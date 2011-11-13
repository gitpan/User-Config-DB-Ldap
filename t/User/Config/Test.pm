package User::Config::Test;

use User::Config;

has_option "setting" => ( default => "defstr", dataclass => "foocl", anon_default => "anonymous" );

has_option "getting" => ( default => "noset", noset => 1 );

my $foo = 0;

has_option "dyndef" => ( default => sub { $foo = $foo +1 }, dataclass => "foocl" );

no Moose;
__PACKAGE__->meta->make_immutable;
1;
