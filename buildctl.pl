#!/usr/bin/perl

use strict;
use warnings;
use Archive::Extract;
use Log::Log4perl;
use Getopt::Long;
use Pod::Usage;
use Data::Dump qw(dd);
use Config::Simple;
use HTML::Strip;
use LWP::UserAgent;
use Buildctl::Base;
use POSIX qw(strftime);
use Switch;
my $help = 0;
my $debug = 0;
my ($config, $command, $app, $version, $build_file, $path) = ("", "", "", "", "");

sub print_help {
	print "Usage: buildctl.pl [-c config file] -r <command>";
	return 0;
}

Getopt::Long::Configure('bundling');
GetOptions(
  "c|config=s"     => \$config,
  "h|help"       => \$help,
  "d|debug"      => \$debug,
  "r|command=s"  => \$command,
  "a|app=s"      => \$app,
  "v|version=s"  => \$version,
  "b|build-file=s" => \$build_file,
  "p|path=s"       => \$path,
);

pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "");
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "switch-version" && ($app eq "" || $version eq ""));
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "install" && ($app eq "" || $version eq ""));
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "delete" && ($app eq "" || $version eq ""));
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "build" && $build_file eq "");
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "pack" && ($app eq "" ||  $version eq ""));

$config = defined($config) && $config ne "" ? $config : "/etc/buildctl/buildctl.conf";

# use module
my $buildctl = Buildctl::Base->new(config => $config, debug => $debug);

my $cfg = new Config::Simple();
$cfg->read($config);
my $log = $cfg->get_block("log");
our $cc = $cfg->get_block("config");
my $a = $cfg->get_block("apps");
our $rep = $cfg->get_block("repository");

our @apps;
foreach my $l (keys %$a) {
	if($a->{$l} == 1) {
		push @apps, $l;
	}
}  

$log->{'loglevel'} = "DEBUG" if ($debug);
my $log_conf;
if ( $debug ) {
$log_conf = "
	log4perl.rootLogger=$log->{'loglevel'}, screen, Logfile
	log4perl.appender.screen = Log::Log4perl::Appender::Screen
	log4perl.appender.screen.stderr = 0
	log4perl.appender.screen.layout = PatternLayout
	log4perl.appender.screen.layout.ConversionPattern = %d %p> %F{1}:%L %M - %m%n

	log4perl.appender.Logfile=Log::Log4perl::Appender::File
  	log4perl.appender.Logfile.filename=$log->{'logfile'}
	log4perl.appender.Logfile.mode=append
	log4perl.appender.Logfile.layout=PatternLayout
	log4perl.appender.Logfile.layout.ConversionPattern=%d %-5p %c - %m%n
";
} else {
	$log_conf = "log4perl.rootLogger=$log->{'loglevel'}, Logfile
	log4perl.appender.Logfile=Log::Log4perl::Appender::File
  	log4perl.appender.Logfile.filename=$log->{'logfile'}
	log4perl.appender.Logfile.mode=append
	log4perl.appender.Logfile.layout=PatternLayout
	log4perl.appender.Logfile.layout.ConversionPattern=%d %-5p %c - %m%n
";
}

Log::Log4perl->init(\$log_conf);
our $ll = Log::Log4perl->get_logger();

my $exit = 0;
switch ($command) {
	case "list-versions" { $buildctl->list_versions($app) }
	case "get-active" { $buildctl->get_active($app) }
	case "switch-version" { $buildctl->switch_version($app, $version) }
	case "repository" { $buildctl->repository($app) }
	case "install" { $buildctl->install($app, $version) }
	case "delete" { $buildctl->delete($app, $version) }
	case "build" { &build($build_file) }
    case "pack" { $buildctl->pack($app, $version, $path) }
	else { pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  }
}


###########################################################################
#  build section
#  #######################################################################
#

##############
# configure
##############
sub configure {
  my $build_path = shift; 
  my $source_dir = shift;
  my $build_opts = shift;
  my $log = "configure.log";

  # run build
  print "Configure: ";
  qx{cd $build_path/$source_dir && $build_opts > $build_path/$log 2>&1};
  my $exit = $? >> 8;
  if ($exit != 0) {
    print "ERROR: configure $build_opts failed\nCheck $build_path/$log\n";
    exit 1;
  } else {
    print "OK\n";
    return 0;
  }
}

##############
# make
##############
sub make {
  my $build_path = shift;
  my $source_dir = shift;
  my $make_cmd = shift;
  my $log = "make.log";
  # run make
  print "Make: ";
  qx{cd $build_path/$source_dir && $make_cmd > $build_path/$log 2>&1};
  my $exit = $? >> 8;
  if ($exit != 0) {
    print "ERROR: $make_cmd failed\nCheck $build_path/$log\n";
    exit 1;
  } else {
    print "OK\n";
    return 0;
  }
}

##############
# make install
##############
sub make_install {
  my $build_path = shift;
  my $source_dir = shift;
  my $install_cmd = shift;
  my $log = "install.log";
  # run make
  print "Install: ";
  qx{cd $build_path/$source_dir && $install_cmd > $build_path/$log 2>&1};
  my $exit = $? >> 8;
  if ($exit != 0) {
    print "ERROR: $install_cmd failed\nCheck $build_path/$log\n";
    exit 1;
  } else {
    print "OK\n";
    return 0;
  }
}

