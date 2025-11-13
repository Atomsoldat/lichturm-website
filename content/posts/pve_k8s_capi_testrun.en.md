---
title: "Proxmox Kubernetes using Cluster-API Part 2: Cluster-API Testrun"
date: 2025-05-23T19:23:12+02:00
tags: ["Kubernetes", "Proxmox"]
---

## Reading material
- https://cluster-api.sigs.k8s.io/user/quick-start.html (Select Proxmox)

## Setup  proxmox cluster-api user account

Our Cluster API provider for Proxmox (CAPMOX) will need to be able to manage resources in Proxmox. We can either follow the [basic instructions](https://github.com/ionos-cloud/cluster-api-provider-proxmox/blob/main/docs/Usage.md#configuring-and-installing-cluster-api-provider-for-proxmox-ve-in-a-management-cluster) of the provider, which may grant a few more permissions than necessary, or we can define a more limited set of permissions  ourselves. For comparison, here's the simple variant using the `PVEVMAdmin` role:

```bash
pveum user add capmox@pve
pveum aclmod / -user capmox@pve -role PVEVMAdmin
pveum user token add capmox@pve capi -privsep 0
```

And here is a somewhat more minimal permission setup I ended up going with, based on the required permissions described [here](https://github.com/ionos-cloud/cluster-api-provider-proxmox/blob/main/docs/advanced-setups.md#proxmox-rbac-with-least-privileges) and some of my own findings:


If we want to use pools for VMs and their templates, we can create some now, using the pve management CLI tools on one of our Proxmox nodes:

```bash
pvesh create /pools --poolid k8s-vms-necropolis --comment "VM pool for necropolis k8s cluster"
pvesh create /pools --poolid k8s-templates-necropolis --comment "Template pool for necropolis k8s cluster"
```

Next are some custom roles for permissions we have to grant in addition to those we can grant with default roles. I like prefixing roles I created, so i can easily tell them apart.

```bash
pveum role add USERDEFINED.capmox-Sys.Audit --privs "Sys.Audit"
pveum role add USERDEFINED.capmox-Datastore.AllocateSpace --privs "Datastore.AllocateSpace"
```


Now we create a user for CAPMOX and grant it membership to the necessary roles at the API paths it will need to have access to. Note that there is a difference in permissions between being `PVEVMAdmin` under `/` and `/vms`. Have a look at the [user management documentation](https://pve.proxmox.com/wiki/User_Management), if you are interested.

```bash
pveum user add capmox-minimal@pve
pveum aclmod / --user capmox-minimal@pve --role USERDEFINED.capmox-Sys.Audit --propagate false
pveum aclmod /nodes --user capmox-minimal@pve --role USERDEFINED.capmox-Sys.Audit --propagate true
pveum aclmod /nodes --user capmox-minimal@pve --role PVEVMAdmin --propagate true
pveum aclmod /vms --user capmox-minimal@pve --role PVEVMAdmin --propagate true
pveum aclmod /pool/k8s-vms-necropolis --user capmox-minimal@pve --role PVEVMAdmin --propagate false
pveum aclmod /pool/k8s-templates-necropolis --user capmox-minimal@pve --role PVETemplateUser --propagate false
pveum aclmod /storage/pve022-nfs-general --user capmox-minimal@pve --role PVEDatastoreAdmin --propagate false
pveum aclmod /storage/ceph_ssd_replicated --user capmox-minimal@pve --role USERDEFINED.capmox-Datastore.AllocateSpace  --propagate false
pveum aclmod /sdn/zones/localnetwork/vmbr0 --user capmox-minimal@pve --role PVESDNUser --propagate false
```

Lastly, we create the token again.

```bash
pveum user token add capmox-minimal@pve capi-token --privsep 0
```

Whichever approach we chose, we will end up with a token that looks something like this:

```
┌──────────────┬──────────────────────────────────────┐
│ key          │ value                                │
╞══════════════╪══════════════════════════════════════╡
│ full-tokenid │ capmox-minimal@pve!capi-token        │
├──────────────┼──────────────────────────────────────┤
│ info         │ {"privsep":"0"}                      │
├──────────────┼──────────────────────────────────────┤
│ value        │ 11111111-2222-aaaa-3333-999999999999 │
└──────────────┴──────────────────────────────────────┘
```


## Creating Cluster-API resources

`clusterctl` requires some configuration parameters, which can be provided via a configuration file. By default, this file is located at `$XDG_CONFIG_HOME/cluster-api/clusterctl.yaml`. The examples here will use a file at a different location, hence the `--config` option.


Here's the configuration file I used, with some explanations. Your's will need to be adapted. Don't forget to replace the placeholder for the secret value.
```yaml
## -- Controller settings -- ##
PROXMOX_URL: "https://pve001.irminsul:8006"                   # The Proxmox VE host
PROXMOX_TOKEN: "capmox@pve!capi-token"                        # The Proxmox VE TokenID for authentication
PROXMOX_SECRET: "REDACTED"                                    # The secret associated with the TokenID

## -- Required workload cluster default settings -- ##
PROXMOX_SOURCENODE: "pve002"                                  # The node that hosts the VM template to be used to provision VMs
TEMPLATE_VMID: "101"                                          # The template VM ID used for cloning VMs
ALLOWED_NODES: "[pve001,pve002,pve020]"                       # The Proxmox VE nodes used for VM deployments
VM_SSH_KEYS: "id_ed25519"                                     # The ssh authorized keys used to ssh to the machines.

# it can be nice to have all the adresses related to a cluster within a single subnet (ingress, controlplane, nodes, ...)
# hence, we can select both an ip_prefix to define the underlying subnet,
# as well as ranges within that subnet to allocate to our nodes
## -- networking configuration-- ##
CONTROL_PLANE_ENDPOINT_IP: "192.168.10.11"                    # The IP that kube-vip is going to use as a control plane endpoint
NODE_IP_RANGES: "[192.168.10.50-192.168.10.100]"              # The IP ranges for Cluster nodes
IP_PREFIX: "24"                                               # Subnet Mask in CIDR notation for your node IP ranges
GATEWAY: "192.168.178.1"                                      # The gateway for the machines network-config.
DNS_SERVERS: "[192.168.178.2, 84.200.69.80, 9.9.9.9]"         # The dns nameservers for the machines network-config.
BRIDGE: "vmbr1"                                               # The network bridge device for Proxmox VE VMs

BOOT_VOLUME_DEVICE: "scsi0"                                   # The device used for the boot disk.
BOOT_VOLUME_SIZE: "50"                                       # The size of the boot disk in GB.
NUM_SOCKETS: "2"                                              # The number of sockets for the VMs.
NUM_CORES: "4"                                                # The number of cores for the VMs.
MEMORY_MIB: "8048"                                            # The memory size for the VMs.

EXP_CLUSTER_RESOURCE_SET: "true"                              # This enables the ClusterResourceSet feature that we are using to deploy CNI
CLUSTER_TOPOLOGY: "true"                                      # This enables experimental ClusterClass templating
```

With these configurations, we can begin by generating the resources that we will be deploying on our initialisation cluster. 

```bash
kind create cluster
kubectl config use-context kind-kind
```

- [CAPMOX XYZ-provider](https://github.com/ionos-cloud/cluster-api-provider-proxmox/tree/main) 
- [in-cluster IPAM-provider](https://github.com/kubernetes-sigs/cluster-api-ipam-provider-in-cluster) 
- [Cluster-API core](https://github.com/kubernetes-sigs/cluster-api)
- [clusterctl CLI](https://cluster-api.sigs.k8s.io/clusterctl/overview)

  - `clusterctl init` [will fetch resources](https://cluster-api.sigs.k8s.io/clusterctl/commands/init#provider-repositories) defined in the respective repositories of the providers installed. These resources can be modified and overriden, refer to the documentation.


If you would like to take a look at what resources exactly `clusterctl init` will install in your cluster (which I recommend you do!), you can do so with the `generate` subcommand. Note, that you can invoke each provider with a specific version, if you want, and that you can use the `--describe` option to get information on the version used, as well as which variables can be set.

```bash
clusterctl generate provider --core  cluster-api  --describe
clusterctl generate provider --core  cluster-api:v1.9.6 --config clusterctl-config.yaml
clusterctl generate provider --infrastructure proxmox --config clusterctl-config.yaml
clusterctl generate provider --ipam in-cluster --describe --config clusterctl-config.yaml
```

Depending on how specific you would like to be, you can specify each provider with its version, or let clusterctl select the default. It will tell you which versions are installed. Note, that `clusterctl init` uses the currently active config from your `~/.kube/config`. If you executed the command to switch context previously, the kind context will be selected. When in doubt, check with `kubectl config current-context`.

```bash
clusterctl init --core cluster-api --ipam in-cluster --infrastructure proxmox --config clusterctl-config.yaml
clusterctl init --infrastructure proxmox --config clusterctl-config.yaml
```

You  may want to manage your Cluster-API providers using GitOps eventually. This is an advanced topic, since there are a lot of interdependencies to be aware of during updates. For the beginning, `clusterctl upgrade` will allow you to upgrade without having to take care of all those yourself.


## Creating a Workload cluster

With the providers running  in our cluster, we can now create the manifests for our actual Kubernetes cluster, and apply them:
```bash
clusterctl generate cluster proxmox-quickstart     --infrastructure proxmox     --kubernetes-version v1.30.11 --control-plane-machine-count 3     --worker-machine-count 1 --config clusterctl-config.yaml   > workload-cluster.yaml
kubectl --context kind-kind apply -f workload-cluster.yaml
```

After this, the Cluster-API components running inside your kind cluster should begin creating VMs in your Proxmox cluster. Depending on how fast your infrastructure is, this will take a while. You can take a look with the `clusterctl` command:

```bash
clusterctl describe cluster proxmox-quickstart
```

Once your cluster has some nodes running, you can get the `kubeconfig`-File to access it as follows:
```bash
clusterctl get kubeconfig nekropolis > nekropolis.kubeconfig
kubectl --kubeconfig nekropolis.kubeconfig get node
```

At this point, no CNI is configured yet. You can either [install it yourself](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/), or use  a `ClusterResourceSet`. This is a [feature provided by Cluster API](https://cluster-api.sigs.k8s.io/tasks/experimental-features/cluster-resource-set) which serves the purpose of automatically applying a set of resources to a newly created cluster, possibly updating them, as the CRS is modified. The kind reader will have to decide whether or not this is beneficial for the use case at hand. On the one hand, for example, this could make the automation of tests easier, on the other hand, it introduces another process modifying things inside our cluster, which can be confusing to people unaware of this. I will demonstrate using a CRS in the next entry of this series.
