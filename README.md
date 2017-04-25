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
  - Data-Dump

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
