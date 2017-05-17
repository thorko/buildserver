package Buildctl::Base;

use strict;
use warnings;

use Log::Log4perl;
use Config::Simple;
use Data::Dump qw(dd);

our @EXPORT = qw( list_versions );

sub new {
	my ($class, %args) = @_;
	my $self;

	my $config = $args{config};
	my $debug = $args{debug} // 0;

	my @apps;
	my $cfg = new Config::Simple();
  $cfg->read($config);
	my $log = $cfg->get_block("log");

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
    log4perl.appender.Logfile.layout.ConversionPattern=%d %-5p %c - %m%n";
  } else {
    $log_conf = "log4perl.rootLogger=$log->{'loglevel'}, Logfile
    log4perl.appender.Logfile=Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename=$log->{'logfile'}
    log4perl.appender.Logfile.mode=append
    log4perl.appender.Logfile.layout=PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern=%d %-5p %c - %m%n";
  }


	Log::Log4perl->init(\$log_conf);
	$self->{logger} = Log::Log4perl->get_logger();
	$self->{config} = $cfg->get_block("config");

	# read apps
	my $a = $cfg->get_block("apps");
	foreach my $l (keys %$a) {
		if($a->{$l} == 1) {
			push @apps, $l;
		}
  }
	$self->{apps} = \@apps;

	return bless $self, $class;
}

sub list_versions {
    my $self = shift;
    my $app = shift;
    my $config = $self->{config};
	  my $logger = $self->{logger};
    $logger->debug("list versions");
    if ( $app eq "" || $app eq "all") {
       foreach ($self->{apps}) {
            if ( ! -d "$config->{'install_path'}/$_" ) {
                print "$config->{'install_path'}/$_ does not exist.\n";
            } else {
                my @v = glob "$config->{'install_path'}/$_/[0-9].*";
                print "$_: ";
                foreach (@v) {
                    $_ =~ s{.*/}{};
                    print " $_ ";
                }
                print "\n";
            }
       }
    } else {
       $logger->debug("list version of $app");
       my @v = glob "$config->{'install_path'}/$app/[0-9].*";
       print "$app: ";
       foreach (@v) {
            $_ =~ s{.*/}{};
            print " $_ ";
       }
       print "\n";
   }
}

1;
