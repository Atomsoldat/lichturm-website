---
title: "Proxmox Kubernetes using Cluster-API Part 1: Preparing Images using Image Builder"
date: 2025-04-27T13:58:54+02:00
tags: ['Kubernetes', 'Proxmox']
---

After thinking about what to use for the Kubernetes cluster, the next step is building an image with the necessary software to start our VMs from. Manually updating nodes with kubeadm is not just more error-prone, it also gets tedious quickly once we have more than a low single digit numbers of nodes.


## Building Images with image-builder

There is an official kubernetes project which produces VM-images for Cluster API called [image-builder](https://github.com/kubernetes-sigs/image-builder). image-builder can produce images for all kinds of virtualisation environments, and in the case of Proxmox, it starts a VM on the Proxmox Cluster to produce the VM template for Kubernetes. Under the hood, tools like [Packer](https://developer.hashicorp.com/packer) and [Ansible](https://docs.ansible.com/) are used. It is a bit on the heavy side, but it has a community around it, and for now, i like having something a bit more standardised.

In order to do anything useful with image-builder, a place to put the images and VMs, that will be built, is needed. There are many supported storage options for Proxmox, and everyone has his own preferences. I use an NFS share to store `.iso` files and keep my VM disks in a ceph cluster. What is important, that a way of storing both files (for `.iso`s) as well as block storage is needed. Refer to the [Proxmox documentation](https://pve.proxmox.com/wiki/Storage#_storage_types). Despite what is said there, NFS can be used to back VM disks, such as on `QCOW` files. I did that for testing purposes, when i did not have my ceph cluster running yet. So don't let the lack of a ceph cluster stop you.

### Choosing Storage for our Images and VMs

Depending on how your Proxmox environment looks, you will likely want to use different types of storage. If everything is happening on one node anyway, using a local directory or filesystem can be an easy (albeit less robust) solution. I had multiple nodes, so a remoteley available solution was desirable. I tested using my existing NFS server both for ISO storage as well as for storing the live VM images. It worked, but my NFS storage is backed by hard disks, and I did not like the idea of having many operating systems running on it, for performance reasons (the VMs did take longer to boot than on SSDs), and because I prefer to avoid wearing out moving parts by constantly moving them. So i built a Ceph cluster out of SSDs for my VMs, which Proxmox makes very [easy](https://pve.proxmox.com/wiki/Deploy_Hyper-Converged_Ceph_Cluster). This will also give me a reason to upgrade my network equipment later (migrating a few VMs over 1 Gb Ethernet works fine, but if I ever decide to store large amounts of data in Ceph, i do not want to be restricted by the network bandwidth during rebalancing).

### Preparing a User Account

First we create a role that posesses all the permissions listed as required by the [image-builder documentation](https://image-builder.sigs.k8s.io/capi/providers/proxmox#configuration). I like to prefix my custom roles with an identifier, so that they are easy to tell apart from the default roles.
```bash
pveum role add NOCTURNENECROPLEXImageBuilder --privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit SDN.Allocate SDN.Audit SDN.Use Sys.AccessNetwork Sys.Audit VM.Allocate VM.Audit,VM.Backup,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Console,VM.Migrate,VM.Monitor,VM.PowerMgmt,VM.Snapshot,VM.Snapshot.Rollback"
```

Next, we create a user posessing that role and issue a token for that user, which gets his full permissions.

```bash
pveum user add imagebuilder@pve
pveum aclmod / --user imagebuilder@pve --role NOCTURNENECROPLEXImageBuilder
# --privsep 0 means the token will have the full permissions of the user, rather than a subset
pveum user token add imagebuilder@pve imagebuildertoken --privsep 0
```


The result should look something like this:
```
┌──────────────┬──────────────────────────────────────┐
│ key          │ value                                │
╞══════════════╪══════════════════════════════════════╡
│ full-tokenid │ imagebuilder@pve!imagebuildertoken   │
├──────────────┼──────────────────────────────────────┤
│ info         │ {"privsep":"0"}                      │
├──────────────┼──────────────────────────────────────┤
│ value        │ 11111111-aaaa-2222-bbbb-333333333333 │
└──────────────┴──────────────────────────────────────┘
```

Now we can test our token by trying to access API paths, that would normally be restricted (if you want, create another user without the role and see the difference):

Here is a script for querying the API with your token:
```bash
#!/bin/bash

# $1 - API endpoint to access e.g. "/nodes"

export PROXMOX_URL="https://pve-roundrobin.irminsul:8006/api2/json"
export PROXMOX_TOKEN="imagebuilder@pve!imagebuildertoken"
export PROXMOX_SECRET="11111111-aaaa-2222-bbbb-333333333333"

# proxmox uses self signed certificates by default, hence the -k option
curl -k -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}=${PROXMOX_SECRET}" ${PROXMOX_URL}${1}
```

You can confirm that you are getting the same information on one of your Proxmox nodes running e.g. `pvesh get /nodes`. The `pvesh` command allows access to the entirety of the Proxmox API, using the same paths.

### Building Images

With all this prepared, the VM images can be built. The Makefiles used in image builder accept environment variables, which can be set in a small environment file:


```bash
# imagebuilder will create a VM using these credentials
export PROXMOX_USERNAME="imagebuilder@pve!imagebuildertoken"
export PROXMOX_TOKEN="11111111-aaaa-2222-bbbb-333333333333"

# where image builder will contact the Proxmox-API
export  PROXMOX_URL="https://pve002.irminsul:8006/api2/json"

# network interface the VM will use
export PROXMOX_BRIDGE="vmbr0"

# where the VM will run
export PROXMOX_NODE="pve002"

# where the base VM image will be stored
# isos can not be stored on rbd
# https://forum.proxmox.com/threads/isos-on-rbd.18031/
export PROXMOX_ISO_POOL="pve001-nfs-general"

# where the building-VM and the resulting template will be stored
export PROXMOX_STORAGE_POOL="ceph_ssd_replicated"

# visiting here
# https://build.opensuse.org/project/subprojects/isv:kubernetes:core:stable
# we can find the repository for each version, such as here
# https://build.opensuse.org/repositories/isv:kubernetes:core:stable:v1.30
# by visiting the published deb repository, we can visit the download repo here
# https://download.opensuse.org/repositories/isv:/kubernetes:/core:/stable:/v1.30/deb/amd64/
# and that is where the funny extra version in the deb packages is derived from
# see also https://image-builder.sigs.k8s.io/capi/providers/proxmox#configuration
# The full list of available environment vars can be found in the variables section of images/capi/packer/proxmox/packer.json
export PACKER_FLAGS="--var 'kubernetes_semver=v1.30.11' --var 'kubernetes_series=v1.30' --var 'kubernetes_deb_version=1.30.11-1.1'"

# increase the building VMs memory, so we have some breathing room
export PACKER_FLAGS="$PACKER_FLAGS --var memory=8192"

# set a custom name
export PACKER_FLAGS="$PACKER_FLAGS --var artifact_name=kube-template-v1.30.11"
```


Next, we will source that environment file, clone the image builder repository and wait for the images to build as the Makefile does its work.


```bash
source ENV_FILE
git clone https://github.com/kubernetes-sigs/image-builder.git
cd image-builder/images/capi
make deps-proxmox
make-build-proxmox-ubuntu-2404
```

After a while (on my hardware it took 15-20 minutes) the build process should be finished and you should see a new VM template available in Proxmox (if the packer tool seems to be stuck at a certain task, give it a bit of time). 

## A note on CPU architecture
VMs use vCPUs, and those vCPUs have instruction sets that need to be compatible with the host machine's CPU. Proxmox is very conservative with this setting and sets `qemu64` by default. That is *very* compatible (think CPUs over ten years old), but also leaves a lot of optimisation from instruction sets provided by more modern cpus on the table. The main downside to setting a more modern instruction set, such as `x86-64-v3`, is that you will not be able to live migrate a VM with that instruction set to a host with a CPU that does not support it. You will have to turn the VM off and change the vCPU instruction set. For me, this was really not an issue, since i don't really intend to use live-migration that much, and all my hosts have the same CPUs anyway. You can judge for yourself, how important performance or compatibility with older hosts is to you. You can simply set the vCPU-setting in the hardware section of your VM template, that image-builder creates for you, any VMs derived from it, will inherit the setting.

## Further Reading

- [The image builder documentation](https://image-builder.sigs.k8s.io/)

You can also feel free to take a look at my own repository, if you are interested in how i use image-builder for my project:

- https://github.com/MausoleumManagement/image-builder-k8s
