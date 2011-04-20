NOTE:  This is only for the brave of heart at the moment.  The instructions below are highly experimental.  If you just want to kick the tires, we suggest you see our instructions on single node vagrant testing.

### Get the latest Virtual Box

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

### Get the chef recipes:

    cd ~
    git clone git://github.com/cloudbuilders/openstack-cookbooks

### Set up some directories

    mkdir aptcache
    mkdir chef
    cd chef

### Get and run the chef-server Vagrantfile

    curl -o Vagrantfile https://gist.github.com/raw/786945/server.rb
    # the chef server takes two runs to provision properly
    vagrant up chef; vagrant provision chef; vagrant up


### Set up routing

If you want to be able to ping your instance from the host machine, you can add a route to enable this:

#### OSX

    route add -net 10.0.0.0/8 192.168.76.101

#### Linux

    route add -net 10.0.0.0/8 gw 192.168.76.101

When you are finished, you can clean up like so:

#### OSX

    route delete -net 10.0.0.0/8 192.168.76.101
    vagrant destroy

#### Linux

    route delete -net 10.0.0.0/8 gw 192.168.76.101
    vagrant destroy
