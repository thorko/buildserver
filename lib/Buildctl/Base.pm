package Buildctl::Base;

use strict;
use warnings;

use Log::Log4perl;
use Config::Simple;
use HTML::Strip;
use LWP::UserAgent;
use Switch;
use version;
use Archive::Extract;
use Linux::Distribution qw(distribution_name distribution_version);

our @EXPORT = qw( list_versions service_action switch_version get_active repository install delete pack rep_var build_script );

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

sub get_latest {
	my $self = shift;
    my $app = shift;
    my $config = $self->{config};
    my $logger = $self->{logger};
    my $rep    = $self->{rep};
    my $req = "";
    my $url = "";
    my $raw = "";
	my $version = 0;
    my ($ua) = LWP::UserAgent->new;
    $url = "http://$rep->{'server'}:$rep->{'port'}/$app";
    $req = HTTP::Request->new(GET => $url);
    $raw = $ua->request($req)->content;
    my $hs = HTML::Strip->new();
    my $text = $hs->parse($raw);
    $hs->eof;
    foreach (split("\n", $text)) {
	  if($_ =~ /^$app-/) {
	    $_ =~ s/^$app-(.*)\.tar\.gz/$1/;
	    $version = $_ if(version->parse($_) > $version);
	  }
    }
	return $version;
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
     if ($version eq "latest") {
	   # get latest version from repository
	   $version = $self->get_latest($app);
     }
     $logger->info("download $app-$version.tar.gz");
     $url = "http://$rep->{'server'}:$rep->{'port'}/$app/$app-$version.tar.gz";
     print "download: $app-$version.tar.gz\n";
     my $r = $ua->get($url, ':content_file' => "/tmp/$app-$version.tar.gz");
     if($r->{'_rc'} != 200) {
       $logger->error("$app-$version.tar.gz not available in repository");
       print "ERROR: $app-$version.tar.gz not available in repository\n";
       return 1;
     }
	 $logger->debug("result: $r->{_msg}");
     $logger->info("installing $app-$version.tar.gz");
     print "installing: $app-$version.tar.gz\n";
	 # make dest
	 qx{mkdir -p $config->{'install_path'}/$app/$version};
	 # extract app
     qx{tar -xzf /tmp/$app-$version.tar.gz --xform=s,usr/local/$app/$version,,g -C $config->{'install_path'}/$app/$version 2> /dev/null};
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

# function to expand macros in variable
# will take variable and a hash which contains 
# the macros values
# return: var - with expanded macros
sub rep_var{
  my $self = shift;
  my $var = shift;
  my $cfghash = shift;
  my $logger = $self->{logger};
  my $a = "";

  while($var =~ /%([a-z_]+)/g) {
    # if $var doesn't contain any variable prefix
    if(not defined($1)) {
      return($var);
    } else {
      my $a = $cfghash->{$1};
      if(not defined($a)) {
        $logger->info("%$1 macro does not exist in config file");
        print "%$1 macro does not exist in config file\n";
      } else {
        $var =~ s/%$1/$a/;
      }
    }
  }
  return($var);
}


sub build_script {
  my $self = shift;
  my $bb = shift;
  my $build_path = shift;
  my $logger = $self->{logger};
  if ( ! -f $bb->{'build_script'} ) {
	  print "ERROR: the build script $bb->{'build_script'} does not exist\n";
	  return 1;
  } 

  # expand build script with macros
  open(FILE, "<$bb->{'build_script'}");
  my @lines = <FILE>;
  close(FILE);
  $bb->{'build_script'} =~ m{.*/(.*)};
  my $script = $1;
  $logger->debug("Create build script $build_path/$script");
  open(NEW_FILE, ">$build_path/$script") or die "can't create build_script";
  foreach(@lines) {
    while($_ =~ /%([a-z_]+)/g) {
      if(not defined($1)) {
        print NEW_FILE $_;
      } else {
        $logger->debug("expand macro %$1");
        my $p = $bb->{$1};
        if(not defined($p)) {
          $logger->info("%$1 macro does not exist in config file");
          print "%$1 macro does not exist in config file\n";
        } else {
          $_ =~ s/%$1/$p/;
        }
      }
    }
    print NEW_FILE $_;
  }
  close(NEW_FILE);
  qx{chmod +x $build_path/$script};
  # run build script
  print "Run your build script $build_path/$script: ";
  qx{$build_path/$script > $build_path/build.log 2>&1};
  my $exit = $? >> 8;
  if($exit != 0) {
    print "ERROR: check your build script and log $build_path/build.log\n";
    exit 1;
  } else {
    print "OK\n";
    exit 0;
    return 0;
  }
}

##############
# configure
##############
sub configure {
  my $self = shift;
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
  my $self = shift;
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
  my $self = shift;
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

sub pre_post_action {
  my $self = shift;
  my $command = shift;
  my $type = shift;
  my $build_path = shift;
  my $logger = $self->{logger};

  print "Running $type command: ";
  qx{cd $build_path && $command > $build_path/$type.log 2>&1};
  my $rc = $? >> 8;
  if ($rc != 0 ) {
    $logger->error("build command $command failed, check log $build_path/$type.log");
    print "ERROR: build command $command failed, check log $build_path/$type.log\n";
    exit 1;
  }
  print "OK\n";
  return 0;
}

sub check_install_dir {
  my $self = shift;
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

sub extract_source {
  my $self = shift;
  my $build_path = shift;
  my $tmpfile = shift;
  my $archive_type = shift;

  # cleanup old stuff
  qx{rm -rf $build_path};
  qx{mkdir -p $build_path};
  print "Extract archive $tmpfile to $build_path: ";

  my $ae = Archive::Extract->new(archive => $tmpfile, type => $archive_type);
  my $ok = $ae->extract(to => $build_path);
  if ($ok) {
     print "OK\n";
     # get path of source
     my @p = glob "$build_path/*";
     $p[0] =~ s{.*/}{};
     return $p[0];
  } else {
     print "ERROR: extracting file $tmpfile\n";
     exit 1;
   }
}

sub download {
  my $self = shift;
  my $url = shift;
  my $tmp = shift;
  my $logger = $self->{logger};
  my $timeout = 60;
  print "Will download $url: ";
  qx{wget -O $tmp --timeout=$timeout --quiet --prefer-family=IPv4 $url};
  my $exit = $? >> 8;
  if($exit != 0) {
    $logger->error("$url couldn't be downloaded.");
    print "ERROR: $url couldn't be downloaded\n";
    exit 1;
  } else { 
    print "OK\n";
    return 0;
  }
}

sub install_requirements {
  my $self = shift;
  my $requirements = shift;
  my $logger = $self->{logger};
  my $ret = 1;
  my $error = "";

  my $distro = distribution_name();

  switch($distro) {
    case "debian" { 
		qx{apt-get -y install $requirements};
	}
	case "redhat" {
		qx{yum -y install $requirements};
	}
	case "centos" { 
		qx{yum -y install $requirements};
	}
	else { $ret = 0; $error = "distro $distro not supported\n"; }
  }
  return ($ret, $error);
}

sub build {
  my $self = shift;
  my $build_file = shift;
  my $logger = $self->{logger};

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
  $bb->{'install_path'} = $self->rep_var($bb->{'install_path'}, $bb);
  $bb->{'url'} = $self->rep_var($bb->{'url'}, $bb);
  $bb->{'build_opts'} = $self->rep_var($bb->{'build_opts'}, $bb);

  # install requirements
  if(defined($bb->{'build_requirements'}) and $bb->{'build_requirements'} ne "") {
	my ($ret, $error) = $self->install_requirements($bb->{'build_requirements'});
	if($ret == 0) {
		print "Requirements installed: OK\n";
	} else {
		print "Requirements installed: ERROR\n";
		print "$error\n";
		exit 1;
	}
  }

  # check if build_script exists and call a different function
  if(defined($bb->{'build_script'})) {
    $self->build_script($bb, $build_path);
  } else {
    # download source
    $self->download($bb->{'url'}, $tmpfile);
    # extract source
    my $source = $self->extract_source($build_path, $tmpfile, $bb->{'archive_type'});
    # run prebuild_command
    if(defined($bb->{'prebuild_command'}) && $bb->{'prebuild_command'} ne "" ){
      $bb->{'prebuild_command'} = $self->rep_var($bb->{'prebuild_command'}, $bb);
      $self->pre_post_action($bb->{'prebuild_command'}, "pre", $build_path);
    }
    # configure
    $self->configure($build_path, $source, $bb->{'build_opts'});
    # compile
    $self->make($build_path, $source, $bb->{'make'});
	# befor installing check install_path
	$self->check_install_dir($bb->{'install_path'});
    # install
    $self->make_install($build_path, $source, $bb->{'install'});
    $logger->info("Sucessfully installed $bb->{'app'} $bb->{'version'}");

    # run post build action
    if(defined($bb->{'postbuild_command'}) && $bb->{'postbuild_command'} ne "" ){
      $bb->{'postbuild_command'} = $self->rep_var($bb->{'postbuild_command'}, $bb);
      $self->pre_post_action($bb->{'postbuild_command'}, "post", $build_path);
    }
  }

  if(defined($bb->{'keep_build'}) and $bb->{'keep_build'} eq "true") {
    $logger->info("will keep build directory at $build_path");
    print "will keep build directory at $build_path\n";
  } else {
    # cleanup build path
    qx{rm -rf $build_path};
    qx{rm -rf $tmpfile};
  }
}


1;
