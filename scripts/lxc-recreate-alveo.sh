#!/bin/bash

# MACHINES="alveo-web alveo-pg"
MACHINES="alveo-solr alveo-sesame alveo-rabbitmq"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INVENTORY=$DIR/../local.yml

rm -f $INVENTORY && touch $INVENTORY

for m in $MACHINES; do
	sudo lxc-destroy -f -n $m

	# We want CentOS 6 for
	# CentOS 7 for pg, rabbitmq, 
	if [ "$m" == "alveo-pg" ] || [ "$m" == "alveo-rabbitmq" ]; then
		DIST="ubuntu"
		sudo lxc-create -n $m -t ubuntu
	elif [ "$m" == "something else" ]; then
		DIST="centos"
		sudo lxc-create -n $m -t centos -- -R 7
	else
		DIST="centos"
		sudo lxc-create -n $m -t centos -- -R 6
	fi

	sudo lxc-start -n $m

	ip="-"
	while [ ${#ip} -lt 7 ]; do
		ip=`sudo lxc-ls -f -F IPV4 --filter="$m" | tail -n1`
		sleep 1
	done

	# Works with CentOS but not Ubuntu
	# pass=$(sudo cat /var/lib/lxc/$m/tmp_root_pass)
	# echo "Temp root password is $pass"

	# Each host gets its own group, and the names match
	echo "[$m]" >> $INVENTORY
	echo -n "$m ansible_ssh_user=devel ansible_ssh_host=$ip" >> $INVENTORY

	root=/var/lib/lxc/$m/rootfs/

	# create user
	sudo chroot $root useradd devel
	
	# ssh key for devel
	sudo mkdir -p $root/home/devel/.ssh/
	cat ~/.ssh/id_rsa.pub | sudo tee -a $root/home/devel/.ssh/authorized_keys
	sudo chroot $root chown -cR devel: /home/devel/
	sudo chroot $root chmod -c 0600   /home/devel/.ssh/authorized_keys

	# Password-less sudo for the devel user
	if [ "$DIST" == "centos" ]; then
		sudo chroot $root usermod -a -G wheel devel
		sudo chroot $root yum install sudo -y
		echo "%wheel ALL=(ALL) NOPASSWD: ALL" | sudo tee $root/etc/sudoers.d/devel-sudo
	else
		# sudo chroot $root apt install sudo -y
		sudo chroot $root adduser devel sudo
		echo "%sudo ALL=(ALL) NOPASSWD: ALL" | sudo tee $root/etc/sudoers.d/devel-sudo
	fi

	echo "" >> $INVENTORY
done

echo "Setting ANSIBLE_HOST_KEY_CHECKING=False"
export ANSIBLE_HOST_KEY_CHECKING=False

ansible all -i $INVENTORY -m shell -b -a "uptime"

echo "Wrote inventory: $INVENTORY"

ansible-playbook -i $INVENTORY $DIR/../aepm/site-alveo-solr.yml
ansible-playbook -i $INVENTORY $DIR/../aepm/site-alveo-sesame.yml
ansible-playbook -i $INVENTORY aepm/site-alveo-rabbitmq.yml
# ansible-playbook -i $INVENTORY aepm/site-alveo-pg.yml
