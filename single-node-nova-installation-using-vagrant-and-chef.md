---
title: single node nova installation using vagrant and chef
---

Integration testing for distributed systems that have many dependencies can be a huge challenge.  Ideally, you would have a cluster of machines that you could PXE boot to a base os install and run a complete install of the system.  Unfortunately not everyone has a bunch of extra hardware sitting around.  For those of us that are a bit on the frugal side, a whole lot of testing can be done with Virtual Machines.  Read on for a simple guide to installing Nova with VirtualBox and Vagrant.

###Installing VirtualBox

VirtualBox is virtualization software by Oracle.  It runs on Mac/Linux/Windows and can be controlled from the command line.  Note that we will be using VirtualBox 4.0 and the vagrant prerelease.

#### OSX

    curl -O http://download.virtualbox.org/virtualbox/4.0.2/VirtualBox-4.0.2-69518-OSX.dmg
    open VirtualBox-4.0.2-69518-OSX.dmg

#### Maverick

    wget -q http://download.virtualbox.org/virtualbox/debian/oracle_vbox.asc -O- | sudo apt-key add -
    echo "deb http://download.virtualbox.org/virtualbox/debian maverick contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
    sudo apt-get update
    sudo apt-get install -y virtualbox-4.0

#### Lucid

    wget -q http://download.virtualbox.org/virtualbox/debian/oracle_vbox.asc -O- | sudo apt-key add -
    echo "deb http://download.virtualbox.org/virtualbox/debian lucid contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
    sudo apt-get update
    sudo apt-get install -y virtualbox-4.0


### Get Vagrant

_Prerelease version no longer necessary. The current version of vagrant (0.7.2) works fine._

#### OSX

    sudo gem update --system
    sudo gem install vagrant

#### Maverick

    sudo gem install vagrant
    sudo ln -s /var/lib/gems/1.8/bin/vagrant /usr/local/bin/vagrant

#### Lucid

    wget http://production.cf.rubygems.org/rubygems/rubygems-1.3.6.zip
    sudo apt-get install -y unzip
    unzip rubygems-1.3.6.zip
    cd rubygems-1.3.6
    sudo ruby setup.rb
    sudo gem1.8 install vagrant

### Get the chef recipes

    cd ~
    git clone http://github.com/cloudbuilders/openstack-cookbooks.git

### Set up some directories

    mkdir aptcache
    mkdir chef
    cd chef

#### Get the chef-solo Vagrantfile

Provisioning for vagrant can use chef-solo, chef-server, or puppet.  We're going to use chef-solo for the installation of nova.

    curl -o Vagrantfile https://gist.github.com/raw/786945/solo.rb

### Running nova

Installing and running nova is as simple as vagrant up

    vagrant up

In 3-10 minutes, your vagrant instance should be running.
NOTE: Some people report an error from vagrant complaining about MAC addresses the first time they vagrant up.  Doing vagrant up again seems to resolve the problem.

    vagrant ssh

Now you can run an instance and connect to it:

    . /vagrant/novarc
    euca-add-keypair test > test.pem
    chmod 600 test.pem
    euca-run-instances -t m1.tiny -k test ami-tty
    # wait for boot (euca-describe-instances should report running)
    ssh -i test.pem root@10.0.0.3

Yo, dawg, your VMs have VMs!  That is, you are now running an instance inside of Nova, which itself is running inside a VirtualBox VM.

When the you are finished, you can destroy the entire system with vagrant destroy. You will also need to remove the .pem files and the novarc if you want to run the system again.

    vagrant destroy

### Using the dashboard

The openstack dashboard should be running on 192.168.86.100.  You can login using username: admin, password: vagrant.
