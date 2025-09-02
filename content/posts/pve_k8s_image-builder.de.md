---
title: "Proxmox Kubernetes Cluster mittels Cluster-API Teil 1: Erstellen von VM-Abbildern mithilfe von Image Builder"
date: 2025-04-27T13:58:54+02:00
tags: ['Kubernetes', 'Proxmox']
---

Nachdem wir uns Gedanken darueber gemacht haben, was wir fuer unseren Cluster verwenden wollen, ist der naechste Schritt das Erstellen eines VM-Abbilds, in dem die notwendigen Dinge vorhanden sind, um unsere Kubernetes-VMs zu starten. Das Manuelle Aktualisieren von Knoten mittels kubeadm ist fehleranfaelliger und wir bei steigender Knotenzahl schnell muehselig, sobald wir den niedrigen einstelligen Bereich verlassen.


## VM-Abbilder mit image-builder bauen

Es gibt ein Kubernetesprojekt, welches Vm-Abbilder fuer Cluster-API produziert, und auf den Namen [image-builder](https://github.com/kubernetes-sigs/image-builder) hoert. image-builder kann Abbilder fuer alle moeglichen Virtualisierungsumgebungen erstellen, und im Falle von Proxmox erstellt es eine VM im Proxmoxcluster selbst, um daraus eine Vorlage fuer Kubernetes-VMs zu erstellen. Hinter den Kulissen verwendet es Werkzeuge wie [Packer](https://developer.hashicorp.com/packer) und [Ansible](https://docs.ansible.com/). Es ist etwas schwergewichtiger, als mir lieb ist, aber es hat einen etablierten Nutzerkreis, und bis auf Weiteres, ist mir eine standardisierte Loesung recht willkommen.

Um mit image-builder etwas anfangen zu koennen, brauchen wir einen Ort, an dem die VMs und VM-Abbilder abgelegt werden koennen. Es gibt viele unterstuetzte Speichervarianten fuer Proxmox, und jeder hat eigene Vorliegen. Ich selbst nutze eine NFS-Freigabe, um `.iso`-Dateien zu speichern und halte die virtuellen Festplatten meiner VMs in einem Ceph-Cluster. Was wichtig ist, ist, dass sowohl eine Moeglichkeit, Dateien zu speichern (fuer `.iso`s) als auch Blockspeicher vorhanden sein muss. Hierzu kann man die [Proxmoxdokumentation](https://pve.proxmox.com/wiki/Storage#_storage_types) zu Rate ziehen. Obwohl es dort nicht explizit steht, kann man auch NFS als Speicherumgebung fuer die virtuellen Festplatten (zum Beispiel `QCOW`-Dateien) von VMS verwenden. Fuer Testzwecke habe ich das auch gemacht, als mein Cephcluster noch nicht lief. also sollte man sich nicht von einem nicht vorhandenen Ceph abhalten lassen.

### Auswaehlen eines Speicherorts fur Abbilder und VMs
Je nachdem wie die vorhandene Proxmoxumgebung aussieht, wird mein werter Leser diese oder jene Speicherloesung nutzen wollen. Wenn sich alles auf einem einzelnen Knoten abspielt, ist die Verwendung eines lokalen Verzeichnisses oder Dateisystems eine bequeme (wenn auch weniger robuste) Loesung sein. Ich hatte mehrere Knoten, also musste eine vernetzte Loesung her. Wie bereits erwaehnt, habe ich zeitweise meinen vorhandenen NFS-Server zum Speichern von VM-Abbildern und VM-Dateisystemen verwendet. Das funktionierte auch, allerdings wir das NFS auf Festplatten bereitgestellt, und die Idee, gleichzeitig viele Betriebssysteme auf den selben Festplatten zu betreiben gefiel mir aus Leistungsgruenden einfach nicht (die VMs starteten wesentlich langsamer als auf SSDs). Nicht zuletzt ziehe ich es vor, unnoetigen Verschleiss an beweglichen Teilen zu vermeiden. Also baute ich einen Cephcluster aus SSDs fuer meine VMs, was Proxmox sehr [einfach](https://pve.proxmox.com/wiki/Deploy_Hyper-Converged_Ceph_Cluster) macht. Das wird mir in der Zukunft auch einen Grund liefern, meine Netzwerkkomponenten aufzuruesten (ab und zu eine VM ueber 1 Gb Ethernet  zu migrieren funktioniert natuerlich, aber wenn ich grosse Mengen Daten in Ceph ablege, will ich nicht durch meine Netzwerkbandbreite eingeschraenkt werden, falls ich Daten neu verteilen muss).

### Einrichten eines Nutzerkontos

Zunaechst erstellen wir eine Rolle, die alle Berechtigungen vergibt, welche die [image-builder Dokumentation](https://image-builder.sigs.k8s.io/capi/providers/proxmox#configuration) vorschreit. Ich verwende gerne ein Praefix, um meine selbst erstellen Rollen zu kennzeichen, und sie von den Systemrollen unterscheidbar zu machen.
```bash
pveum role add NOCTURNENECROPLEXImageBuilder --privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit SDN.Allocate SDN.Audit SDN.Use Sys.AccessNetwork Sys.Audit VM.Allocate VM.Audit,VM.Backup,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Console,VM.Migrate,VM.Monitor,VM.PowerMgmt,VM.Snapshot,VM.Snapshot.Rollback"
```

Dann erstellen wir einen Nutzer, dem die Rolle zugewiesen wird, und fuer den wir ein Token erstellen, welches seine vollen Berechtigungen erhaelt.
```bash
pveum user add imagebuilder@pve
pveum aclmod / --user imagebuilder@pve --role NOCTURNENECROPLEXImageBuilder
# --privsep 0 means the token will have the full permissions of the user, rather than a subset
pveum user token add imagebuilder@pve imagebuildertoken --privsep 0
```


Das Resultat sollte in etwa so aussehen:
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

Jetzt koennen wir versuchen, verschiedene API-Pfade, die normalerweise nicht zugaenglich sind, mit em Token abzugrasen (falls Interesse besteht, kann man sich auch einen weitern Nutzer ohne die Berechtigungen erstellen und den Unterschied feststellen).

Hier ist ein Skript, um das Token mit der APi zu verwenden:
```bash
#!/bin/bash

# $1 - API endpoint to access e.g. "/nodes"

export PROXMOX_URL="https://pve-roundrobin.irminsul:8006/api2/json"
export PROXMOX_TOKEN="imagebuilder@pve!imagebuildertoken"
export PROXMOX_SECRET="11111111-aaaa-2222-bbbb-333333333333"

# proxmox uses self signed certificates by default, hence the -k option
curl -k -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}=${PROXMOX_SECRET}" ${PROXMOX_URL}${1}
```

Auf einem der Proxmoxknoten laesst sich  zum Beispiel mit dem Kommando `pvesh get /nodes` feststellen, ob man dieselbe Information erhaelt. Das `pvesh`-Kommando erlaubt Zugriff auf die Gesamtheit der API, unter Verwendung der selben Pfade.

### Abbilder Herstellen

Wenn all diese Vorbereitungen abgeschlossen sind, koennen VM-Abbilder gebaut werden. Die Makefiles im image-builder-Project verwenden Umgebungsvariablen, die sich in einer handlichen Skriptdatei definieren lassen:


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

Als naechstes wir die Skriptdatei eingelesen, das image-builder Repo eingelesen, und dann heisst es warten, bis das Makefile seine Arbeit getan hat.


```bash
source ENV_FILE
git clone https://github.com/kubernetes-sigs/image-builder.git
cd image-builder/images/capi
make deps-proxmox
make-build-proxmox-ubuntu-2404
```

Nach einer Weile (auf meinen Servern dauerte es 15-20 Minuten), sollte der Bauprozess abgeschlossen sein und ein neues VM-Abbild in Proxmox zu sehen sein (falls Packer bei einem Schritt stehen zu bleiben scheint, einfach noch etwas warten, die Prozess kann lange dauern). 

## Eine Anmerkung zu CPU-Architekturen
VMs verwenden virtuelle CPUs, und diese vCPUs haben Befehlssaetze, die mit dem Befehlssatz der ausfuehrenden Mschine kompatibel sein muessen. Proxmox ist sehr Konservativ bei der Auswahl des Befehlssatzes und setzt standardmaessig `qemu64`. Das ist *sehr* kompatibel (zehn Jahre alte CPUs und aelter), aber es laesst auch einiges an Optimierungen aus den Befehlssaetzen modernener CPUs links liegen. Der Hauptnachteil bei der Verwendung eines modernener Befehlssatzes, wie etwa `x86-64-v3`, ist, dass es nicht moeglich sein wird, die VM im laufenden Betrieb auf einen Server mit einer CPU, die den Befehlssatz nicht unterstuetzt, zu migrieren. Die VM wird ausgeschalten und der Befehlssatz angepasst werden muessen. Fuer mich war das wirklich kein Problem, weil ich nicht vorhabe, staendig VMs zu migrieren, und alle meine Prozessoren sowieso denselben Befehlssatz haben. Der geneigte Leser kann selbst entscheiden, wie wichtig Leistung oder Kompatibilitaet mit aelteren Maschinen ihm ist. Der Befehlssatz kann leicht am VM-Abbild in den Hardware-Einstellungen veraendert werden. Alle daraus abgeleiteten VMs werden die Einstellun erben.

## Weitere Lektuere

- [Die image-builder Dokumentation](https://image-builder.sigs.k8s.io/)

Falls von Interesse ist, wie ich image-builder verwende, kann man auch einen Blick auf dieses Repo werfen:

- https://github.com/MausoleumManagement/image-builder-k8s