# function to expand macros in variable
# will take variable and a hash which contains 
# the macros values
# return: var - with expanded macros
sub rep_var{
  my $var = shift;
  my $cfghash = shift;
  my $a = "";

  while($var =~ /%([a-z_]+)/g) {
    # if $var doesn't contain any variable prefix
    if(not defined($1)) {
      return($var);
    } else {
      my $a = $cfghash->{$1};
      if(not defined($a)) {
        $ll->info("%$1 macro does not exist in config file");
        print "%$1 macro does not exist in config file\n";
      } else {
        $var =~ s/%$1/$a/;
      }
    }
  }
  return($var);
}

sub pre_post_action {
  my $command = shift;
  my $type = shift;
  my $build_path = shift;

  print "Running $type command: ";
  qx{cd $build_path && $command > $build_path/$type.log 2>&1};
  my $rc = $? >> 8;
  if ($rc != 0 ) {
    $ll->error("build command $command failed, check log $build_path/$type.log");
    print "ERROR: build command $command failed, check log $build_path/$type.log\n";
    exit 1;
  }
  print "OK\n";
  return 0;
}

sub check_install_dir {
  my $id = shift;
  # don't install if version already exists
  if ( -d $id ) {
	  print "ERROR: $id already exists\n";
	  print "Do you want to continue? (type uppercase yes): ";
	  my $answer = <STDIN>;
	  if($answer !~ /YES/) {
	    exit 0;
	  }
  }
  # check if install_path exists
  if(! -d $id) {
    # create install path
    qx{mkdir -p $id};
  }
}

##############
# build
##############
sub build {
  my $build_file = shift;

  if ($build_file eq "") {
    print "build_file is missing\n";
    return 0;
  } elsif (! -f $build_file) {
    print "build file: $build_file does not exist\n";
    return 0;
  }
  my $cfg = new Config::Simple();
  $cfg->read($build_file);
  my $bb = $cfg->get_block("config");


  my $tmpfile = "/tmp/app.$bb->{'archive_type'}";
  my $build_path = defined($bb->{'build_path'}) ? $bb->{'build_path'} : "/tmp/build";

  qx{mkdir -p $build_path};
  # cleanup build path
  qx{rm -rf $build_path/*};
  qx{rm -rf $tmpfile};

  # replace variables if existing
  $bb->{'install_path'} = rep_var($bb->{'install_path'}, $bb);
  $bb->{'url'} = rep_var($bb->{'url'}, $bb);
  $bb->{'build_opts'} = rep_var($bb->{'build_opts'}, $bb);

  # check if build_script exists and call a different function
  if(defined($bb->{'build_script'})) {
    $buildctl->build_script($bb, $build_path);
  } else {
    # download source
    $buildctl->download($bb->{'url'}, $tmpfile);
    # extract source
    my $source = $buildctl->extract_source($build_path, $tmpfile, $bb->{'archive_type'});
    # run prebuild_command
    if(defined($bb->{'prebuild_command'}) && $bb->{'prebuild_command'} ne "" ){
      $bb->{'prebuild_command'} = rep_var($bb->{'prebuild_command'}, $bb);
      pre_post_action($bb->{'prebuild_command'}, "pre", $build_path);
    }
    # configure
    configure($build_path, $source, $bb->{'build_opts'});
    # compile
    make($build_path, $source, $bb->{'make'});
	# befor installing check install_path
	check_install_dir($bb->{'install_path'});
    # install
    make_install($build_path, $source, $bb->{'install'});
    $ll->info("Sucessfully installed $bb->{'app'} $bb->{'version'}");

    # run post build action
    if(defined($bb->{'postbuild_command'}) && $bb->{'postbuild_command'} ne "" ){
      $bb->{'postbuild_command'} = rep_var($bb->{'postbuild_command'}, $bb);
      pre_post_action($bb->{'postbuild_command'}, "post", $build_path);
    }
  }

  if(defined($bb->{'keep_build'}) and $bb->{'keep_build'} eq "true") {
    $ll->info("will keep build directory at $build_path");
    print "will keep build directory at $build_path\n";
  } else {
    # cleanup build path
    qx{rm -rf $build_path};
    qx{rm -rf $tmpfile};
  }
}


__END__

=head1 SYNOPSIS

 buildctl.pl -r <command> 
                    
=head1 DESCRIPTION

 builctl.pl is a tool to install applications from source

=head1 OPTIONS

=head2 GENERAL OPTIONS

=over 

=item B<-a, --app>

use app, [all,apache,php5....]

=item B<-v, --version>

use version, [2.4.1, 5.4.2, ...]

=item B<-b, --build-file>

use build file to install app

=head2 COMMANDS

=over

=item B<list-versions>

list all versions of applications

=item B<get-active>

get the active versions of applications

=item B<switch-version>

requires --app, --version: switch version of app

=item B<repository>

requires --app, show versions of app on repository server

=item B<install>

requires --app, --version: install version of app from repository server

=item B<delete>

requires --app, --version: delete version of app from server

=item B<build>

requires --build-file: build the app from source

=item B<pack>

requires --app, --version, --path: will pack the app in version and move it to path
