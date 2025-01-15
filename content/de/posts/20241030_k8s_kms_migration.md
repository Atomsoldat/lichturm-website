---
title: "Migration von KMSv1 auf KMSv2 in Kubernetes"
tags: ["Kubernetes"]
---

## Nota Bene
Bevor irgendwelche Arbeiten, die den etcd betreffen gemacht werden, ist es unabdingbar, von diesem [Backups anzufertigen](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster). Generell ist das mehr als empfehlenswert, wenn man einen Kubernetescluster betreibt, und zwar regelmässig und automatisiert. Mit der Funktion und Administration von etcd sollte man sich ebenso vertraut machen. Nun, da wir diese Vorkehrungen getroffen haben, können wir uns an die eigentliche Arbeit machen.


## Für und Wider
Diverse Regelwerke schreiben die Verschlüsselung von geheimen Daten vor. Man könnte deswegen der Meinung sein, dass man auch die Geheminisse in seinem etcd verschlüsseln sollte. Oder man könnte der Meinung sein, dass ein potenzieller Angreifer bereits irgendeine Art von Zugriff auf das Betriebssystem, auf dem der etcd-Prozess läuft, haben muss (vorausgesetzt man erlaubt nur die notwendigen Netzwerkverbindungen). Dass es deswegen wenig nützt zusätzliche Geheimniskrämerei für Dinge zu betreiben, die Anwendungen im Cluster notwendigerweise im Klartext lesen können müssen, solange man seine Datenträger selbst verschlüsselt ([hier](https://www.macchaffee.com/blog/2022/k8s-secrets/) ein gut geschriebener Artikel, der das Sicherheitsthema etwas mehr ausleuchtet). Aber am Ende kann es einem trotzdem passieren, dass man einen Cluster verwalten muss, in dem die Entscheidung fiel, die erstere Herangehensweise zu wählen.

## Hintergrund und Funktionsweise 
Wenn in unserem Kubernetescluster Daten im etcd verschlüsselt gespeichert werden sollen, braucht der API-Server ein KMS-Plugin (Key Management Service) beim Lesen und Schreiben im etcd. Der KMS kümmert sich um die Entschlüsselung des Geheimtextes und gibt dem API-Server den Klartext zurück. Kubernetes hat in Version 1.29 die KMS-Version 1 abgekündigt, weshalb letztens eine Migration anstand. Hier gibt es nun also die Schritte, falls jemand von einer Version auf die andere wechselt, oder von einem KMS auf den anderen (in den Beispielen wird es OpenStack Barbican sein).

Wenn unser KMS die Einträge im etcd verschlüsselt, stellt es dem chiffrierten Text das Verschlüsselungsschema voran. Der API-Server nutzt diese Information, um den richtigen KMS zur Entschlüsselung zu verwenden. Hier als Beispiel einmal der Anfang eines Eintrages aus dem etcd:

```
k8s:enc:kms:v1:barbican_v1
```

Ich habe mir eine leichte Doppelung bei der Versionsangabe erlaubt (der letzte Teil dieses Präfixes ist abhängig vom Namen des jeweiligen KMS-Plugins, welcher frei gewählt werden kann), damit die Konfigurationsbeispiele nachher klarer sind. Ein anderer Eintrag nach dem Wechsel auf KMS Version 2 könnte dann so aussehen:

```
k8s:enc:kms:v2:barbican_v2
```

Die `etcdctl`-Kommandos, mit denen man sich diese Einträge anschauen kann sind etwas weiter unten vermerkt.

Da der Name des Plugins Teil des Präfixes ist, sollte also sichergestellt sein, dass für jeden Eintrag im etcd immer ein passend benanntes KMS-Plugin verfügbar ist. Ansonsten wird unser API-Server beim Lesen einen Fehler zurückgeben, und das gilt es zu vermeiden. Aus diesem Grund ist es auch nicht empfehlenswert, den Namen eines KMS Plugins in `/etc/kubernetes/encryptionconfig.yaml` zu verändern, solange Ressourcen mit diesem Präfix im etcd verschlüsselt sind, weil diese dann nicht mehr lesbar sein werden. Die Reihenfolge der Plugins ist auch relevant, dazu später mehr. Ebenso ist es eine schlechte Idee, zwei KMS-Plugins unter demselben Namen zu verwenden (wie soll der API-Server entscheiden, welches er verwenden soll?). 


Hier einmal ein Beispiel, wie diese Datei aussehen kann (siehe auch [die offizielle Dokumentation](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/)) 
```YAML
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
      - applications.argoproj.io
      - ingresses.networking.k8s.io
    providers:
      - kms:
          name: barbican_v1
          endpoint: unix:///var/lib/kms/kms_v1.sock
          cachesize: 65536
```
Wie  wir sehen, wird beschrieben, welche Ressourcen verschlüsselt abgelegt werden sollen, und welche KMS-Provider dafür genutzt werden sollen. Es folgt die Methode, die uns Scherereien mit den oben genannten Themen ersparen wird.

## Überblick
Folgende Schritte werden durchlaufen werden:
- KMS v1 und v2 werden parallel betrieben 
- Die Präferenz für Verschlüsselung wird auf v2 umgestellt
- Alle verschlüsselten Ressourcen werden neu verschlüsselt
- KMS v2 wird alleine betrieben

Der API-Server nutzt die KMS-Plugins in der Reihenfolge, wie sie in der `/etct/kubernetes/encryptionconfig.yaml` erscheinen, das gilt es zu nutzen und zu beachten, wenn man von einem KMS-Plugin auf das Andere wechseln will oder Daten neu verschlüsseln möchte. Sollte ein Plugin nicht erreichbar sein, oder einen Fehler liefern, wird das Nächste verwendet, und so weiter.


### KMS v1 und v2 Parallel
Das KMS-Plugin für beide Versionen muss für den API-Server erreichbar sein, beispielsweise über einen Socket. Anschliessend tragen wir das neue KMS-Plugin in unserer `/etc/kubernetes/encryptionconfig.yaml` ein.

```YAML
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
      - applications.argoproj.io
      - ingresses.networking.k8s.io
    providers:
      - kms:
          name: barbican_v1
          endpoint: unix:///var/lib/kms/kms_v1.sock
          cachesize: 65536
      - kms:
          name: barbican_v2
          apiVersion: v2
          endpoint: unix:///var/lib/kms/kms.sock
```
Wie oben bereits gesagt, befindet sich das neue Plugin unterhalb dem Alten, damit unser API-Server nicht anfängt Geheimnisse mit diesem zu verschlüsseln, was anderen API-Servern, die es noch nicht kennen, Probleme bereiten würde. Im Anschluss starten wir den API-Server neu, um die neue Konfiguration zu laden.

### Präferenz für Verschlüsselung umstellen
Sobald alle API-Server das neue KMS-Plugin kennen, können wir Die neue KMS-Plugin-Version wird jetzt oberhalb eingetragen


```YAML
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
      - applications.argoproj.io
      - ingresses.networking.k8s.io
    providers:
      - kms:
          name: barbican_v2
          apiVersion: v2
          endpoint: unix:///var/lib/kms/kms.sock
      - kms:
          name: barbican_v1
          endpoint: unix:///var/lib/kms/kms_v1.sock
          cachesize: 65536
```

Und abermals starten wir alle API-Server neu.

### Neuverschlüsselung aller verschlüsselten Ressourcen
Um das Verschlüsselungsschema auf die neue KMS-Version umzustellen, erstellen wir alle verschlüsselten Ressourcen neu. Die [Kubernetes-Doku](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/#ensuring-all-secrets-are-encrypted) empfiehlt folgendes, simples Kommando:


```BASH
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

Wer etwas mehr Kontrolle haben möchte, kann auch z.B. [folgendes Skript](https://gist.github.com/Atomsoldat/01fdd854b90e8cb7f0e7f4ee3e488a04) nutzen:

{{< details summary="Klicken zum Ausklappen..." >}}

```BASH
#!/bin/bash

# Copyright 2024 Leon Welchert
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


set -euo pipefail

INTERVAL=3
ALLNS='false'
DRYRUN='false'
unset -v NAMESPACE
unset -v KIND
unset -v CONTEXT
unset -v nsarray


Help()
{
   # Display Help
   echo "This script recreates all kubernetes resources of a given type in a given namespace or clusterwide"
   echo
   echo "Syntax Examples:"
   echo "         k8s-resource-recreate.sh [OPTIONS...] -n NAMESPACE -k KIND"
   echo "         k8s-resource-recreate.sh [OPTIONS...] -a -k KIND"
   echo "options:"
   echo "-h               Print this Help."
   echo "-a               Replace in all namespaces."
   echo "-d               Dry-run. Only show which replacements would be performed."
   echo "-k KIND          Kind of kubernetes resource to replace."
   echo "-c CONTEXT       Context from your ~/.kube/config to work in (defaults to currently active one)."
   echo "-n NAMESPACE     Namespace to replace resources in."
   echo "-i INTERVAL      Time to wait between namespaces (uses gnu sleep, defaults to 3s)."
   echo
}

HandleOptions()
{
  # only short options 
  # a colon in the first position of the opt string will suppress errors
  # upon invalid options, we don't want that
  while getopts 'hadk:c:n:i:' option; do
    case $option in
      h) # display help
        Help
      exit;;
      a) # run in all namespaces
        ALLNS='true'
        #echo "$option: All Namespaces is $ALLNS" 
      ;;
      d) # dry run
        DRYRUN='true'
        #echo "$option: Dryrun is $DRYRUN" 
      ;;
      k) # kind of resource to replace
        KIND=${OPTARG}
        #echo "$option: Kind is $KIND" 
      ;;
      c) # kubectl context to use
        CONTEXT=${OPTARG}
        #echo "$option: Context is $CONTEXT" 
      ;;
      n) # namespace to run in
        NAMESPACE=${OPTARG}
        #echo "$option: Namespace is $NAMESPACE" 
      ;;
      i) # time interval between namespaces
        INTERVAL=${OPTARG}
        #echo "$option: Interval is $INTERVAL" 
      ;;
      \?) # Invalid option recognised by getopts
        echo "Error: Invalid option"
        Help
      exit;;
    esac
  done
  # if the user passes no options, display help
  if [[ $OPTIND -eq 1 ]]; then
    Help
    exit
  fi
}

