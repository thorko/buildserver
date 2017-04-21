#!/bin/bash

wget -O /tmp/%app.tar.gz %url
if [ $? -ne 0 ]; then
	echo "failed"
	exit 1
fi
tar -xzvf /tmp/%app.tar.gz -C %build_path/
if [ $? -ne 0 ]; then
	echo "failed"
	exit 1
fi


cd %build_path/%app-%version

tp="%install_path"
mkdir -p $tp/etc
cp -p /etc/%app_build/main.cf $tp/etc/
cp -p /etc/postfix_build/master.cf $tp/etc/

make -f Makefile.init makefiles CCARGS='-DHAS_MYSQL -I/usr/local/mariadb/current/include/mysql -DUSE_SSL -I/usr/local/openssl/1.0.2j-sslv2/include -DUSE_TLS -DUSE_SASL_AUTH -DDEF_CONFIG_DIR=\"'$tp'/etc\" -DDEF_DATA_DIR=\"/var/lib/postfix\" -DDEF_COMMAND_DIR=\"'$tp'/sbin\" -DDEF_QUEUE_DIR=\"/var/spool/postfix\" -DDEF_DAEMON_DIR=\"'$tp'/libexec\"' AUXLIBS='-L/usr/lib -L/usr/local/openssl/1.0.2j-sslv2/lib -lmysqlclient -lz -lm -lssl -lcrypto'
if [ $? -ne 0 ]; then
	echo "failed"
	exit 1
fi
make
if [ $? -ne 0 ]; then
	echo "failed"
	exit 1
fi

make upgrade install_root=/ tempdir=/tmp/postfix-%version config_directory=/usr/local/postfix/%version/conf command_directory=/usr/local/postfix/%version/sbin daemon_directory=/usr/local/postfix/%version/libexec data_directory=/var/lib/postfix html_directory=no mail_spool_directory=/var/mail mailq_path=/usr/local/postfix/%version/bin/mailq manpage_directory=/usr/local/postfix/%version/man newaliases_path=/usr/local/postfix/%version/bin/newaliases queue_directory=/var/spool/directory readme_directory=no sendmail_path=/usr/local/postfix/%version/sbin/sendmail
if [ $? -ne 0 ]; then
	echo "failed"
	exit 1
fi

rm -f /tmp/%app.tar.gz
