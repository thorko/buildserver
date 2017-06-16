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

like(qx/$tool -h/, qr/requires: --option/, 'check help message');
like(qx/$tool -r help/, qr/use build file to install app/, 'check pod2usage');

# list-versions
like(qx/$tool -r list -o version/, qr/php5:  0.0.1  0.0.2/, 'list application versions');
# list-version of app
like(qx/$tool -r list -o version -a apache2/, qr/apache2:  1.2.0  1.2.1/, 'list version of app apache2');

# get-active
like(qx/$tool -r get-active/, qr/apache2: 1.2.0/, 'get active version');
like(qx/$tool -r get-active -a apache2/, qr/apache2: 1.2.0/, 'get active version of apache');

# switch version
like(qx/$tool -r activate -a apache2 -v 1.2.1/, qr/apache2: activated 1.2.1/, 'switched to version 1.2.1');
like(qx/$tool -r activate -a apache2 -v 1.2.0/, qr/apache2: activated 1.2.0/, 'switched to version 1.2.0');
like(qx/$tool -r activate -a apache2 -v 1.2.0/, qr/WARN: start-stop script couldn't be found/, 'check warning of service action');

# pack an app
like(qx/$tool -r pack -a apache2 -v 1.2.1/, qr/Packaging apache2 1.2.1: OK/, 'pack app apache2');
qx{rm -f /tmp/apache2/apache2-1.2.1.tar.gz};

# update an app
like(qx/$tool -r update -b tests\/mariadb.conf/, qr/Updating app: mariadb to 5.5.56/, 'update app mariadb');

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

is($b->switch_version("", ""), 1, 'switch_version without app');
is($b->switch_version("apache2", "1.9.0"), 1, 'switch_version version not available');
is($b->switch_version("apache2", "1.9.0"), 1, 'switch_version version not available');

is($b->download("http://tt.tt/tt.tar.gz", "/tmp/a.tar.gz"), 1, 'failed download');

# test build file missing
is($b->build(""), 1, 'test build file missing');
is($b->build("/tmp/t"), 1, 'test build file does not exist');

# pack
is($b->pack("apache2", ""), 1, "pack - required options missing");
is($b->pack("apache2", "1.2.0"), 0, "pack - couldn't pack");

# test build script expansion
like(qx{$tool -r build -b tests/mariadb.conf}, qr{Run your build script /tmp/test_mariadb/mariadb.sh: ERROR: check your build script and log /tmp/test_mariadb/build.log}, 'create build script');
my $scriptfile = "/tmp/test_mariadb/mariadb.sh";
ok((fgrep { /https.*mariadb-5\.5\.56\.tar\.gz/ } $scriptfile) == 1, 'found version in url');
ok((fgrep { /configure.*mariadb.5\.5\.56 --with/ } $scriptfile) == 1, 'found version in configure line');
# clean up
qx{rm -rf /tmp/test_mariadb};

# test full build script expansion
qx{$tool -r build -b tests/php.conf};
$scriptfile = "/tmp/php7/php.sh";
ok((fgrep { /touch \/tmp\/php7\/1.0.2l/ } $scriptfile) == 1, 'found openssl version in script');
ok((fgrep { /echo \/usr\/local\/openssl\/1.0.2l/ } $scriptfile) == 1, 'found openssl version in script');

# clean up
qx{rm -rf /tmp/php7};

like(qx{$tool -r build -b tests/missing_variable.conf}, qr{ERROR: Missing mandatory config variable}, 'test with missing mandatory variable');


done_testing();
