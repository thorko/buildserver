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
like(qx/$tool -r repository -a nginx/, qr/nginx-1.12.0.tar.gz/, 'show repository');
# stop repository server

# install nginx
like(qx/$tool -r install -a nginx -v 1.12.0/, qr/Success/, 'install nginx');

# test latest
like(qx/$tool -r install -a nginx -v latest/, qr/Success/, 'install latest nginx');

# delete nginx
like(qx/$tool -r delete -a nginx -v 1.12.0/, qr/Success/, 'delete nginx');

# cleanup
qx(rm -rf tests/apps/nginx);
qx(kill -HUP $pid);

# test build with app config file
$pid = qx($srv > /dev/null 2>&1 & echo \$!);
my $build_output = qx{$tool -r build -b tests/apache.conf};
like($build_output, qr{Will download http://localhost:12355/nginx/nginx-1.12.0.tar.gz: OK}, 'test download of build');
like($build_output, qr{Extract archive /tmp/app.tgz to /tmp/apache2: OK}, 'test extract of downloaded source');
like($build_output, qr{Running pre command: OK}, 'test prebuild command');
like($build_output, qr{Configure: OK}, 'test configure of source');
like($build_output, qr{Make: OK}, 'test make of source');
like($build_output, qr{Install: OK}, 'test install of source');
# cleanup
qx(kill -HUP $pid);

done_testing();
