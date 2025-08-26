---
title: "Proxmox Kubernetes Cluster using Cluster API Part 0: Considerations"
date: 2025-04-23T18:32:34+02:00
tags: ['Kubernetes', 'Proxmox']
---

The devloper of Portfolio Performance called working on his Free Software project »Therapeutic Programming«; that is to say, that from time to time, it is salubrious to work on a technical project where you get to make all the design decisions, and no external restrictions are placed on you. Just you and the issue at hand, with no time pressure, or meddling detracting from the enjoyment and discovery. I have learned a lot about the tools i use in my work by finding uses for them in my free time. Usually i come across other people's notes and documentation during this, which have always been very helpful. So, in the tradition of doing that, I will document building my own, homegrown, little datacenter for posterity.

I wanted a setup that can benefit from automation and declarative infrastructure specification, so that I can easily rebuild it, when trouble rears its head. When it came to the applications running on the infrastructure, I already knew, that they would have to tolerate some instability, both due to my tendency to tinker, and because ancient hardware keeps being repurposed and reused, when I am around, meaning that hardware failures are rather likely, eventually. This makes Kubernetes very interesting to me, because it is designed to tolerate *some* instability. Not to mention that it allows me to take advantage of the effort other people put into writing Kubernetes deployments for all the great applications out there.  

If you would like to know why I picked one or the other tool, you can read on, keeping in mind, that this is a hobby project and built above all to my liking.

# Proxmox

I did not want to have to provision and maintain baremetal Kubernetes hosts, because of the frequent releases. VMs are easier to automate using VM images for now, but I am not averse to attempting an image based baremetal deployment later in the future. Beyond that, I wanted a virtualisation environment that »just works«, because I will be the only one maintaining the infrastructure (so no OpenStack). Any of the proprietary virtualisation environments were non-starters because I do not want a nebulous organisation telling me how I can or can not use my own infrastructure. That made the choice very simple. I have actually had a [Proxmox](https://www.proxmox.com/) server whose sole purpose was hosting an NFS server and various LXC containers in my home network for years, and Proxmox has just worked without an issue all this time. Another nice feature is the Ceph with training wheels, that comes with Proxmox. 


This collection of articles assumes that there is a Proxmox installation ready to be used. In the absence of such a thing, take care of [that](https://pve.proxmox.com/pve-docs/chapter-pve-installation.html) first.

# Kubernetes
Without this, there would not be much point to this project. There are many Kubernetes distributions, and dedicated operating systems, such as [Talos](https://www.talos.dev/) or [Flatcar](https://flatcar-linux.org). These are great for minimising the moving parts and risks of clueless hands breaking things (and I think that I will want to try some of them out in the future), but I want to be able to move things around and break things, so that I can learn in the process. That is why I will rely on the [image-builder project](https://github.com/kubernetes-sigs/image-builder) for now, to build standardised Kubernetes VM images. It is a bit bulkier compared to the custom image building processes I have seen before, but in exchange, it is also off-the-rack, which I appreciate.

# Further Tools

- I am already familiar with [Cluster API](https://cluster-api.sigs.k8s.io/), so this was my first choice when it came to managing my cluster. I like, that it is not extremely opinionated like [OKD](https://okd.io/) or full of features i do not need yet, like [Rancher](https://www.rancher.com/). I did take a look at [Gardener](https://gardener.cloud/), to see whether i was missing out on any really great features, but couldn't spot anything immediately obvious.
- I was unaware of [kube-vip](https://kube-vip.io/), when i started planning this, it just came with the default Cluster API resources for Proxmox. But this was very fortunate, because it conveniently solves the issue of providing load balancing for the Kubernetes cluster without requiring any external loadbalancers. Instead, kube-vip runs as a pod in Kubernetes and arranges the configuration of virtual IPs on our nodes as needed
- BGP and Advanced Network Security were features I wanted (I am fairly sure, that i will want to get into datacenter switches eventually). [Cilium](https://cilium.io/) does that, and I am familiar with it. If [Calico](https://www.tigera.io/project-calico/community/) comes along with some really interesting feature later on, I will have a fun migration project, but for now, I picked Cilium to get going faster. 
- I want to work with GitOps for my infrastructure, so that I can quickly update, recreate or get rid of it. I picked [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) for this, because it does all that and even though i usually prefer the command line, sometimes even i like a GUI. And it has a cheery mascot, that looks like an [octopus sausage](https://commons.wikimedia.org/wiki/Category:Octopus-shaped_sausages) wearing a space helmet. I might still give [Flux](https://fluxcd.io/flux/) a go later for fun.

# More to come
A few months have already passed since i began to write this series of articles, but the basic setup is finished, as is most of the content of the articles. It takes a while for me to test and turn my drafts into something i think is actually worth showing to other people. Let's see what the next weeks bring, I hope many good things, some of which will be some more articles of this series.
