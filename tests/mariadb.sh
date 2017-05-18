#!/bin/bash

#wget -O /tmp/app.tar.gz %url
tar -xzvf /tmp/app.tar.gz -C %build_path/

cd /tmp/mariadb/mariadb-%version
cd BUILD 
./autorun.sh

cd ..

./configure --prefix=%install_path --with-mysqld-user=mysql --with-mysqlmanager --enable-profiling --with-plugins=myisam,archive,blackhole,csv,ibmdb2i,innodb_plugin,aria,myisammrg,xtradb,federated,partition,pbxt
