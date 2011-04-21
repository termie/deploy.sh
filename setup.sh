#!/bin/bash

for d in chef dhcp; do lxc-stop -n $d; rm -rf /var/lib/lxc/$d; done

set -e
set -x

DHCP_RANGE=8.21.28.0/0
# can be calcualted
NETMASK=255.255.255.0
GATEWAY=8.21.28.1

# broken!
MY_IP=`/sbin/ifconfig br0 | grep "inet " | cut -d ':' -f2 | cut -d ' ' -f1`

# these we should intuit

chef_host=8.21.28.240
dhcp_host=8.21.28.241

if [ ! -x /usr/share/doc/apt-cacher ]; then
    apt-get install -y apt-cacher apache2
    sed -i -e 's/^#*AUTOSTART.*/AUTOSTART=1/' /etc/default/apt-cacher
    /etc/init.d/apt-cacher restart
fi

apt-get install -y lxc debootstrap bridge-utils libcap2-bin dsh

if ( ! grep -q cgroup /etc/mtab ); then
    mkdir -p /var/lib/cgroups
    mount -t cgroup cgroup /var/lib/cgroups/
fi

mkdir -p /var/lib/lxc

cat > /var/lib/lxc/builder.conf <<EOF
lxc.network.type=veth
lxc.network.link=br0
lxc.network.flags=up
EOF


if [ ! -f ~/.ssh/id_builder.pub ]; then
    ssh-keygen -d -P "" -f ~/.ssh/id_builder
fi

for d in dhcp chef; do 
    ROOTFS=/var/lib/lxc/${d}/rootfs

    if [ ! -x ${ROOTFS} ]; then
	lxc-create -n ${d} -f /var/lib/lxc/builder.conf -t ubuntu
    fi

    var=\$${d}_host
    IP=`eval echo $var`

    echo Setting ip of ${d} to ${IP}

    # fix up the ip address
    cat > ${ROOTFS}/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0 
iface eth0 inet static
      address $IP
      netmask $NETMASK
      gateway $GATEWAY
EOF

    # set up a sane ubuntu repo
    cat > ${ROOTFS}/etc/apt/sources.list <<EOF
deb http://$MY_IP:3142/mirrors.us.kernel.org/ubuntu lucid main universe
EOF

    # working resolver
    rm -f ${ROOTFS}/etc/resolv.conf
    cat > ${ROOTFS}/etc/resolv.conf <<EOF
nameserver 8.8.8.8
EOF

    # drop the builder ssh key in
    mkdir -p ${ROOTFS}/root/.ssh
    chmod 700 ${ROOTFS}/root/.ssh
    cp ~/.ssh/id_builder.pub ${ROOTFS}/root/.ssh/authorized_keys
    chmod 600 ${ROOTFS}/root/.ssh/authorized_keys


    if [ ! -f /etc/dsh-builder.conf ]; then
	touch /etc/dsh-builder.conf
	chmod 600 /etc/dsh-builder.conf
    fi

    if ( ! grep -q ${IP} /etc/dsh-builder.conf ); then
	echo $USER@$IP >> /etc/dsh-builder.conf
    fi

    # add keyring
    chroot ${ROOTFS} apt-get update
    chroot ${ROOTFS} apt-get install -y --force-yes ubuntu-keyring
    chroot ${ROOTFS} apt-get update

    sed -i -e 's/^#*PermitRoot.*/PermitRootLogin without-password/' ${ROOTFS}/etc/ssh/sshd_config 
    lxc-start -dn ${d}

    # Wait for machine to come up
    if( ! ping -W10 -c1 $IP ); then
	echo "Can't start server.  Bad."
	exit 1
    fi
done

function ssh_it { 
   ssh -i ~/.ssh/id_builder -o StrictHostKeyChecking=no $1 "$2" 
}

ssh_it "root@${chef_host}" "apt-get install -y ruby ruby-dev libopenssl-ruby rdoc ri irb build-essential wget ssl-cert rubygems"
ssh_it "root@${chef_host}" "gem install chef -y --no-ri --no-rdoc"
# cp_it 
# FIXME add solo.rb
# ssh_it "root@${chef_host}" "chef-solo -c /etc/chef/solo.rb -j ~/chef.json -r http://s3.amazonaws.com/chef-solo/bootstrap-latest.tar.gz"



