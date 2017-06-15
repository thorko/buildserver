#!/bin/bash
php_version="7.0.20"
php_path="/usr/local/php7/7.0.20"
svn_version="1.8.17"
svn_path="/usr/local/subversion/1.8.17"
modsec_version="2.9.1"
modsec_path="/usr/local/modsecurity/2.9.1"

wget http://mirror.serversupportforum.de/apache/httpd/httpd-%version.tar.gz -O %build_path/source.tar.gz
if [ $? -ne 0 ]; then
  echo "Couldn't download"
  exit 1
fi
tar -xzvf %build_path/source.tar.gz -C %build_path/
if [ $? -ne 0 ]; then
  echo "extract failed"
  exit 1
fi
cd %build_path/httpd-%version
CPPFLAGS='-DOPENSSL_NO_SSL2' ./configure --prefix=%install_path --enable-mods-shared='headers authz_svn auth_basic authn_file alias dav_lock dav_fs dav dav_svn cache disk_cache mem_cache ssl cgi rewrite unique_id' --enable-auth-digest --enable-substitute --enable-info --enable-vhost-alias --enable-status --enable-autoindex --enable-log-forensic --with-unique-id --enable-so --enable-deflate --enable-dav --enable-unixd --with-ssl=/usr/local/openssl/current --enable-http2 --enable-ssl-staticlib-deps
if [ $? -ne 0 ]; then
	echo "configure apache failed..."
	exit 1
fi
make
if [ $? -ne 0 ]; then
	echo "ERROR make apache failed..."
	exit 1
fi
make install
if [ $? -ne 0 ]; then
	echo "ERROR make install apache failed..."
	exit 1
fi

# compile php7
cd %build_path
wget http://de2.php.net/get/php-$php_version.tar.bz2/from/this/mirror -O %build_path/php-$php_version.tar.bz2
if [ $? -ne 0 ]; then
  echo "Couldn't download php-$php_version.tar.bz2"
  exit 1
fi
tar -xjvf %build_path/php-$php_version.tar.bz2 -C %build_path/
cd %build_path/php-$php_version
#vim -c '%s/^\(\s*test.*recode_conflict.*\)/#\1/g' -c 'wq!' configure
sed -i 's/^\(\s*test.*recode_conflict.*\)/#\1/g' configure
sed -i 's/^\(\s*test.*recode_conflict.*\)/dnl \1/g' ext/recode/config9.m4
     
LD_LIBRARY_PATH=/usr/local/openssl/current/lib ./configure --prefix=$php_path --with-pear --enable-cli --with-mysql=/usr/local/mariadb/current --with-mysql-sock --enable-calendar --with-pcre-regex --with-mysqli --with-mcrypt --with-recode --with-gd --with-zlib --enable-bcmath --with-pdo-mysql --with-apxs2=%install_path/bin/apxs --with-freetype-dir --enable-gd-native-ttf --with-gettext --enable-dom --enable-sockets --enable-mbstring --enable-intl --with-jpeg-dir=/usr/lib --with-png-dir --enable-zip --enable-json --enable-exif --with-libxml-dir=/usr/local/libxml2 --enable-opcache --enable-pcntl --with-openssl=/usr/local/openssl/current --with-kerberos=/usr/local/kerberos/current --with-imap=/usr/local/src/imap-2007f --with-imap-ssl=/usr/local/openssl/current --enable-phar --enable-static --disable-shared --with-curl=/usr/local/curl
if [ $? -ne 0 ]; then
	echo "configure php failed..."
	exit 1
fi
make
if [ $? -ne 0 ]; then
	echo "ERROR make php failed..."
	exit 1
fi
make install
if [ $? -ne 0 ]; then
	echo "ERROR make install php failed..."
	exit 1
fi

$php_path/bin/pear install Log
if [ $? -ne 0 ]; then
	echo "pear install Log failed"
	exit 1
fi

$php_path/bin/pecl install geoip-1.1.1
if [ $? -ne 0 ]; then
	echo "pecl install GeoIP failed"
	exit 1
fi

# compile subversion for mod_dav_svn
wget http://artfiles.org/apache.org/subversion/subversion-$svn_version.tar.gz -O %build_path/svn-$svn_version.tar.gz
if [ $? -ne 0 ]; then
  echo "Couldn't download subversion-$svn_version.tar.gz"
  exit 1
fi
tar -xzvf %build_path/svn-$svn_version.tar.gz -C %build_path/
cd %build_path/subversion-$svn_version
./configure --with-apxs=%install_path/bin/apxs --prefix=$svn_path
if [ $? -ne 0 ]; then
	echo "configure subversion failed..."
	exit 1
fi
make
if [ $? -ne 0 ]; then
	echo "ERROR make dav_svn failed..."
	exit 1
fi
make install
if [ $? -ne 0 ]; then
	echo "ERROR make install dav_svn failed..."
	exit 1
fi
# copy modules
cp %build_path/subversion-$svn_version/subversion/mod_dav_svn/.libs/mod_dav_svn.so %install_path/modules/
cp %build_path/subversion-$svn_version/subversion/mod_authz_svn/.libs/mod_authz_svn.so %install_path/modules/

# compile mod_security
wget https://www.modsecurity.org/tarball/$modsec_version/modsecurity-$modsec_version.tar.gz -O %build_path/modsecurity-$modsec_version.tar.gz
tar -xzvf %build_path/modsecurity-$modsec_version.tar.gz -C %build_path/
cd %build_path/modsecurity-$modsec_version

./configure --prefix=$modsec_path --with-apxs=%install_path/bin/apxs
if [ $? -ne 0 ]; then
  echo "ERROR failed to configure modsecurity..."
  exit 1
fi
make
if [ $? -ne 0 ]; then
  echo "make modsec failed"
  exit 1
fi
make install
if [ $? -ne 0 ]; then
  echo "make install modsec failed"
  exit 1
fi


# relink everything
cd %install_path
mv conf conf.orig
ln -sfn /etc/apache2 ./conf

#if [ ! -f $ipath/apache2/$apache_version/modules/mod_security2.so ]; then
#	echo "NO mod_security.so installed"
#  exit 1
#fi
#if [ ! -f $ipath/apache2/$apache_version/modules/libphp5.so ]; then
#	echo "NO libphp5.so installed"
#  exit 1
#fi
#if [ ! -f $ipath/apache2/$apache_version/modules/mod_dav_svn.so ]; then
#	echo "NO mod_dav_svn.so installed"
#  exit 1
#fi
#if [ ! -f $ipath/apache2/$apache_version/modules/mod_authz_svn.so ]; then
#	echo "NO mod_authz_svn.so installed"
#  exit 1
#fi
