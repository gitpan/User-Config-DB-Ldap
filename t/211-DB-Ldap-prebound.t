use Test::More;

use lib 't';

BEGIN {
	eval { require Net::LDAP::Server::Test };
	plan skip_all => "Net::LDAP::Server::Test isn't installed" if $@;
	plan tests => 6;
}

my $module;
BEGIN { $module = 'User::Config::DB::Ldap'};
BEGIN { use_ok($module) };

use User::Config;
use User::Config::Test;

my $rootdn = "dc=example,dc=com";
my $uc = User::Config::instance();
my $mod = User::Config::Test->new;
$mod->context({user => "foo"});

ok( Net::LDAP::Server::Test->new(38080, data => []), "LDAP Test-Server respawned");
my $ldap = Net::LDAP->new("ldap://localhost:38080");
$ldap->bind(version => 3);
is(ref $uc->db("Ldap", { ldap => sub { return $ldap }, rootdn => $rootdn}),
	"User::Config::DB::Ldap", "LDAP client preconnected");
is($mod->setting, "defstr", "Default value (static bind)");
$mod->setting("bla");
SKIP: {
	skip("Net::LDAP::Server::Test doesn't seem to store modified values", 2);
	is($mod->setting, "bla", "saved LDAP setting");
	$mod->setting("blablupp");
	is($mod->setting, "blablupp", "modified LDAP setting");
}
