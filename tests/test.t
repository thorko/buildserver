#!perl


use lib 'lib';
use Buildctl::Base;
use Config::Simple;
use Test::More;
use FindBin qw($Bin);
use strict;
use warnings;

my $opt = "-Mlib=$Bin/../lib";
my $config = "tests/buildctl.conf";
my $cfgopt = "-c $config";
my $tool = "$^X $opt $Bin/../buildctl.pl $cfgopt";

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

# delete nginx
like(qx/$tool -r delete -a nginx -v 1.12.0/, qr/Success/, 'delete nginx');

# cleanup
qx(rm -rf tests/apps/nginx);
qx(kill -HUP $pid);

# pack an app
like(qx/$tool -r pack -a apache2 -v 1.2.1 -p \/tmp\//, qr/Packaging apache2 1.2.1: OK/, 'pack app apache2');
qx{rm -f /tmp/apache2-1.2.1.tar.gz};


# test rep_var
my $hash = { install_path => '/usr/local/%app/%version', app => 'bind', version => '9.10.4-P8'};
my $b = Buildctl::Base->new(config => $config, debug => 0);
is($b->rep_var('/usr/local/%app/%version', $hash), '/usr/local/bind/9.10.4-P8', 'test path variable expansion');
# test app config file expansion
my $c = new Config::Simple();
$c->read("tests/mariadb.conf");
my $buildhash = $c->get_block("config");

is($b->rep_var($buildhash->{'install_path'}, $buildhash), '/usr/local/mariadb/5.5.56', 'test build file expansion 1');
is($b->rep_var($buildhash->{'url'}, $buildhash), 'https://downloads.mariadb.org/f/mariadb-5.5.56/source/mariadb-5.5.56.tar.gz/from/http%3A//ftp.hosteurope.de/mirror/mariadb.org/?serve', 'test build file expansion 2');

# test build script expansion
like(qx{$tool -r build -b tests/mariadb.conf}, qr{Run your build script /tmp/test_mariadb/mariadb.sh: ERROR: check your build script and log /tmp/test_mariadb/build.log}, 'create build script');
# clean up
qx{rm -rf /tmp/test_mariadb};

done_testing();
