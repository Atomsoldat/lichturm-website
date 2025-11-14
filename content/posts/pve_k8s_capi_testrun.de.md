---
title: "Proxmox Kubernetes mittels Cluster-API Teil 2: Cluster-API Testlauf"
date: 2025-05-23T19:23:12+02:00
tags: ["Kubernetes", "Proxmox"]
---

## Lektüre
- https://cluster-api.sigs.k8s.io/user/quick-start.html (Proxmox auswählen)

## Einrichten des Cluster-API Nutzerkontos

Unser Cluster-API provider für Proxmox (CAPMOX) wird in Proxmox Ressourcen verwalten können müssen. Wir können entweder den [grundlegenden Anweisungen](https://github.com/ionos-cloud/cluster-api-provider-proxmox/blob/main/docs/Usage.md#configuring-and-installing-cluster-api-provider-for-proxmox-ve-in-a-management-cluster) des Providers folgen, welche vielleicht einige Berechtigungen mehr vergeben als nötig, oder wir können einen beschränkteren Satz Berechtigungen selbst definieren. Zum Vergleich, hier ist die einfache Variante unter Zuhilfenahme der `PVEVMAdmin` Rolle:

```bash
pveum user add capmox@pve
pveum aclmod / -user capmox@pve -role PVEVMAdmin
pveum user token add capmox@pve capi -privsep 0
```

Und hier folgt die etwas eingeschränktere Variante, die ich auf Basis der vorgeschriebenen Berechtigungen [hier](https://github.com/ionos-cloud/cluster-api-provider-proxmox/blob/main/docs/advanced-setups.md#proxmox-rbac-with-least-privileges) und meinen eignen Experimenten erarbeitet  habe:


Falls wir Pools für unsere VMs und ihre Abbilder verwenden wollen, können wir nun welche mit der PVE-Kommandozeile erstellen:

```bash
pvesh create /pools --poolid k8s-vms-necropolis --comment "VM pool for necropolis k8s cluster"
pvesh create /pools --poolid k8s-templates-necropolis --comment "Template pool for necropolis k8s cluster"
```

Dann folgen einige Rollen fuer  Berechtigungen, die wir zusätzlich zu den Berechtigungne der Standardrollen verteilen wollen. Ich gebe meinen selbst erstellten Rollen gerne ein Präfix, um sie vom Rest abzuheben.

```bash
pveum role add NOCTURNENECROPLEX.capmox-Sys.Audit --privs "Sys.Audit"
pveum role add NOCTURNENECROPLEX.capmox-Datastore.AllocateSpace --privs "Datastore.AllocateSpace"
```

Nun erstellen wir einen Nutzer für CAPMOX und machen diesen zum Mitglied in allen  notwendigen Rollen unter den API-Pfaden, die er benötigen wird. *Nota bene:* Es gibt einen Unterschied darin, ob man `PVEVMAdmin` unter `/` oder `/vms` ist. Falls das interessant klingt kann man dazu gerne die [Dokumentation zur Nutzerverwaltung](https://pve.proxmox.com/wiki/User_Management) zu Rate ziehen.

```bash
pveum user add capmox-minimal@pve
pveum aclmod / --user capmox-minimal@pve --role NOCTURNENECROPLEX.capmox-Sys.Audit --propagate false
pveum aclmod /nodes --user capmox-minimal@pve --role NOCTURNENECROPLEX.capmox-Sys.Audit --propagate true
pveum aclmod /nodes --user capmox-minimal@pve --role PVEVMAdmin --propagate true
pveum aclmod /vms --user capmox-minimal@pve --role PVEVMAdmin --propagate true
pveum aclmod /pool/k8s-vms-necropolis --user capmox-minimal@pve --role PVEVMAdmin --propagate false
pveum aclmod /pool/k8s-templates-necropolis --user capmox-minimal@pve --role PVETemplateUser --propagate false
pveum aclmod /storage/pve022-nfs-general --user capmox-minimal@pve --role PVEDatastoreAdmin --propagate false
pveum aclmod /storage/ceph_ssd_replicated --user capmox-minimal@pve --role NOCTURNENECROPLEX.capmox-Datastore.AllocateSpace  --propagate false
pveum aclmod /sdn/zones/localnetwork/vmbr0 --user capmox-minimal@pve --role PVESDNUser --propagate false
```

Zuletzt erzeugen wir wieder ein Token.

```bash
pveum user token add capmox-minimal@pve capi-token --privsep 0
```

Gleich welche Herangehensweise wir gewählt haben, am  Ende erhalten wir ein Token, das in etwa so aussehen wird:

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


## Erstellen der Cluster-API Resourcen

`clusterctl` benötigt einige Konfigurationsparameter, welche man durch eine Konfigurationsdatei übergeben kann. Standardmäßig ist diese Datei unter `$XDG_CONFIG_HOME/cluster-api/clusterctl.yaml` zu finden. Die Beispiele hier verwenden eine Datei an einem anderen Ort, daher also die `--config` Option.


Hier ist die Konfigurationsdatei, die ich verwendete, mit einigen Erklärungen der Authoren von CAPMOX. Ich habe mir erlaubt, diese unverändert  zu lassen. Die Datei meiner geschätzten Leserschaft wird sicher angepasst werden müssen, nicht zuletzt der Wert für `PROXMOX_SECRET`.

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

## -- networking configuration-- ##
CONTROL_PLANE_ENDPOINT_IP: "192.168.10.11"                    # The IP that kube-vip is going to use as a control plane endpoint
NODE_IP_RANGES: "[192.168.10.50-192.168.10.100]"              # The IP ranges for Cluster nodes
IP_PREFIX: "24"                                               # Subnet Mask in CIDR notation for your node IP ranges
GATEWAY: "192.168.178.1"                                      # The gateway for the machines network-config.
DNS_SERVERS: "[192.168.178.2, 84.200.69.80, 9.9.9.9]"         # The dns nameservers for the machines network-config.
BRIDGE: "vmbr1"                                               # The network bridge device for Proxmox VE VMs

BOOT_VOLUME_DEVICE: "scsi0"                                   # The device used for the boot disk.
BOOT_VOLUME_SIZE: "50"                                        # The size of the boot disk in GB.
NUM_SOCKETS: "2"                                              # The number of sockets for the VMs.
NUM_CORES: "4"                                                # The number of cores for the VMs.
MEMORY_MIB: "8048"                                            # The memory size for the VMs.

EXP_CLUSTER_RESOURCE_SET: "true"                              # This enables the ClusterResourceSet feature that we are using to deploy CNI
CLUSTER_TOPOLOGY: "true"                                      # This enables experimental ClusterClass templating
```

Mit diesen Konfigurationen können wir  nun anfangen, die Ressourcen zu generieren, die wir auf unserem Initialisierungscluster installieren werden.

```bash
kind create cluster
kubectl config use-context kind-kind
```

Wer möchte, darf gerne einen Blick auf die Projekte werfen, die wir gleich nutzen werden:

- [CAPMOX Provider](https://github.com/ionos-cloud/cluster-api-provider-proxmox/tree/main) 
- [in-cluster IPAM-provider](https://github.com/kubernetes-sigs/cluster-api-ipam-provider-in-cluster) 
- [Cluster-API core](https://github.com/kubernetes-sigs/cluster-api)
- [clusterctl CLI](https://cluster-api.sigs.k8s.io/clusterctl/overview)

  - `clusterctl init` wird [Kubernetesmanifeste](https://cluster-api.sigs.k8s.io/clusterctl/commands/init#provider-repositories) holen, welche in den jeweiligen Repositories der jeweils zu installierenden Provider definiert sind. Diese  Ressourcen kann man modifizieren und  überschreiben, siehe dazu die Dokumentation.

Falls wir einen Blick darauf werfen wollen, welche Ressourcen genau `clusterctl init` auf unserem Cluster installieren wird (was ich sehr empfehle!), können wir das mit dem `generate` Unterkommando tun. *Nota bene*: Jeder Provider kann mit, oder ohne spezifische Versionsangabe generiert werden, wenn wir wollen; und die `--describe`-Option können wir verwenden um Informationen über die verwendete Version herauszubekommen, sowie auch welche Variablen wir setzen können.

```bash
clusterctl generate provider --core  cluster-api  --describe
clusterctl generate provider --core  cluster-api:v1.9.6 --config clusterctl-config.yaml
clusterctl generate provider --infrastructure proxmox --config clusterctl-config.yaml
clusterctl generate provider --ipam in-cluster --describe --config clusterctl-config.yaml
```
Je nachdem, wie penibel wir sein wollen, geben wir jeden Provider mit seiner Version an, oder lassen `clusterctl` den Standardwert verwenden. Welche Versionen es verwendet,  wird es uns sagen. *Nota bene*: `clusterctl init` verwendet den aktuell aktiv gesetzten Kontext aus unserer `~/.kube/config`. Falls wir das obige Kommando zum Wechseln des Kontexts ausgeführt haben, wird der `kind`-Kontext ausgewählt sein (das ist der Gewünschte). Im Zweifel können wir mit `kubectl config current-context` nachsehen.

```bash
clusterctl init --core cluster-api --ipam in-cluster --infrastructure proxmox --config clusterctl-config.yaml
clusterctl init --infrastructure proxmox --config clusterctl-config.yaml
```

Irgendwann möchten wir vielleicht  einmal unsere  Cluster-API Provider mit GitOps verwalten. Das ist ein fortgeschritteneres Thema, weil es viele gegenseitige Abhängigkeiten der Komponenten aufeinander gibt, die man bei Aktualisierungen beachten muss. Für den Anfang wird `clusterctl upgrade` uns erlauben, AKtualisierungen durchzuführen, ohne dass wir uns damit auseinandersetzen müssen.


## Erzeugen eines Kubernetesclusters in  Proxmox

Nun, da die Provider in unserem Urcluster laufen, können wir die Manifeste für den eigentlich für uns interessanten Cluster generieren und installieren:

```bash
clusterctl generate cluster proxmox-quickstart     --infrastructure proxmox     --kubernetes-version v1.30.11 --control-plane-machine-count 3     --worker-machine-count 1 --config clusterctl-config.yaml   > workload-cluster.yaml
kubectl --context kind-kind apply -f workload-cluster.yaml
```
Danach sollten die Cluster-API-Komponenten, welche im kind-Cluster laufen anfangen, VMs in Proxmox zu erstellen. Je nachdem, wie schnell die Infrastruktur ist, wird dies etwas dauern. Wir können mit dem `clusterctl`-Kommando nachsehen:

```bash
clusterctl describe cluster proxmox-quickstart
```

Zu diesem Zeitpunkt ist noch kein CNI konfiguriert. Ohne ein CSI ist Kubernetes nicht besonders nützlich, da keine Kommunkation zwischen den  Knoten möglich ist. Cluster-API wird Knoten ohne funktionierendes CNI nicht als funktionsfähig einstufen, und gegebenenfalls aufhören, neue Knoten zu erstellen, da diese offenbar nicht bereit werden. Wir  können das CNI entweder [selbst installieren](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/), oder ein `ClusterResourceSet` verwenden. Das ist eine von Cluster-API bereitgestellte [Funktionalität](https://cluster-api.sigs.k8s.io/tasks/experimental-features/cluster-resource-set), welche dem Zweck dient, automatisch einen Satz Ressourcen auf unserem neu erzeugten Cluster zu installieren, und diese auch möglicherweise zu aktualisieren, wenn das CRS modifiziert wird. Mein geschätzer Leser wird sich selbst entscheiden müssen, ob das für den Anwendungsfall nützlich ist. Einerseits könnte  das die Automatisierung von z.B. Tests vereinfachen, andererseits ist es ein weiterer Vorgang, der in die Konfiguration unseres Clusters eingreift, was Verwirrung bei Leuten stiften kann, die dies nicht wissen. Was es mit einem CRS auf sich hat, zeige ich  in einem folgenden Artikel.

Sobald einige Knoten auf dem Cluster laufen, können wir 
Once your cluster has some nodes running, you can get the `kubeconfig`-File to access it as follows:
```bash
clusterctl get kubeconfig nekropolis > nekropolis.kubeconfig
kubectl --kubeconfig nekropolis.kubeconfig get node
```

## Resümee
Damit sollten wir einen grundsätzlich verwendbaren Kubernetescluster erzeugt haben, mit dem man schon viele interessante Dinge tun kann. In den folgenden Artikeln werden wir noch einige weitere Themen behandeln, wie  das bereits erwähnte CRS oder die Migration unserer Cluster-API Manifeste.