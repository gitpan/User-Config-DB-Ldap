package User::Config::DB::Ldap;

use strict;
use warnings;

use Moose;
use Moose::Util::TypeConstraints;

with 'User::Config::DB';
use Net::LDAP;
use Net::LDAP::Entry;
use User::Config;

our $VERSION = '0.01_01';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

=pod

=head1 NAME

User::Config::DB::Ldap - Store User-Configuration in an LDAP-directory.

=head1 SYNOPSIS

  use User::Config;

  my $uc = User::Config->instance;
  $uc->db("LDAP",  { table => "user", db => "dbi:SQLite:user.sqlite" });

=head1 DESCRIPTION

This is a database-backend for L<User::Config>. It will store all values within
an LDAP-directory. The options dataclass will be used to determine the
LDAP-schema to use. If needed, this will be added on demand.

=head2 ATTRIBUTES

=head3 scope

The scope to use during searches. It might be one of "one", "base" or
"sub" - which is the default.

=cut

enum ScopeType => [ qw/ sub one base /];
has scope => (
	is => "rw",
	isa => "ScopeType",
	default => "sub",
);

=head3 userattr

The attribute of the ldap-entry, which is used to determine the corresponding user.
This defaults to uid.

=cut

has userattr => (
	is => "rw",
	default => "uid",
);

=head3 ns2attribute

to generate the name of an attribute out of the namespace and name of a given
option, some kind of transition is needed.

By default the '::' seperating the namespace will be replaced by an underscore;
as well as an underscore will be used to concatenate the namespace and the
options name.

If another behaviour is needed, a corresponding sub-ref can be used here. It
will be called as C<<$db->ns2attribute($namespace, $name, $context)>> and
should return the needed attribute's name.

=cut

sub _ns2attribute {
	my ($self, $namespace, $name, $ctx) = @_;

	$namespace =~ s/::/_/g;
	return $namespace."_".$name;
}

has ns2attribute => (
	is => "rw",
	default => sub { return \&_ns2attribute },
);

=head3 searchstr

If a search for an element has to be performed, a corresponding query is
generated.

By default, a search for an element, where the attribute set in C<userattr> is
equal to the current's context user will be performed.

To generate another searchstr, C<searchstr> can be set to an sub-ref. This will
be called like C<<$db->searchstr($namespace, $option_name, $user, $context)>>.

=cut

sub _searchstr {
	my ($self, $namespace, $name, $user, $ctx) = @_;
	
	return "(".$self->userattr."=$user)";
}

has searchstr => (
	is => "ro",
	default => sub { return \&_searchstr },
);

=head3 ldap

If there is a preared LDAP-connection is available, this can be set using the
ldap-attribute. It will accept a sub-ref returning a bound connection. This
will be called as C<<$db->ldap($user, $modification, $context)>>, where
$modification will indicate, wether this connection will be used to modify
items in the database. The connection then has to be returned. Care has to be
taken not to return a connection with different user-privileges.

=cut

sub _ldap {
	my ($self, $user, $bind, $context) = @_;

	my $ldap = Net::LDAP->new($self->host) or die $@;
	if($bind and $self->binddn) {
		my $userdn = sprintf($self->binddn, $user);
		$ldap->bind($userdn, password => $self->bindpwd, version => 3 );
	} else {
		$ldap->bind(version => 3);
	}
	return $ldap;
}

has ldap => (
	is => "ro",
	isa => "CodeRef",
	default => sub { \&_ldap },
);

=head3 host, binddn, bindpwd and rootdn

If no C<ldap>-attribute is given, alternativly these parameters can be given
to bind to a server on every request. C<host> must be set to a corresponding
URI and is, like C<rootdn> in this case mandatory.

Read-only requests will be performed using an anonymous bind. Modification will
do a bind on the connection in advance.

HINT: even, if C<ldap> is given, these can be set and being used in the given sub,
using eg C<<$self->host>>.

