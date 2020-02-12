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
		tar -xpzf $ETC -C /tmp;
	else
		echo "Please copy etc.tar.gz with the same path of script."
	fi
fi
}

clean_temp () { ###Function to delete the untar files in temp folder.
        if [[ -d "$1" ]]; then
                rm -r $1  ###Remove the conf files in temp.
        else
                echo "Clean the Temp folder"
        fi
}

extract pkg
whereis squid ###Check to Squid binary and install if it's fail.
if [[ ! $? -eq 0 ]]; then 
	pkg_add gmake gnutls-3.6.10 db-4.6.21p7v0 openldap-client-2.4.48
	PKG_PATH=$dir pkg_add -D unsigned squid35-ldap
	clean_temp $dir
fi


extract etc ###Extract the etc folder to copy the squid configuration.
#cp /tmp/etc/squid/{squid.conf,secret,allow.txt,allow_sales.txt} /etc/squid/
squid -v 
if [[ ! $? -eq 0 ]]; then
	cp -r $dir/* /etc/squid/
fi

rsync --version  ###Check rsync if it's install then using if else statement to install the apps.
if [[ ! $? -eq 0 ]]; then
	pkg_add rsync-3.1.3
	if [[ ! -d "/etc/rsync" ]] && [[ ! -f "/etc/rsyncd.conf" ]] ; then
		cp -r $dir/ /etc/
		cat $dir/rsyncd.conf > /etc/rsyncd.conf
		chgrp -R _rsync /etc/rsync
		chgrp -R _rsync /etc/rsyncd.conf
		rcctl enable rsyncd
		rcctl start rsyncd
		clean_temp $dir 
	fi
fi

squidlog=/var/log/squid ###Check if the logs folder for squid is created.
if [[ ! -d "$squidlog" ]]; then
	mkdir $squidlog
	chown _squid $squidlog
	chgrp _squid $squidlog
	rcctl enable squid
fi

ufdbgclient -v   ###Check ufdbGuard if it's install then using if else statement to install the apps.

if [[ ! $? -eq 0 ]]; then
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

rc_cmd \$1" > /etc/rc.d/ufdb
	chmod a+x /etc/rc.d/ufdb
	cat ~/ufdbGuard.conf > /usr/local/etc/ufdbGuard.conf 
	clean_temp $dir 
fi

extract ufdbguard ###Check if the ufdbguard backup files is copy to var folder.
count=$(ls -ls /var/ufdbguard | wc -l)
if [[ $count -le 1 ]]; then
	cp -r $dir /var
	rcctl enable ufdb
	rcctl start ufdb
	rcctl start squid
	clean_temp $dir
fi
