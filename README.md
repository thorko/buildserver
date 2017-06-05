[![Build Status](https://travis-ci.org/thorko/buildserver.svg?branch=master)](https://travis-ci.org/thorko/buildserver)
[![Coverage Status](https://coveralls.io/repos/github/thorko/buildserver/badge.svg?branch=master)](https://coveralls.io/github/thorko/buildserver?branch=master)

BUILDCTL
========

# Requirements
```
- perl
  - Archive-Extract
  - HTTP-Server-Brick
  - GetOpt-Long-Descriptive
  - Config-Simple
  - Log-Log4perl
  - HTML-Strip
  - Linux-Distribution

- Supports: Debian, CentOS, RedHat, Fedora
```

# Install
To install the software do
```
make prepare
make install
```

# Update
To update run
```
make update
```

# Remove
This will remove the tool
```
make clean
```

# Configuration of buildctl client
the configuration will be installed in /etc/buildctl/buildctl.conf
```
[log]
loglevel=DEBUG
logfile=/var/log/buildctl.log

[config]
# the root path where the apps will be installed
install_path=/usr/local
# can be systemd or initd
init_sysv=systemd
# restart method
# soft=don't fail when init or systemd file not found
# hard=fail when init or systemd file not found
# ignore=don't restart anything just ignore it
restart=soft
# the path to the repository 
# will be used when packaging apps
repository=/var/repository

[apps]
# 1 = enabled
# 0 = disabled
apache2=1
php5=1

# the server which contains the repository
[repository]
server=127.0.0.1
port=8082
```

## Usage
To build an app from source run
```
buildctl -r build -b /etc/buildctl/apps/dovecot.conf
```
To list all available versions of apps
```
buildctl -r list-versions
```
Get active version of app
```
buildctl -r get-active -a dovecot
```

And more help can be found with
```
buildctl -h
```

### Build file example
You can use macros in app build files
Specify a macro with
```
%<variable>
```

#### an example
```
[config]
app="bind"
version="9.10.4-P6"
build_path="/tmp/build"
install_path="/usr/local/bind/%version"
url="https://www.isc.org/downloads/file/%version/la_%version/bind-9.10.4-p6/?version=tar-gz"
archive_type="tgz"
prebuild_command="patch -p < somepatch"
build_opts="./configure --enable-ipv6 --with-ecdsa --with-openssl=/usr/local/openssl/current --prefix=/usr/local/bind/%version --enable-rrl"
make="make"
install="make install"
postbuild_command="ln -s something"
keep_build=false
```
To get more info about the parameters check build_example.conf

### Build your package
To build your software run
```
buildctl -r build -b <your build file>
```
When done successful you can create the package with
```
buildctl -r pack -a bind -v 9.10.4-P6
```
This will create an Tar/GZ-File in /var/repository/bind

Update an app - will build app and create package in repository path
```
buildctl -r update -b /etc/buildctl/apps/apache2.conf
```

### Repository Server
to start repository server use the configuration file at **/etc/buildctl/buildsrv.conf**
```
[log]
loglevel=INFO
logfile=/var/log/buildsrv.log

[config]
hostname=<your ip or hostname>
port=8080
path=/var/repository
```
Start it with
```
systemctl start buildsrv
```

### Install software from repository server
Show what is available
```
buildctl -r repository         # list all available apps
buildctl -r repository -a bind # list all packages of bind
```
```
buildctl -a bind -v 9.10.4-P6 -r install
```
Install latest version of bind
```
buildctl -a bind -v latest -r install
```
This will download the package from the repository server and install it to 
the **install_path** setting in **/etc/buildctl/buildctl.conf**

Afterwards you can switch to it
```
buildctl -a bind -r list-versions
buildctl -a bind -v 9.10.4-P6 -r switch-version
```