GetContext()
{
  # allow unset CONTEXT variable
  set +u
  if [[ -z "$CONTEXT" ]]; then
    set -u
    CONTEXT=$(kubectl config current-context)
    echo Context was not set, defaulting to $CONTEXT
  else
    set -u
    echo Context was set to $CONTEXT
  fi
}

GetNamespaces()
{
  if [[ "$ALLNS" == 'true' ]]; then
    echo "Working in all namespaces"
    nsarray=( $(kubectl --context $CONTEXT get namespaces -o jsonpath='{.items[*].metadata.name}') )
  else 
    echo "Working in a specified namespace"
    nsarray=($NAMESPACE)
  fi

  echo "The following namespaces will be worked on"
  for ns in ${nsarray[@]}; do
    echo -n "$ns "
  done
}

ReplaceResources()
{
  if [[ "$DRYRUN" == 'true' ]]; then
    for ns in ${nsarray[@]}; do
      echo "Working on namespace $ns"
      kubectl --context $CONTEXT -n $ns get $KIND -o json | kubectl --dry-run=server --context $CONTEXT replace -f -
    done
  else
    for ns in ${nsarray[@]}; do
      echo "Working on namespace $ns"
      kubectl --context $CONTEXT -n $ns get $KIND -o json | kubectl --context $CONTEXT replace -f -
    done
  fi
}


