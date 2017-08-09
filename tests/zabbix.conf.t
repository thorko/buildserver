[config]
# mandatory: the name of the app
app="zabbix"
# mandatory
version="3.2.7"
# build_path: this is the path where all the source gets compiled
build_path="/tmp/zabbix"

# where the app will be installed 
# path will always be extended by the version /usr/local/bind/$version
# mandatory
install_path="/usr/local/zabbix/%version"
# the url where to download the source
url="file:///local/zabbix-%version.tar.gz"

# the archive type of the source
# types: tar, tgz, gz, Z, zip, bz2, tbz, lzma
# mandatory
archive_type="tgz"

# if the build_script option is used the "build_opts", "make" and "install" will not be used, but can still be used at macros in build_script
# in the build script you can use any macro (%version, %app, %url, %build_opts) 
# the script has to be executable and should be a bash script
# specify the full path to it
#build_script="/tmp/test.sh"

# prebuild command
# this command will be run before build_opts are run
#prebuild_command="patch -p < somepatch"

# the confgure options 
# add the full command to run
build_opts="./configure --prefix=%install_path --enable-agent --enable-server --with-libcurl --with-ssh2 --with-mysql=/usr/local/mariadb/current/bin/mysql_config --enable-proxy --enable-java --with-unixodbc --with-openssl=/usr/local/openssl/current"
# the make command to use
make="make"
# the install command to use
install="make install"
# post build actions
# this command will be run after make install was successful
postbuild_command="cp -R zabbix-%version/frontends/php %install_path/frontends; rm -f %install_path/etc/zabbix_agentd.conf && rm -f %install_path/etc/zabbix_server.conf; ln -s /etc/zabbix/zabbix_agentd.conf %install_path/etc/zabbix_agentd.conf && ln -s /etc/zabbix/zabbix_server.conf %install_path/etc/zabbix_server.conf"
# keep build directory
# the build directory and logs will be kept
# even when the build was successful
keep_build=false
