package Buildctl::Base;

use strict;
use warnings;


sub new {
	my $pkg = shift;
	my $self = bless {}, $pkg;

	return $self;
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
