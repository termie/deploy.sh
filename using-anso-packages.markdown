Cloudbuilers provides custom packages that have been tested more rigorously then the current openstack trunk.  This allows users to try out new features in the openstack code between releases without worrying about stability issues.  There are a few minor differences in deploying nova using these packages.  A set of instructions for getting up and running using the cloudbuilders packages is outlined below.


### Prerequisites

* Ubuntu Maverick __64bit__

The packages currently work with Ubuntu Maverick.

### Add Anso Package Archive

    sudo apt-get -y --force-yes install python-software-properties
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 460DF9BE
    sudo add-apt-repository 'deb http://packages.ansolabs.com/ maverick main'
    sudo apt-get update

### Install Software

    sudo apt-get install -y nova-api nova-compute nova-scheduler nova-network
    sudo apt-get install -y nova-volume nova-objectstore
    sudo modprobe kvm # skip this if you don't have hardware virtualization
    sudo /etc/init.d/libvirt-bin restart
    sudo killall dnsmasq # kill the dnsmasq instance that libvirt runs
    echo "ISCSITARGET_ENABLE=true" | sudo tee /etc/default/iscsitarget
    sudo /etc/init.d/iscsitarget restart
    sudo apt-get install -y rabbitmq-server euca2ools unzip mysql-server

### Create a Volume Group (On Volume Host)

If you want to use nova-volume you need a properly named volume group.  If you have a spare drive on the machine (like /dev/sdb) you can create a volume group like so:

    sudo vgcreate nova-volumes /dev/sdb

If you don't have a spare drive, you can create a flat file to back the volume group. Here is an example for a 10G volume store:

    truncate -s 10G volumes
    DEV=`sudo losetup -f --show volumes`
    sudo vgcreate nova-volumes $DEV


### Adding Images (On Api/Objectstore Host)

Rackspace Cloud Builders has several images available for your testing purposes.  ami-tty is a very small instance, highly useful for testing.  ami-maverick is the Nova port of the most recent Ubuntu release.

    sudo mkdir -p /var/lib/nova/images/
    cd /var/lib/nova/images/
    sudo wget http://images.ansolabs.com/tty.tgz
    sudo tar xfvz tty.tgz
    sudo wget http://images.ansolabs.com/maverick.tgz
    sudo tar xfvz maverick.tgz
    sudo chown -R nova .

### Customize the Conf file

If you want to change any configuration settings, especially network and volume related, you will need to modify /etc/nova.conf. If you are installing onto multiple machines, you will need to setup mysql and make sure all of the machines are using the right flags for:

    --sql_connection
    --s3_host
    --rabbit_host

If you don't have hardware virtualization, you should add the following line:

    --libvirt_type=qemu

### Set up database, admin user, and networks

The database needs to be created as the user nova so that it is accessible by the upstart scripts.  For the rest of the nova-manage commands you can sudo or switch to the nova user.

    sudo su -c "nova-manage db sync" nova
    sudo nova-manage user admin admin
    sudo nova-manage project create admin admin
    sudo nova-manage network create 10.0.0.0/24 8 32

### Make sure ip_forward is enabled

Ip forwarding should be enabled by libvirt, but if it is off for some reason, you can turn it on like so:

    echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

### Start your services

Unlike the default ubuntu packages, the anso packages do not start services by default.  This is because they are designed to be easy to use on multiple machines. You are responsible for creating the db and configuring the system.  When you are ready you enable nova.

    echo "ENABLED=1" | sudo tee /etc/default/nova-common
    sudo start nova-api
    sudo start nova-objectstore
    sudo start nova-scheduler
    sudo start nova-network
    sudo start nova-volume
    sudo start nova-compute

### Export and source credentials for your user

These commands should be run on the host running nova-api. The third command will add the credentials for the admin user to your environment.  The rc file is bash specific, so it will not work correctly with other shells.

    sudo nova-manage project zipfile admin admin nova.zip
    unzip nova.zip
    . novarc

### Run euca-commands

Nova should be ready to go.

    euca-describe-images
    euca-run-instances -t m1.tiny ami-tty
    euca-describe-instances # wait for instance to be in running state
    ssh 10.0.0.3 # password is password

### Multiple hosts

The easiest setup for multiple hosts is to put nova-api, nova-objectstore, nova-scheduler, and nova-network on one machine.  Then you can run nova-compute and nova-volume on the rest of the machines.
