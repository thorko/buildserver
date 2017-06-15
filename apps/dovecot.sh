#!/bin/bash

wget --prefer-family=IPv4 %url -O %build_path/source.tar.gz
if [ $? -ne 0 ]; then
  echo "download dovecot failed"
  exit 1
fi
cd %build_path
tar -xzvf %build_path/source.tar.gz -C %build_path/
if [ $? -ne 0 ]; then
  echo "extract dovecot failed"
  exit 1
fi
cd %app-%version

./configure --prefix=/usr/local/dovecot/%version --with-shadow --with-pam --with-ssl=openssl --with-mysql --sysconfdir=/etc
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

ln -s /etc/dovecot %install_path/etc

wget --prefer-family=IPv4 %pigeonhole_url -O %build_path/pigeonhole.tar.gz
if [ $? -ne 0 ]; then
  echo "download pigeonhole failed"
  exit 1
fi
cd %build_path
tar -xzvf %build_path/pigeonhole.tar.gz -C %build_path/
if [ $? -ne 0 ]; then
  echo "extract pigeonhole failed"
  exit 1
fi

cd dovecot-2.2-pigeonhole-%pigeonhole_version
./configure --with-dovecot=/usr/local/dovecot/%version/lib/dovecot
if [ $? -ne 0 ]; then
  echo "configure pigeonhole failed"
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
