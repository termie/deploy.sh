#!/bin/bash

set -e

DHCP_RANGE=8.21.28.0/0
# can be calcualted
NETMASK=255.255.255.0
GATEWAY=8.21.28.1

# these we should intuit
chef_host=8.21.28.240
dhcp_host=8.21.28.241

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

    lxc-start -dn ${d}

    sed -i -e 's/^#*PermitRoot.*/PermitRootLogin without-password/' ${ROOTFS}/etc/ssh/sshd_config 
done



