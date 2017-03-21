#!/bin/bash

MACHINES="alveo-solr alveo-sesame alveo-web alveo-pg alveo-rabbitmq"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HOSTSFILE=$DIR/../local.yml

echo "" > $HOSTSFILE

for m in $MACHINES; do
	sudo lxc-destroy -f -n $m

	sudo lxc-create -t centos -n $m
	sudo lxc-start -n $m

	ip="-"
	while [ ${#ip} -lt 7 ]; do
		ip=`sudo lxc-ls -f -F IPV4 --filter="$m" | tail -n1`
		sleep 1
	done

	pass=$(sudo cat /var/lib/lxc/$m/tmp_root_pass)
	echo "Temp root password is $pass"

	echo "" >> $HOSTSFILE
	# Each host gets its own group
	echo "[$m]" >> $HOSTSFILE
	echo -n "$m ansible_ssh_user=devel ansible_ssh_host=$ip" >> $HOSTSFILE

	root=/var/lib/lxc/$m/rootfs/

	# create user
	sudo chroot $root useradd devel
	sudo chroot $root usermod -a -G wheel devel

	# ssh key for devel
	sudo mkdir -p $root/home/devel/.ssh/
	cat ~/.ssh/id_rsa.pub | sudo tee -a $root/home/devel/.ssh/authorized_keys
	sudo chroot $root chown -c devel: /home/devel/.ssh/authorized_keys
	sudo chroot $root chmod -c 0600   /home/devel/.ssh/authorized_keys

	# Password-less sudo for devel
	sudo chroot $root yum install sudo -y
	echo "%wheel ALL=(ALL) NOPASSWD: ALL" | sudo tee $root/etc/sudoers.d/devel-sudo
done

echo "Setting ANSIBLE_HOST_KEY_CHECKING=False"
export ANSIBLE_HOST_KEY_CHECKING=False

ansible all -i $HOSTSFILE -m shell -b -a "uptime"

echo "Wrote inventory: $HOSTSFILE"
