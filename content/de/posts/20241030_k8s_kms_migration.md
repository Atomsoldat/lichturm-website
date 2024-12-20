---
title: "Migration auf KMSv2 in Kubernetes"
# TODO:
# - Umlaute
# - SS
# - Abkuerzung KMS
draft: true
tags: ["Kubernetes"]
---

Wenn in unserem Kubernetescluster Daten im etcd verschluesselt gespeichert werden sollen, braucht der API-Server ein KMS-Plugin (Key Management Service) beim Lesen und Schreiben im etcd. Kubernetes hat in Version 1.29 die KMS-Version 1 abgekuendigt, weshalb letztens eine Migration anstand. Hier gibt es nun also die Schritte, falls jemand von einer Version auf die andere wechselt, oder von einem KMS auf den anderen (in den Beispielen wird es OpenStack Barbican sein).

## Hintergrund

Wenn unser KMS die Eintraege im etcd verschluesselt, stellt es dem chiffrierten Text das Verschluesselungsschema voran. Der API-Server nutzt diese Information, um den richtigen KMS zur Entschluesselung zu verwenden. Hier als Beispiel einmal der Anfang eines Eintrages aus dem etcd:

```
k8s:enc:kms:v1:barbican_v1
```

Ich habe mir eine leichte Doppelung bei der Versionsangabe erlaubt, damit die Konfigurationsbeispiele nachher klarer sind. Ein anderer Eintrag nach dem Wechsel auf KMS Version 2 koennte dann so aussehen:

```
k8s:enc:kms:v2:barbican_v2
```

Die `etcdctl`-Kommandos, mit denen man sich diese Eintraege anschauen kann sind etwas weiter unten vermerkt.

Es sollte also sichergestellt sein, dass fuer jeden Eintrag im etcd immer ein passend benanntes KMS-Plugin verfuegbar ist, ansonsten wird unser API-Server beim Lesen einen Fehler zurueckgeben, und das gilt es zu vermeiden. Aus diesem Grund ist es auch nicht empfehlenswert, den Namen eines KMS Plugins in `/etc/kubernetes/encryptionconfig.yaml` zu veraendern, solange Ressourcen mit diesem Praefix im etcd verschluesselt sind, weil diese dann nicht mehr lesbar sein werden. Ebenso ist es eine schlechte Idee, zwei KMS-Plugins unter demselben Namen zu verwenden. Es folgt also die Methode, die uns solcherlei Scherereien ersparen wird.

## Ueberblick
Folgende Schritte werden durchlaufen werden:
- KMS v1 und v2 werden parallel betrieben 
- Die Praeferenz fuer Verschluesselung wird auf v2 umgestellt
- Alle verschluesselten Ressourcen werden neu verschluesselt
- KMS v2 wird alleine betrieben

Der API-Server nutzt die KMS-Plugins in der Reihenfolge, wie sie in der `/etct/kubernetes/encryptionconfig.yaml` erscheinen, das gilt es zu nutzen und zu beachten, wenn man von einem KMS-Plugin auf das andere wechseln will oder Daten neu verschluesseln moechte.


### KMS v1 und v2 Parallel
Das KMS-Plugin fuer beide Versionen muss fuer den API-Server erreichbar sein, beispielsweise ueber einen Socket. Anschliessend tragen wir das neue KMS-Plugin in unserer `/etc/kubernetes/encryptionconfig.yaml` ein.

```
ENCRYPTION CONFIG GOES HERE
```
### Praeferenz fuer Verschluesselung umstellen
Die neue KMS-Version wird jetzt oberhalb

```
ENCRYPTION CONFIG GOES HERE
```
### Neuverschluesselung aller verschluesselten Ressourcen
Um das Verschluesselungsschema auf die neue KMS-Version umzustellen, erstellen wir alle verschluesselten Ressourcen neu. Die [Kubernetes-Doku](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/#ensuring-all-secrets-are-encrypted) empfiehlt folgendes, simples Kommando:

```
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

Wer etwas mehr Kontrolle haben moechte, kann auch z.B. [folgendes Skript]() nutzen.

```
RESOURCE RECREATION COMMAND HERE
```

```
ETCD CHECKING COMMAND HERE
```
### Alleiniger Betrieb von KMS v2
Nachdem alle verschluesselten Ressourcen die neue KMS-Version nutzen, koennen wir die alte aus der `encryptionconfig.yaml` entfernen. Danach werden die API-Server nacheinander neugestartet und wir sind fertig.

```
ENCRYPTION CONFIG GOES HERE
```


### Fehlerbehebung
Falls wir aus welchen Gruenden auch immer doch in die Situation geraten, dass wir Eintraege im etcd haben, die mit einem nicht (oder falsch) konfigurierten KMS verschluesselt sind, haben wir im Grunde zwei Moeglichkeiten, um die Situation zu beheben:
- Die Eintraege loeschen
  - **HIER QUELLE ANGEBEN**
  - Die Kubernetesentwickler raten darueber hinaus davon ab, manuell im etcd Daten zu veraendern
- Den fehlenden KMS nachkonfigurieren und die Daten neu verschluesseln
