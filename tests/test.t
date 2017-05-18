#!perl


use lib 'lib';
use Test::More;
use FindBin qw($Bin);
use strict;
use warnings;

my $opt = "-Mlib=$Bin/../lib";
my $config = "-c tests/buildctl.conf";
my $tool = "$^X $opt $Bin/../buildctl.pl $config";

like(qx/$tool -h/, qr/list all versions of applications/, 'check help message');

# list-versions
like(qx/$tool -r list-versions/, qr/php5:  0.0.1  0.0.2/, 'list application versions');

done_testing();
