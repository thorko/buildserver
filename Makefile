prepare:
	apt-get -y install libarchive-extract-perl libhttp-server-brick-perl libgetopt-long-descriptive-perl libconfig-simple-perl liblog-log4perl-perl libhtml-strip-perl libdata-dump-perl

install:
	mkdir -p /etc/tkctl
	cp -fp tkctl.pl /usr/local/bin/tkctl
	cp -fp tkctl.conf /etc/tkctl/tkctl.conf
	cp -fp tksrv.pl /usr/local/sbin/tksrv
	cp -fp tksrv.conf /etc/tkctl/tksrv.conf
	cp -fp tksrv.service /etc/systemd/system/tksrv.service
	systemctl daemon-reload
	cp -fp tkctl.bash /etc/bash_completion.d/tkctl
	cp -fpr apps /etc/tkctl/


update:
	-cp -fp tkctl.pl /usr/local/bin/tkctl
	-cp -fp tkctl.conf /etc/tkctl/tkctl.conf
	-cp -fp tksrv.pl /usr/local/sbin/tksrv
	-cp -fp tksrv.conf /etc/tkctl/tksrv.conf
	-cp -fp tksrv.service /etc/systemd/system/tksrv.service
	-systemctl daemon-reload
	-cp -fp tkctl.bash /etc/bash_completion.d/tkctl
	-cp -fpr apps /etc/tkctl/

clean:
	rm -rf /usr/local/bin/tkctl /etc/tkctl /usr/local/sbin/tksrv /etc/systemd/system/tksrv.service /etc/bash_completion.d/tkctl
