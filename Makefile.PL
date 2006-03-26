use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'WWW::GMail',
    'VERSION_FROM'	=> 'GMail.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        Crypt::SSLeay => undef,
		HTTP::Cookies => undef,
		LWP::UserAgent => undef,
		HTTP::Request => undef,
	    URI::Escape => undef,
        Carp => undef,
    },
	'dist' => {
		'SUFFIX'       => ".gz",
		'DIST_DEFAULT' => 'all tardist',
		'COMPRESS'     => "gzip -9vf",
	},						
);
