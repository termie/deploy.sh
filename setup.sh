#!/bin/bash

for d in chef dhcp; do lxc-stop -n $d; rm -rf /var/lib/lxc/$d; done

set -e
set -x

DHCP_LOW=192.168.2.242
DHCP_HIGH=192.168.2.250

# can be calcualted
NETMASK=255.255.255.0
GATEWAY=192.168.2.1

# broken!
MY_IP=`/sbin/ifconfig br0 | grep "inet " | cut -d ':' -f2 | cut -d ' ' -f1`

# these we should intuit

chef_host=192.168.2.240
dhcp_host=192.168.2.241

function ssh_it { 
   ssh -i ~/.ssh/id_builder -o StrictHostKeyChecking=no $1 "$2" 
}

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
	lxc-create -n ${d} -f /var/lib/lxc/builder.conf -t maverick
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
deb http://$MY_IP:3142/mirrors.us.kernel.org/ubuntu maverick main universe
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

    # moved this to the template
    # sed -i -e 's/^#*PermitRoot.*/PermitRootLogin without-password/' ${ROOTFS}/etc/ssh/sshd_config 
    lxc-start -dn ${d}

    # Wait for machine to come up
    if( ! ping -W1 -c20 $IP ); then
	echo "Can't start server.  Bad."
	exit 1
    fi
    
    ssh_it "root@${IP} apt-get update"
#    ssh_it "root@${IP} apt-get install -fy --force-yes"
#    ssh_it "root@${IP} apt-get install -y --force-yes ubuntu-keyring netbase gnupg gpgv"
#    ssh_it "root@${IP} apt-get update"
done


ssh_it "root@${chef_host}" "apt-get install -y ruby ruby-dev libopenssl-ruby rdoc ri irb build-essential wget ssl-cert rubygems"
ssh_it "root@${chef_host}" "gem install chef -y --no-ri --no-rdoc"

TMPDIR=`mktemp -d`
cat > ${TMPDIR}/solo.rb <<EOF
file_cache_path "/tmp/chef-solo"
cookbook_path "/tmp/chef-solo/cookbooks"
recipe_url "http://s3.amazonaws.com/chef-solo/bootstrap-latest.tar.gz"
EOF

cat > ${TMPDIR}/chef.json <<EOF
{
"bootstrap": {
"chef": {
"url_type": "http",
"init_style": "runit",
"path": "/srv/chef",
"serve_path": "/srv/chef",
"server_fqdn": "chef.`hostname -d`",
"webui_enabled": true
}
},
"run_list": [ "recipe[chef::bootstrap_server]" ]
}
EOF

mkdir -p /var/lib/lxc/chef/rootfs/etc/chef
cp ${TMPDIR}/solo.rb /var/lib/lxc/chef/rootfs/etc/chef/
cp ${TMPDIR}/chef.json /var/lib/lxc/chef/rootfs/etc/chef/chef-bootstrap.json

if [ "${TMPDIR}" = "" ]; then
    echo "Close one"
    exit 1
fi

rm -rf "${TMPDIR}"
ssh_it "root@${chef_host}" "/var/lib/gems/1.8/bin/chef-solo -c /etc/chef/solo.rb -j /etc/chef/chef-bootstrap.json -r http://s3.amazonaws.com/chef-solo/bootstrap-latest.tar.gz"

# push up the cookbooks

ssh_it "root@${chef_host}" "apt-get install -y git-core"
ssh_it "root@${chef_host}" "cd /root; git clone https://github.com/openstack/openstack-cookbooks.git"
ssh_it "root@${chef_host}" "ln -s /var/lib/gems/1.8/bin/knife /usr/bin/"
ssh_it "root@${chef_host}" "knife configure -i -y --defaults -r='' -u openstack"
ssh_it "root@${chef_host}" "knife cookbook upload -o /root/openstack-cookbooks/cookbooks -a"

# Chef is done - install dhcp server
ssh_it "root@${dhcp_host}" "apt-get install -y dnsmasq nginx syslinux"
ROOTFS=/var/lib/lxc/dhcp/rootfs

mkdir -p ${ROOTFS}/var/lib/builder
touch ${ROOTFS}/var/lib/builder/hosts.mac

