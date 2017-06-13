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


# start server
my $pid = qx($srv > /dev/null 2>&1 & echo \$!);

like(qx/$tool -r repository/, qr/nginx/, 'get repository');
like(qx/$tool -r repository -a nginx/, qr/nginx-1.12.0.tar.gz\tignore/, 'show repository');

# mark package
like(qx/$tool -r mark -a openssl -v 1.0.2l -m k/, qr{Marked tests/repository/openssl/openssl-1.0.2l.tar.gz as keep}, 'mark package openssl');

# list package state
like(qx/$tool -r list -o package_state/, qr{tests/repository/openssl/openssl-1.0.2l.tar.gz\tkeep}, 'list marked packages');

# install nginx
like(qx/$tool -r install -a nginx -v 1.12.0/, qr{/nginx/nginx-1.12.0.tar.gz is set to i}, 'try to install nginx');
like(qx/$tool -r install -a nginx -v 1.12.0 -f/, qr/Success/, 'install nginx');
like(qx/$tool -r install -a mailsrv -v 1.12.0/, qr/ERROR: mailsrv-1.12.0.tar.gz not available in repository/, 'app not available in repository');

like(qx/$tool -r install -a apache -v 1.13.0 /, qr{tests/repository/apache/apache-1.12.0.tar.gz is set to keep}, 'test pinned package apache - error');
like(qx/$tool -r install -a apache -v 1.12.0 /, qr{tests/repository/apache/apache-1.12.0.tar.gz is set to keep}, 'test pinned package apache - install');

# test latest
like(qx/$tool -r install -a nginx -v latest -f/, qr/Success/, 'install latest nginx');

# delete nginx
like(qx/$tool -r delete -a nginx -v 1.12.0/, qr/Success/, 'delete nginx');
like(qx/$tool -r delete -a apache2 -v 1.2.0/, qr/ERROR: apache2: can't delete active version 1.2.0/, 'delete active version apache2');

# cleanup
qx(rm -rf tests/apps/nginx);
qx(kill -HUP $pid);

# test build with app config file
$pid = qx($srv > /dev/null 2>&1 & echo \$!);
my $build_output = qx{$tool -r build -b tests/apache.conf};
like($build_output, qr{Requirements installed: ERROR}, 'install build requirements');
like($build_output, qr{Will download http://localhost:12355/nginx/nginx-1.12.0.tar.gz: OK}, 'test download of build');
like($build_output, qr{Extract archive /tmp/app.tgz to /tmp/apache2: OK}, 'test extract of downloaded source');
like($build_output, qr{Running pre command: OK}, 'test prebuild command');
like($build_output, qr{Configure: OK}, 'test configure of source');
like($build_output, qr{Make: OK}, 'test make of source');
like($build_output, qr{Install: OK}, 'test install of source');
like($build_output, qr{Running post command: OK}, 'test prebuild command');
# cleanup
qx(kill -HUP $pid);

done_testing();
