ifndef _ARCH
  _distro := $(shell lsb_release -i | cut -f2)
  export _distro
endif

prepare:
ifeq ($(_distro),Debian)
	apt-get -y install libarchive-extract-perl libhttp-server-brick-perl libgetopt-long-descriptive-perl libconfig-simple-perl liblog-log4perl-perl libhtml-strip-perl liblinux-distribution-perl libfile-slurp-perl libfile-grep-perl
endif
ifeq ($(_distro),$(filter $(_distro), CentOS Fedora RedHat))
	yum -y install perl-Archive-Extract perl-HTTP-Server-Brick perl-Getopt-Long-Descriptive perl-Config-Simple perl-Log-Log4perl perl-HTML-Strip perl-Linux-Distribution perl-File-Slurp perl-File-Grep
endif

install:
	mkdir -p /etc/buildctl
	cp -fpr lib/Buildctl /usr/share/perl5/
	cp -fp buildctl.pl /usr/local/bin/buildctl
	cp -fp buildctl.conf /etc/buildctl/buildctl.conf
	cp -fp buildsrv.pl /usr/local/sbin/buildsrv
	cp -fp buildsrv.conf /etc/buildctl/buildsrv.conf
	cp -fp buildsrv.service /etc/systemd/system/buildsrv.service
	systemctl daemon-reload
	cp -fp buildctl.bash /etc/bash_completion.d/buildctl
	cp -fpr apps /etc/buildctl/


update:
	-git pull
	-cp -fpr lib/Buildctl /usr/share/perl5/
	-cp -fp buildctl.pl /usr/local/bin/buildctl
	-cp -fp buildctl.conf /etc/buildctl/buildctl.conf
	-cp -fp buildsrv.pl /usr/local/sbin/buildsrv
	-cp -fp buildsrv.conf /etc/buildctl/buildsrv.conf
	-cp -fp buildsrv.service /etc/systemd/system/buildsrv.service
	-systemctl daemon-reload
	-cp -fp buildctl.bash /etc/bash_completion.d/buildctl

update_apps:
	-cp -fpr apps /etc/buildctl/

clean:
	rm -rf /usr/local/bin/buildctl /etc/buildctl /usr/local/sbin/buildsrv /etc/systemd/system/buildsrv.service /etc/bash_completion.d/buildctl /usr/share/perl5/Buildctl

test:
	perl -Mlib=./lib -wc buildctl.pl
	perl tests/test.t
	perl tests/srv.t
