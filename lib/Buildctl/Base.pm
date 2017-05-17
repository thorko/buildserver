package Buildctl::Base;

use strict;
use warnings;

use Log::Log4perl;
use Config::Simple;

our @EXPORT = qw( list_versions );

sub new {
	my ($class, $args) = @_;

	my $config = $args->{config};
	my $debug = $args->{debug};
	my $cfg = new Config::Simple();
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


	Log::Log4perl->init(\$log_conf);
	$self->logger = Log::Log4perl->get_logger();

	return bless $self, $class;
}


sub list_versions {
    my $self = shift;
    my $app = shift;
    my $cc = $self->config;
	my $ll = $self->logger;
    $ll->debug("list versions");
    if ( $app eq "" || $app eq "all") {
       foreach (@apps) {
            if ( ! -d "$cc->{'install_path'}/$_" ) {
                print "$cc->{'install_path'}/$_ does not exist.\n";
            } else {
                my @v = glob "$cc->{'install_path'}/$_/[0-9].*";
                print "$_: ";
                foreach (@v) {
                    $_ =~ s{.*/}{};
                    print " $_ ";
                }
                print "\n";
            }
       }
    } else {
       $ll->debug("list version of $app");
       my @v = glob "$cc->{'install_path'}/$app/[0-9].*";
       print "$app: ";
       foreach (@v) {
            $_ =~ s{.*/}{};
            print " $_ ";
       }
       print "\n";
   }
}

1;
