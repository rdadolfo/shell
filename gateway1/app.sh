#!/bin/sh
set +o sh

###Check user as permission to access etc folder
if [[ -x /usr/bin/id ]] && (($(id -u) != 0)); then
	echo "${0##*/}: need root privileges"
	exit 1
fi

extract () {  ###Function to extract the backup tar file.
dir=/tmp/$1
empty=$(ls -ls | wc -l)
ETC=$1.tar.gz
if [[ -s "$dir" ]] || (($empty != 0)); then
	if [[ -f "$ETC" ]]; then
		 tar -xpzf $ETC -C /tmp
	else
		echo "Please copy $1.tar.gz with the same path of script."
	fi
fi
}

clean_temp () { ###Function to delete the untar files in temp folder.
        if [ -d "$1" ]; then
                rm -r $1  ###Remove the conf files in temp.
	else
                echo "Clean the Temp folder"
        fi
}

extract pkg
whereis squid ###Check to Squid binary and install if it's fail.
if [ ! $? -eq 0 ]; then 
	pkg_add gmake gnutls-3.6.10 db-4.6.21p7v0 openldap-client-2.4.48
	PKG_PATH=$dir pkg_add -D unsigned squid35-ldap
fi
clean_temp $dir

extract etc ###Extract the etc folder to copy the configuration file.
cp -r $dir/squid/* /etc/squid/

cp $dir/mail/{secrets.db,smtpd.conf,spamd.conf,aliases} /etc/mail  ###Setup SMTP for Gmail
chown _smtpd /etc/mail/secrets.db

whereis openvpn ###check if OpenVPN is installed.
if [ ! $? -eq 0 ]; then
	pkg_add openvpn
	cp -r $dir/openvpn /etc
	chown -R _openvpn /etc/openvpn/
	mkdir /var/log/openvpn_server/
	cp $dir/rc.d/openvpn* /etc/rc.d/
fi

whereis rsync  ###Check if rsync is installed.
if [ ! $? -eq 0 ]; then
	pkg_add rsync-3.1.3
	if [ ! -d "/etc/rsync" ]; then
		cp -r $dir/rsync /etc/
		cat $dir/rsyncd.conf > /etc/rsyncd.conf
		chgrp -R _rsync /etc/rsync
		chgrp -R _rsync /etc/rsyncd.conf
		rcctl enable rsyncd
		rcctl start rsyncd
	fi
fi

clean_temp $dir

squidlog=/var/log/squid ###Check if the logs folder for squid is created.
if [ ! -d "$squidlog" ]; then
	mkdir $squidlog
	chown _squid $squidlog
	chgrp _squid $squidlog
	rcctl enable squid
fi

whereis ufdbgclient   ###Check ufdbGuard if it's install then using if else statement to install the apps.
if [ ! $? -eq 0 ]; then
	extract ufdbGuard-1.34.2
	pkg_add bzip2 
	cd $dir
	CFLAGS='-pipe -pthread -O2 -march=native' CC=cc CPP=cpp ./configure --prefix=/usr/local/ --with-bz2=/usr/local
	gmake -j4
	gmake install
	echo "#!/bin/sh  
#
# \$OpenBSD: ufdb,v 1.34.2 2016/02/02 17:51:11 sthen Exp $

daemon=\"/usr/local/bin/ufdbguardd\"

. /etc/rc.d/rc.subr

rc_cmd \$1" > /etc/rc.d/ufdb ###Create runlevel of ufdbGuard
	chmod a+x /etc/rc.d/ufdb
        clean_temp $dir

	cd -
	extract usr_local_etc
        cat /tmp/usr/local/etc/ufdbGuard.conf > /usr/local/etc/ufdbGuard.conf
        clean_temp /tmp/usr

        extract var ###Check if the ufdbguard backup files is copy to var folder.
        cp -r $dir/ufdbguard /var
        rcctl enable ufdb
        rcctl start ufdb
        rcctl start squid
fi

whereis apachectl2
if [ ! $? -eq 0 ]; then
	pkg_add apache-httpd p5-CGI p5-ldap
	extract var
	cp -r $dir/www/htdocs/lightsquid /var/www/htdocs
	cp $dir/www/cgi-bin/* /var/www/cgi-bin/
	cp $dir/www/htdocs/wpad.dat /var/www/htdocs/
	clean_temp $dir
	sed -i '
	s/\#LoadModule\ cgi/LoadModule cgi/g
	269 s/AllowOverride\ None/AllowOverride\ All/
	s/\#AddHandler\ cgi-script/AddHandler\ cgi-script/
	' /etc/apache2/httpd2.conf
	rcctl restart apache2
fi

sed -i -e '48d' -e '/:openfiles\-max\=1024:\\/i \
        :openfiles\=8192:\\\
' -e 's/:openfiles\-max\=1024:\\/:openfiles\-max\=8192:\\/' \
-e 's/:openfiles\-cur\=128:\\/:openfiles\-cur\=8192:\\/' /etc/login.conf