=cut

has [ qw/host binddn bindpwd rootdn /] => (
	isa => "Str",
	is => "ro",
);

=head3 default_objectclass

If an option should be set, whithout any entry for the given user being present, a
new entry will be created. The entry will use the objectclass given by
C<default_objectclass> which defaults to "posixAccount".

=cut

has default_objectclass => (
	isa => "Str",
	is => "ro",
	default => "posixAccount",
);

#
# This returns a the bound connection as well as the executed search
#

sub _get_bind_search {
	my ($self, $args) = @_;

	my $ldap = &{$self->ldap}($self, $args->{user}, $args->{bind}, $args->{context});

	print "search:\n\tdn: ".$self->rootdn."\n\tscope: ".$self->scope."\n\tattrs: ".join(', ',@{$args->{attr}})."\n\tsearch: ".
		&{$self->searchstr}($self, 
			$args->{namespace}, $args->{name}, $args->{user}, $args->{context})."\n" if $ENV{LDAP_DEBUG};
	my $res = $ldap->search(
	       	base => $self->rootdn,
		scope => $self->scope,
		attrs => $args->{attr},
		filter => &{$self->searchstr}($self, 
			$args->{namespace}, $args->{name}, $args->{user}, $args->{context}),
	);
	if($ENV{LDAP_DEBUG}) {
		$_->dump for $res->all_entries();
	}
	return ($ldap, $res);
}

=head2 METHODS

=head3 C<<$db->set($package, $user, $option_name, $context, $value)>>

assigns the value for the given user to the option within a package.
See L<User::Config::DB>

=cut

sub set {
	my ($self, $namespace, $user, $name, $ctx, $value) = @_;

	my $attr = &{$self->ns2attribute}($self, $namespace, $name, $ctx);
	my ($ldap, $res) = $self->_get_bind_search({
			bind => 1,
			attr => [],
			name => $name,
			namespace => $namespace,
			user => $user,
			context => $ctx,
		});
	my $entry = ($res->entries())[0];
	my $dataclass =
		User::Config->instance()->options()->{$namespace}->{$name}->{dataclass}
		|| "extensibleObject";
	my $add = 0;
	unless ($entry) {
		$add = 1;
		$entry = Net::LDAP::Entry->new(
			$self->userattr."=".$user.",".$self->rootdn,
			objectclass => $self->default_objectclass,
			$self->userattr => $user);
	}
	my @cls = $entry->get_value("objectclass");
	if(grep { $_ eq $dataclass } @cls) {
		$entry->replace($attr => $value);
		print("set:\n\tdn: ".$entry->dn."\n\tcmd: replace($add)\n\t$attr: $value\n") if $ENV{LDAP_DEBUG};
	} else {
		$entry->add(objectclass => $dataclass, $attr => $value);
		print("set:\n\tdn: ".$entry->dn."\n\tcmd: add($add)\n\tch: objectclass => $dataclass\n\t$attr: $value\n")
			if $ENV{LDAP_DEBUG};
	}
	my $ret = $add?$ldap->add($entry):$entry->update($ldap);
	die $ret->error if $ret->code;
}

=head3 C<<$db->isset($package, $user, $option_name, $context)>>

Checks wether the option was set.
See L<User::Config::DB>

=cut

sub get {
	my ( $self, $namespace, $user, $name, $ctx) = @_;
	my $attr = &{$self->ns2attribute}($self, $namespace, $name, $ctx);
	my ($ldap, $res) = $self->_get_bind_search({
			attr => [ $attr ],
			name => $name,
			namespace => $namespace,
			user => $user,
			context => $ctx,
		});
	my @ret = map { $_->get_value($attr) } $res->entries;
	return @ret if wantarray;
	return $ret[0];
}

=head1 SEE ALSO

=head1 AUTHOR

Benjamin Tietz E<lt>benjamin@micronet24.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Benjamin Tietz

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;
1;

