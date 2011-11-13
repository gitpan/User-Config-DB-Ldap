use 5.010001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'User::Config::DB::Ldap',
    VERSION_FROM      => 'lib/User/Config/DB/Ldap.pm', # finds $VERSION
    PREREQ_PM         => {
	    Moose => 2.02,
	    'User::Config' => 0.02,
	    'Net::LDAP' => 0,
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (
	      ABSTRACT_FROM  => 'lib/User/Config/DB/Ldap.pm', # retrieve abstract from module
	      AUTHOR         => 'Benjamin Tietz <btietz@cpan.com>',
	      LICENSE		=> 'perl',
	      META_MERGE	=> {
		      no_index => {
			      directory => 't',
		      },
	      },
      ) : ()),
);
