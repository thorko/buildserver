prepare:
	apt-get -y install libarchive-extract-perl libhttp-server-brick-perl libgetopt-long-descriptive-perl libconfig-simple-perl liblog-log4perl-perl libhtml-strip-perl libdata-dump-perl

install:
	mkdir -p /etc/buildctl
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
	-cp -fp buildctl.pl /usr/local/bin/buildctl
	-cp -fp buildctl.conf /etc/buildctl/buildctl.conf
	-cp -fp buildsrv.pl /usr/local/sbin/buildsrv
	-cp -fp buildsrv.conf /etc/buildctl/buildsrv.conf
	-cp -fp buildsrv.service /etc/systemd/system/buildsrv.service
	-systemctl daemon-reload
	-cp -fp buildctl.bash /etc/bash_completion.d/buildctl
	-cp -fpr apps /etc/buildctl/

clean:
	rm -rf /usr/local/bin/buildctl /etc/buildctl /usr/local/sbin/buildsrv /etc/systemd/system/buildsrv.service /etc/bash_completion.d/buildctl
