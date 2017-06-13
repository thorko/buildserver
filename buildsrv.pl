#!/usr/bin/perl
use strict;
use warnings;
use Log::Log4perl;
use Getopt::Long;
use Pod::Usage;
use Config::Simple;
use File::Slurp;
use File::Grep qw(fgrep fmap fdo);
use POSIX qw(strftime);
use HTTP::Server::Brick;
my $help = 0;
my $debug = 0;
my ($config, $command, $app, $version) = ("", "", "", "");

Getopt::Long::Configure('bundling');
GetOptions(
  "c|config=s"     => \$config,
  "h|help"       => \$help,
  "d|debug"      => \$debug,
);

pod2usage( { -exitval=>1,  -verbose => 99, -sections =>[qw(SYNOPSIS OPTIONS)] } )  if ($help);

$config = defined($config) && $config ne "" ? $config : "/etc/buildctl/buildsrv.conf";

our $package_states = { k => "keep", i => "ignore", f => "failed" };

my $cfg = new Config::Simple();
$cfg->read($config);
my $log = $cfg->get_block("log");
our $cc = $cfg->get_block("config");

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

my $srv = HTTP::Server::Brick->new(port=>$cc->{'port'}, host=>$cc->{'hostname'});
$ll->info("Starting Server at $cc->{'port'}");
$ll->info("Serving $cc->{'path'}");
#$srv->mount("/" => { path => $cc->{'path'} });

# new implementation
$srv->mount("/" => {
  handler => sub{
	# HTTP::Request and HTTP::Response object
	my ($req, $res) = @_;
	# return root path of $cc->{'path'}
	if (not defined($req->{path_info})) {
		my $dirs = qx{ls $cc->{'path'}};
		$res->add_content($dirs);
	} else {
		# the packages
		if("$cc->{'path'}/$req->{path_info}" =~ /\.tar\.gz|\.tgz/) {
		  if(-f "$cc->{'path'}/$req->{path_info}") {
			my $state = 0;
			my $package = "";
			($state, $package) = check_package("$cc->{'path'}$req->{path_info}", "$cc->{'path'}/.package_info") if (-f "$cc->{'path'}/.package_info");
		    my $data = read_file("$cc->{'path'}/$req->{path_info}", { binmode => ':raw' });
			$ll->info("Download Package: $req->{path_info}: $state");
			$res->push_header(packagestatus => $state);
			$res->push_header(package => $package) if (defined $package && $package ne "");
			$res->content($data);
		  } else {
			$res->code(404);
		    $res->content("$cc->{'path'}/$req->{path_info} NOT FOUND");
		  }
		# the directories
		} elsif (-d "$cc->{'path'}/$req->{path_info}") {
		  my $content = "";
		  my $lines = qx{ls $cc->{'path'}/$req->{path_info}};
		  my @files = split("\n", $lines);
		  foreach (@files) {
			my $state = "";
			my $package = "";
		    ($state, $package) = check_package("$cc->{'path'}$req->{path_info}/$_", "$cc->{'path'}/.package_info") if (-f "$cc->{'path'}/.package_info");
			if(defined($state) && $state =~ /k|i|f/) {
		      $content .= "$_\t$package_states->{$state}\n";
			} else {
			  $content .= "$_\n";
			}
		  }
		  $res->content($content);
		# uri not found
		} else {
		  $res->code(404);
		  $res->content("$req->{path_info} NOT FOUND");
		}
	}
	1;
  },
  wildcard => 1, # return all matches
});


$srv->start;


sub check_package {
	# k = keep
	# i = ignore
	# f = failed
	my $package = shift; # contains full path
	my $info_file = shift;
	my $state = 0;

	# check first if there is a package entry
	my @matches = fgrep { /$package/ } $info_file;
	foreach (@matches) {
	  if ($_->{count} > 1) {
		return 1;
	  } else {
		foreach my $l (keys %{$_->{matches}}) {
		  my $hit = $_->{matches}->{$l};
		  my ($t, $p) = split(" ", $hit);
		  # if excact package name is set to keep return 0
		  if($t eq "k") {
			$state = 0;
		  } else {
		    $state = $t;
		  }
		}
	  }
	}
	return $state if ($state ne "0");
	# check if there is a package pinned (keep);
	my ($name, $version) = $package =~ /([a-z\-]*)-([0-9a-z\.]+)\.tar\.gz$/;
	@matches = fgrep { /$name/ } $info_file;
	foreach (@matches) {
	  if($_->{count} == 0 ) {
	    return 0;
	  } elsif ($_->{count} > 1) {
		return 1;
	  } else {
		foreach my $l (keys %{$_->{matches}}) {
		  my $hit = $_->{matches}->{$l};
		  my ($t, $p) = split(" ", $hit);
		  $state = $t;
		  return ($state, $p);
		}
	  }
	}
	return 0;
}

__END__

=head1 SYNOPSIS

 buildsrv.pl [-c <config] 
                    
=head1 DESCRIPTION

 buildsrv.pl is a tool to serve applications from a build server

=head1 OPTIONS

=head2 GENERAL OPTIONS

=over 

=item B<-c, --config>

use config file

