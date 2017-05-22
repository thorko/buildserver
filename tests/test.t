#!perl


use lib 'lib';
use Buildctl::Base;
use Config::Simple;
use File::Grep qw(fgrep);
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
like(qx/$tool -r help/, qr/use build file to install app/, 'check pod2usage');

# list-versions
like(qx/$tool -r list-versions/, qr/php5:  0.0.1  0.0.2/, 'list application versions');
# list-version of app
like(qx/$tool -r list-versions -a apache2/, qr/apache2:  1.2.0  1.2.1/, 'list version of app apache2');

# get-active
like(qx/$tool -r get-active/, qr/apache2: 1.2.0/, 'get active version');
like(qx/$tool -r get-active -a apache2/, qr/apache2: 1.2.0/, 'get active version of apache');

# switch version
like(qx/$tool -r switch-version -a apache2 -v 1.2.1/, qr/apache2: switched to 1.2.1/, 'switched to version 1.2.1');
like(qx/$tool -r switch-version -a apache2 -v 1.2.0/, qr/apache2: switched to 1.2.0/, 'switched to version 1.2.0');
like(qx/$tool -r switch-version -a apache2 -v 1.2.0/, qr/WARN: start-stop script couldn't be found/, 'check warning of service action');

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
is($b->rep_var($buildhash->{'make'}, $buildhash), 'make %test', 'test failed macro expansion');

# test build file missing
is($b->build(""), 0, 'test build file missing');
is($b->build("/tmp/t"), 0, 'test build file does not exist');

# test build script expansion
like(qx{$tool -r build -b tests/mariadb.conf}, qr{Run your build script /tmp/test_mariadb/mariadb.sh: ERROR: check your build script and log /tmp/test_mariadb/build.log}, 'create build script');
my $scriptfile = "/tmp/test_mariadb/mariadb.sh";
ok((fgrep { /https.*mariadb-5\.5\.56\.tar\.gz/ } $scriptfile) == 1, 'found version in url');
ok((fgrep { /configure.*mariadb.5\.5\.56 --with/ } $scriptfile) == 1, 'found version in configure line');
# clean up
qx{rm -rf /tmp/test_mariadb};

done_testing();