cat > ${ROOTFS}/etc/dnsmasq.conf <<EOF
enable-tftp
tftp-root=/var/lib/builder/tftpboot

interface=eth0
dhcp-no-override
dhcp-hostsfile=/var/lib/builder/hosts.macs
dhcp-boot=pxelinux.0
dhcp-range=eth0,$DHCP_LOW,$DHCP_HIGH,255.255.255.0
EOF

mkdir -p ${ROOTFS}/var/lib/builder/tftpboot
cat > ${ROOTFS}/var/lib/builder/tftpboot/pxelinux.cfg <<EOF
TIMEOUT 1
ONTIMEOUT maverick

LABEL maverick
        MENU LABEL ^Install Maverick
        MENU DEFAULT
        kernel ubuntu-installer/amd64/linux
        append tasksel:tasksel/first="" vga=3841 locale=en_US setup/layoutcode=en_US console-setup/layoutcode=us netcfg/get_hostname=openstack initrd=ubuntu-installer/amd64/initrd.gz preseed/url=http://10.127.48.40/preseed.txt -- console=tty interface=eth0 netcfg/dhcp_timeout=60
EOF

mkdir -p ${ROOTFS}/var/lib/builder/www
cp ~/.ssh/id_builder.pub ${ROOTFS}/var/lib/builder/www/id_dsa.pub
cat > ${ROOTFS}/var/lib/builder/www/preseed.txt <<EOF
d-i pkgsel/install-language-support boolean false
d-i debian-installer/locale string en_US
d-i console-setup/ask_detect boolean false
d-i console-setup/layoutcode string us
d-i clock-setup/utc boolean true
d-i time/zone string UTC

d-i clock-setup/ntp boolean true

d-i netcfg/choose_interface select auto
d-i netcfg/dhcp_timeout string 120
d-i netcfg/get_hostname string os
d-i netcfg/get_domain string openstack.org

d-i mirror/country string manual
d-i mirror/http/directory string /ubuntu
d-i mirror/http/hostname string $MY_IP:3142
d-i mirror/http/proxy string

d-i passwd/root-login boolean true
d-i passwd/root-password password 0penstack
d-i passwd/root-password-again password 0penstack

d-i passwd/make-user boolean false
d-i user-setup/encrypt-home boolean false

d-i pkgsel/include string openssh-server screen vim-nox
d-i pkgsel/update-policy select none

d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev string /dev/sdc
d-i finish-install/reboot_in_progress note

d-i partman-auto/disk string /dev/sda /dev/sdb /dev/sdc

d-i partman-auto/method string lvm
d-i partman-auto-lvm/guided_size string max
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-lvm/device_remove_lvm_span boolean true
d-i partman-auto/purge_lvm_from_device boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-auto-lvm/new_vg_name string raid
d-i partman-lvm/confirm boolean true

d-i partman-auto/expert_recipe string                           \
        boot-root ::                                            \
                40 1 100 ext3                                   \
                        $primary{ } $bootable{ }                \
                        method{ format } format{ }              \
                        use_filesystem{ } filesystem{ ext3 }    \
                        mountpoint{ /boot }                     \
                .                                               \
                10240 2 500000 ext4                             \
                        $lvmok{ }                               \
                        method{ format } format{ }              \
                        use_filesystem{ } filesystem{ ext4 }    \
                        mountpoint{ / }                         \
                .                                               \
                1024 3 120% linux-swap                          \
                        $lvmok{ }                               \
                        method{ swap } format{ }                \
                .

d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select Finish partitioning and write changes to disk
d-i partman/confirm boolean true

d-i pkgsel/install-pattern string ~t^ubuntu-standard$

d-i preseed/late_command string in-target mkdir -p /root/.ssh; in-target chmod 700 /root/.ssh; in-target wget -O /root/.ssh/authorized_keys http://$MY_IP/id_dsa.pub
EOF

mkdir -p ${ROOTFS}/etc/nginx/sites-enabled
cat > ${ROOTFS}/etc/nginx/sites-enabled/default <<EOF
server {
  listen   80; ## listen for ipv4

  server_name  localhost;

  access_log  /var/log/nginx/localhost.access.log;

  location / {
    root   /var/lib/builder/www;
  }
}
EOF
