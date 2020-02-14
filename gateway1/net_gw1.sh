#!/bin/sh 
set +o sh

###Check user as permission to access etc folder
if [[ -x /usr/bin/id ]] && (($(id -u) != 0)); then
        echo "${0##*/}: need root privileges"
        exit 1
fi

###Backup file of etc folder and extract using tar
ETC=etc.tar.gz
dir=/tmp/etc
extract_etc="tar -xzpf $ETC -C /tmp"
if [[ -d "$dir" ]]; then
	if [[ $(find $dir -maxdepth 0 -empty -exec echo 0 \;) == 0 ]]; then
        	$($extract_etc);
	fi
else
	if [[ ! -f $ETC ]]; then
        	echo "Please copy etc.tar.gz with the same path of script."
		exit 0
	else
		$($extract_etc);
	fi
fi

verify_int () {   ###Function to verify the interface config file and copy to etc folder.

cmd="find $dir -name $1" 

if [[ $2 -eq 0 ]]; then
	END=$($cmd | wc -l)
elif [[ $2 -eq 1 ]]; then
	END=$(( $($cmd | wc -l) + 1 ))
fi

        i=$2
        while [[ $i -lt $END ]];  do
				
		FILE=$(echo $1 | sed "s/*/$i/");
		int="cat /tmp/etc/$FILE"
		$int;
			while true; do
				echo "Do you want to copy this IP Address to /etc/$FILE ? [Y/N] "
				read yn
					case $yn in
						[Yy]*) $int > /etc/$FILE; break;;
						[Nn]*) echo "Type new IP for $FILE: "; read inet; echo $inet > /etc/$FILE; break;;
						*) echo "Please answer yes or no [Y/N] ";;
					esac
				done 
		(( i += 1 ))
        
	done

}


verify_etc () {    ###Function to verify the file config before creating to etc folder.
etc=$1
int="cat /tmp/etc/$etc"
$int;

	while true;  do
		echo "Do you want to copy this to $etc ? [Y/N] "
		read yn
			case $yn in
				[Yy]*) $int > /etc/$etc; break;;
				[Nn]*) echo "Type new $etc: "; read etconf; echo $etconf > /etc/$etc; break;;
				*) echo "Please answer yes or no [Y/N] ";;
			esac
		done
	
	
}

verify_int hostname.em* 0
verify_int hostname.carp* 1
verify_etc mygate
verify_etc myname
verify_etc hostname.pfsync0
verify_etc sysctl.conf
verify_etc newsyslog.conf
verify_etc resolv.conf
verify_etc relayd.conf
verify_etc ifstated.conf
verify_etc doas.conf

rc_ctlr () {   ###Function for enabling and starting the system.
        sys=/etc/$1.conf
        if [ -f $sys -a -s $sys ]; then
                rcctl enable $1
                rcctl start $1
        fi
}

rc_ctlr relayd

script=/home/scripts/ifstated
extract_script="tar -xvzpf scripts.tar.gz -C /home/" ###compress scripts folder only for exact application of this script
if [[ -d $script ]]; then
        if [[ $(find $script -maxdepth 0 -empty -exec echo 0 \;) == 0 ]]; then
                $extract_script; rc_ctlr ifstated
        fi
else
        $extract_script; rc_ctlr ifstated
fi

sh /etc/netstart ###Restart Network

pfctl -nf /tmp/etc/pf.conf 2>&1 ###Check the Packet Filter configuration for error free

if [ $? -eq 0 ]; then  ###If the PF file is free from error it will apply and load it to the firewall.
        verify_etc pf.conf
	pfctl -F rules -f /etc/pf.conf
else
        echo "Please check pf files and run again this script."
	exit 0
fi


rm -r /tmp/etc  ###Remove the conf files in temp
