#!perl


use lib 'lib';
use Test::More;
use FindBin qw($Bin);
use strict;
use warnings;

my $opt = "-Mlib=$Bin/../lib";
my $config = "-c tests/buildctl.conf";
my $tool = "$^X $opt $Bin/../buildctl.pl $config";

my $srv = "$^X $opt $Bin/../buildsrv.pl -c tests/buildsrv.conf";

like(qx/$tool -h/, qr/list all versions of applications/, 'check help message');

# list-versions
like(qx/$tool -r list-versions/, qr/php5:  0.0.1  0.0.2/, 'list application versions');

# get-active
like(qx/$tool -r get-active/, qr/apache2: 1.2.0/, 'get active version');

# switch version
like(qx/$tool -r switch-version -a apache2 -v 1.2.1/, qr/apache2: switched to 1.2.1/, 'switched to version 1.2.1');
like(qx/$tool -r switch-version -a apache2 -v 1.2.0/, qr/apache2: switched to 1.2.0/, 'switched to version 1.2.0');
like(qx/$tool -r switch-version -a apache2 -v 1.2.0/, qr/WARN: start-stop script couldn't be found/, 'check warning of service action');

# test repository
# start server
my $pid = qx($srv > /dev/null 2>&1 & echo \$!);
like(qx/$tool -r repository -a nginx/, qr/nginx-1.12.0.tar.gz/, 'show repository');
# stop repository server

# install nginx
like(qx/$tool -r install -a nginx -v 1.12.0/, qr/Success/, 'install nginx');

# cleanup
qx(rm -rf tests/apps/nginx);
qx(kill -HUP $pid);
done_testing();
