---
title: Deployment
layout: default
---

# Cloud Builder Docs

## documents

 * [hacking nova](hacking-nova.html)
 * [single node nova installation using vagrant and chef](single-node-nova-installation-using-vagrant-and-chef.html)
 * [multi node nova installation using vagrant and chef](multi-node-nova-installation-using-vagrant-and-chef.html)
 * [using dev packages](using-dev-packages.html)

## scripts

### lxc + ubuntu powered demo/testing deployment:

From a base maverick install, use LXC to configure a multi-mode openstack deployment using:

 * DHCP: pxe + preseed, tftp, dnsmasq
 * CHEF: chef-server, openstack recipes

        curl -Sks https://github.com/cloudbuilders/deploy.sh/raw/master/setup.sh | /bin/bash

