#!/usr/bin/perl

use strict;
use warnings;
use Log::Log4perl;
use Getopt::Long;
use Pod::Usage;
use Config::Simple;
use Buildctl::Base;
use POSIX qw(strftime);
use Switch;
my $help = 0;
my $debug = 0;
my $force = 0;
my ($config, $command, $app, $file, $version, $build_file, $path, $mark, $option) = ("", "", "", "", "", "", "");

Getopt::Long::Configure('bundling');
GetOptions(
  "c|config=s"     => \$config,
  "h|help"       => \$help,
  "d|debug"      => \$debug,
  "r|command=s"  => \$command,
  "a|app=s"      => \$app,
  "f|force"      => \$force,
  "t|file=s"     => \$file,
  "m|mark=s"     => \$mark,
  "o|option=s"   => \$option,
  "v|version=s"  => \$version,
  "b|build-file=s" => \$build_file,
  "p|path=s"       => \$path,
);

pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "");
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "activate" && ($app eq "" || $version eq ""));
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "list" && $option eq "");
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "install" && $file eq "");
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "delete" && ($app eq "" || $version eq ""));
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "build" && $build_file eq "");
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "pack" && ($app eq "" ||  $version eq ""));
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "update" && $build_file eq "");
pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($command eq "mark" && ($app eq "" ||  $version eq "" || $mark eq ""));

$config = defined($config) && $config ne "" ? $config : "/etc/buildctl/buildctl.conf";

# use module
my $buildctl = Buildctl::Base->new(config => $config, debug => $debug, force => $force);

my $exit = 0;
switch ($command) {
	case "list" { 
	  if ($option eq "version") {
	    $buildctl->list_versions($app);
	  } elsif ($option eq "package_state") {
		$buildctl->list_package_state();
	  }
	}
	case "get-active" { $buildctl->get_active($app) }
	case "activate" { $buildctl->switch_version($app, $version) }
	case "repository" { $buildctl->repository($app) }
	case "install" { if($version ne "") { $buildctl->install($file, $version) } else { $buildctl->install($file) } }
	case "delete" { $buildctl->delete($app, $version) }
	case "build" { $buildctl->build($build_file) }
    case "pack" { $buildctl->pack($app, $version) }
	case "update" { $buildctl->update($build_file) }
	case "mark" { $buildctl->mark($app, $version, $mark) }
	else { pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  }
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

=item B<list>

requires: --option (version, package_state): will list version or package states

=item B<get-active>

get the active versions of applications

=item B<activate>

requires --app, --version: activate version of app

=item B<repository>

requires --app, show versions of app on repository server

=item B<install>

requires --file: install file from repository server

=item B<delete>

requires --app, --version: delete version of app from server

=item B<build>

requires --build-file: build the app from source

=item B<pack>

requires --app, --version: will pack the app in version and move it to path

=item B<update>

requires --build-file: will build app and packing it

=item B<mark>

requires --app, --version, --mark: will mark the app in repository (allowed: k = keep, i = ignore, f = failed)
