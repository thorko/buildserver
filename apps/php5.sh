#!/bin/bash

wget %url -O /tmp/php5.tar.bz2

cd %build_path
tar -xjvf /tmp/php5.tar.bz2
cd php-%version
sed -i 's/^\(\s*test.*recode_conflict.*\)/#\1/g' configure
sed -i 's/^\(\s*test.*recode_conflict.*\)/dnl \1/g' ext/recode/config9.m4
# make sure curl is correctly linked
if [ ! -L /usr/local/curl/include/curl ]; then
    mkdir -p /usr/local/curl/include
    ln -sfn /usr/include/x86_64-linux-gnu/curl /usr/local/curl/include/curl
fi

LD_LIBRARY_PATH=/usr/local/openssl/current/lib ./configure --prefix=%install_path --with-pear --enable-cli --with-mysql=/usr/local/mariadb/current --with-mysql-sock --enable-calendar --with-pcre-regex --with-mysqli --with-mcrypt --with-recode --with-gd --with-zlib --enable-bcmath --with-pdo-mysql --with-apxs2=/usr/local/apache2/current/bin/apxs --with-freetype-dir --enable-gd-native-ttf --with-gettext --enable-dom --enable-sockets --enable-mbstring --enable-intl --with-jpeg-dir=/usr/lib --with-png-dir --enable-zip --enable-json --enable-exif --with-libxml-dir=/usr/local/libxml2 --enable-opcache --enable-pcntl --with-openssl=/usr/local/openssl/current --with-kerberos=/usr/local/kerberos/current --with-imap=/usr/local/src/imap-2007f --with-imap-ssl=/usr/local/openssl/current --enable-phar --enable-static --disable-shared --with-curl=/usr/local/curl
if [ $? -ne 0 ]; then
	echo "configure failed"
	exit 1
fi

make
if [ $? -ne 0 ]; then
	echo "make failed"
	exit 1
fi

make install
if [ $? -ne 0 ]; then
	echo "install failed"
	exit 1
fi

# after install delete php module line from httpd.conf
sed -i '/^LoadModule php5_module/d' /etc/apache2/httpd.conf

cp libs/libphp5.so /usr/local/php5/%version/lib
