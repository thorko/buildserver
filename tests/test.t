#!perl


use lib 'lib';
use Test::More;
use FindBin qw($Bin);
use strict;
use warnings;

my $opt = "-Mlib=$Bin/../lib";
my $tool = "$^X $opt $Bin/../buildctl.pl";

like(qx/$tool -h/, qr/list all versions of applications/, 'check help message');

done_testing();
