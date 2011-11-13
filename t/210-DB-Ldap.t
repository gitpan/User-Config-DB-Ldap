use Test::More;

use lib 't';

BEGIN {
	eval { require Net::LDAP::Server::Test };
	plan skip_all => "Net::LDAP::Server::Test isn't installed" if $@;
	plan tests => 4;
}

my $module;
BEGIN { $module = 'User::Config::DB::Ldap'};
BEGIN { use_ok($module) };

use User::Config;
use User::Config::Test;

my $rootdn = "dc=example,dc=com";

ok( Net::LDAP::Server::Test->new(28080), "LDAP Test-Server spawned");
my $uc = User::Config::instance();
ok($uc->db("Ldap", { host => "ldap://localhost:28080", rootdn => $rootdn}), "LDAP client connected");
my $mod = User::Config::Test->new;
$mod->context({user => "foo"});
is($mod->setting, "defstr", "Default value (single bind)");
