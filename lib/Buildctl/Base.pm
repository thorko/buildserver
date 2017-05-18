package Buildctl::Base;

use strict;
use warnings;

use Log::Log4perl;
use Config::Simple;
use HTML::Strip;
use LWP::UserAgent;
use Switch;
use Data::Dump qw(dd);

our @EXPORT = qw( list_versions service_action switch_version get_active repository install delete pack );

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

	$self->{rep} = $cfg->get_block("repository");

	return bless $self, $class;
}

sub list_versions {
    my $self = shift;
    my $app = shift;
    my $config = $self->{config};
	  my $logger = $self->{logger};
    $logger->debug("list versions");
    if ( !defined($app) ||  $app eq "" || $app eq "all") {
       foreach (@{$self->{apps}}) {
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

# function to start or stop a service
sub service_action {
   my $self = shift;
   my $app = shift;
   my $action = shift;
   my $config = $self->{config};
   my $logger = $self->{logger};

   if ( defined($config->{'init_sysv'}) and $config->{'init_sysv'} ne "") {
	 my $exit = 0;
     my $unit = "";
     switch ($config->{'init_sysv'}) {
		  case "systemd" { 
                      # get available service
                      $unit = qx{/bin/systemctl list-unit-files |grep -E "$app.*service.*enabled"};
                      my @units = split('\n', $unit);
                      if (scalar(@units) < 1) {
					    if($config->{'restart'} eq "soft") {
							print "WARN: start-stop script couldn't be found\n";
							return 0;
						} elsif ($config->{'restart'} eq "hard") {
                            print "ERROR: start-stop script couldn't be found\n";
                            exit(1);
						} else {
							# ignore init file
							return 0;
						}
                      } 
                      # foreach service run the action
                      foreach (@units) {
                          $_ =~ s/.service.*enabled//g;
                          chomp($_);
                          print "Will $action $_? (type uppercase yes): ";
                          my $answer = <STDIN>;
                          if($answer !~ /YES/) {
                            # only do the action if user types YES
                            print "will not do anything\n";
                            next;
                          } else {
                            qx{/bin/systemctl $action $_};
							if($? != 0) {
								print "ERROR: $_ couldn't $action\n";
							} else {
								print "$_ $action: [OK]\n";
							}
                          }
                      } 
                    }
		  case "initd"   {  
                      # get available init files
                      $unit = qx{find /etc/init.d/ -executable | grep $app};
                      my @units = split('\n', $unit);
                      if (scalar(@units) < 1) {
					    if($config->{'restart'} eq "soft") {
							print "WARN: start-stop script couldn't be found\n";
							return 0;
						} elsif ($config->{'restart'} eq "hard") {
                            print "ERROR: start-stop script couldn't be found\n";
                            exit(1);
						} else {
							# ignore init file
							return 0;
						}
                      } 
                      # foreach service run the action
                      foreach (@units) {
                          chomp($_);
                          print "Will $action $_? (type uppercase yes): ";
                          my $answer = <STDIN>;
                          if($answer !~ /YES/) {
                            # only do the action if user types YES
                            print "will not do anything\n";
                            next;
                          } else {
                            qx{$_ $action};
							if($? != 0) {
								print "ERROR: $_ couldn't $action\n";
							} else {
								print "$_ $action: [OK]\n";
							}
                          }
                      } 
		            }
	   }
   }
}

sub switch_version {
   my $self = shift;
   my $app = shift;
   my $version = shift;
   my $config = $self->{config};
   my $logger = $self->{logger};
   if ($app eq "" || $version eq "") {
     print "no app given or version\n";
	 return;
   } else {
	 if ( ! -d "$config->{'install_path'}/$app/$version" ) {
		print "ERROR: $app version $version not available\n";
		return 0;
	 }
	 # stop service
	 $self->service_action($app, "stop");
     $logger->debug("$app: -> $version");
	 qx{ln -sfn $config->{'install_path'}/$app/$version $config->{'install_path'}/$app/current};
	 my $exit = $? >> 8;
	 if($exit != 0) {
		print "ERROR: $app couldn't switch to $version\n";
		print "ln -sfn failed\n";
		exit $exit;
	 } else {
		print "$app: switched to $version\n";
	 }
	 # start service again
	 $self->service_action($app, "start");
   }
}

sub get_active {
    my $self = shift;
	my $app = shift;
	my $config = $self->{config};
	my $logger = $self->{logger};
	if ( $app eq "" || $app eq "all") {
	   foreach (@{$self->{apps}}) {
			if(-l "$config->{'install_path'}/$_/current") {
			  my $v = readlink("$config->{'install_path'}/$_/current");
			  $v =~ s{.*/}{};
			  print "$_: $v\n" if ($v =~ /^\d+/);
         	} else {
				$logger->debug("$_: current link does not exist");
			}
	   }
	} else {
		if(-l "$config->{'install_path'}/$app/current") {
		  my $v = readlink("$config->{'install_path'}/$app/current");
		  $v =~ s{.*/}{};
		  print "$app: $v\n" if ($v =~ /^\d+/);
        } else {
		  $logger->debug("$app: current link does not exist");
        }
	}
}

sub repository {
   my $self = shift;
   my $app = shift;
   my $config = $self->{config};
   my $logger = $self->{logger};
   my $rep    = $self->{rep};
   my $req = "";
   my $url = "";
   my $raw = "";
   my ($ua) = LWP::UserAgent->new;
   if ($app eq "") {
      $url = "http://$rep->{'server'}:$rep->{'port'}";
      $logger->debug("Call: $url");
      $req = HTTP::Request->new(GET => $url);
      $raw = $ua->request($req)->content;
      my $hs = HTML::Strip->new();
      my $text = $hs->parse($raw);
      $hs->eof;
      my $appl = "";
      foreach (split("\n", $text)) {
        print grep {/^([a-z0-9A-Z\-\.]*)\/$/ } $_ . "\n";
      }
   } else {
      $url = "http://$rep->{'server'}:$rep->{'port'}/$app";
      $logger->debug("Call: $url");
      $req = HTTP::Request->new(GET => $url);
      $raw = $ua->request($req)->content;
      my $hs = HTML::Strip->new();
      my $text = $hs->parse($raw);
      $hs->eof;
      foreach (split("\n", $text)) {
        print "$_\n" if ($_ =~ /^$app.*/);
      }
   }
}

sub install {
   my $self = shift;
   my $app = shift;
   my $version = shift;
   my $config = $self->{config};
   my $logger = $self->{logger};
   my $rep = $self->{rep};
   my $req = "";
   my $url = "";
   my $raw = "";
   my ($ua) = LWP::UserAgent->new;
   if ($app eq "" || $version eq "") {
     print "app or version not given.\n";
     return 0;
   } else {
     $logger->info("download $app-$version.tar.gz");
     $url = "http://$rep->{'server'}:$rep->{'port'}/$app/$app-$version.tar.gz";
     print "download: $app-$version.tar.gz\n";
     my $r = $ua->get($url, ':content_file' => "/tmp/$app-$version.tar.gz");
     if($r->{'_rc'} != 200) {
       $logger->error("$app-$version.tar.gz not available in repository");
       print "ERROR: $app-$version.tar.gz not available in repository\n";
       return 1;
     }
	 $logger->debug("result: $r");
     $logger->info("installing $app-$version.tar.gz");
     print "installing: $app-$version.tar.gz\n";
	 # make dest
	 qx{mkdir -p $config->{'install_path'}/$app/$version};
	 # extract app
     qx{tar -xzf /tmp/$app-$version.tar.gz -C $config->{'install_path'}/$app/$version --strip-components=3};
     my $exit = $? >> 8;
     if($exit != 0) {
       $logger->error("Couldn't extract /tmp/$app-$version.tar.gz to $config->{'install_path'}/$app/$version");
       print "Couldn't extract file /tmp/$app-$version.tar.gz to $config->{'install_path'}/$app/$version \n";
       return 1;
     } else {
       $logger->info("Success");
       print "Success\n";
     } 
     unlink("/tmp/$app-$version.tar.gz");
   }
}

sub delete {
    my $self = shift;
	my $app = shift;
	my $version = shift;
	my $config = $self->{config};
	my $logger = $self->{logger};
	if($app eq "" || $version eq "") {
		print "app or version not given.\n";
		return 0;
    }

  my $active_version = readlink("$config->{'install_path'}/$app/current");
  if (defined($active_version)) {
    $active_version =~ s{.*/(\d+.*)}{$1};
  }
  if (defined($active_version) and $active_version eq $version) {
    $logger->error("$app: can't delete active version $version\n");
    print "ERROR: $app: can't delete active version $version\n";
    return 0;
  } else {
    $logger->info("$app will delete version $version\n");
    print "$app: delete $version\n";
        qx{rm -rf  $config->{'install_path'}/$app/$version};
        my $exit = $? >> 8;
      if($exit != 0) {
      $logger->error("$app: Couldn't delete $version");
      print "ERROR: $app: Couldn't delete $version\n";
      } else {
      $logger->info("$app: Deleted old version $version");
      print "Success\n";
      }
  }
}

sub pack {
  my $self = shift;
  my $app = shift;
  my $version = shift;
  my $path = shift;
  my $config = $self->{config};
  my $logger = $self->{logger};

  if ($app eq "" || $version eq "" || $path eq "") {
    print "some required option not set\n";
    exit 0;
  }

  print "Packaging $app $version: ";
  qx{tar -czf $path/$app-$version.tar.gz -C $config->{'install_path'}/$app/$version . > /dev/null 2>&1};
  my $rc = $? >> 8;
  if ($rc != 0 ) {
    $logger->error("packaging of $app $version failed");
    print "ERROR: packaging of $app $version failed\n";
    exit 1;
  }
  print "OK\n";
}

1;