# main part of the script
HandleOptions $@
GetContext
GetNamespaces
echo "Waiting for 10 seconds before beginning replacement"
sleep 10
ReplaceResources
echo "Replacement Finished!"
```
{{< /details >}}
  

Um sicherzustellen, dass alle mit der alten KMS-Version verschlüsselten Ressourcen ersetzt wurden, können wir im etcd nachschauen, ob dem wirklich so ist:

```BASH
# Je nachdem, wie der etcd konfiguriert ist, kann sich der Authentifizierungsweg unterscheiden
# Um die neu verschlüsselten Geheimnisse zu sehen, suchen wir entsprechend nach kms:v2
etcdctl --cacert /etc/kubernetes/pki/etcd/ca.crt \
        --key /etc/kubernetes/pki/etcd/server.key \
        --cert /etc/kubernetes/pki/etcd/server.crt \
        --command-timeout=600s  \
        get --prefix /registry/secrets/ | grep --text kms:v1
```

### Alleiniger Betrieb von KMS v2
Nachdem alle verschlüsselten Ressourcen die neue KMS-Version nutzen, können wir die Alte aus der `/etc/kubernetes/encryptionconfig.yaml` entfernen. Danach werden die API-Server nacheinander neugestartet und wir sind fertig.

```YAML
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
      - applications.argoproj.io
      - ingresses.networking.k8s.io
    providers:
      - kms:
          name: barbican_v2
          apiVersion: v2
          endpoint: unix:///var/lib/kms/kms.sock
```

### Fehlerbehebung
Falls wir aus welchen Gründen auch immer doch in die Situation geraten, dass wir Einträge im etcd haben, die mit einem nicht (oder falsch) konfigurierten KMS-Provider verschlüsselt sind, haben wir im Grunde zwei Möglichkeiten, um die Situation zu beheben:
- Die Einträge löschen
- Den fehlenden/fehlerhaften KMS-Provider nachkonfigurieren und die Daten neu verschlüsseln
