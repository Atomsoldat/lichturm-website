---
title: "Proxmox Kubernetes Cluster using Cluster API Part 0: Considerations"
date: 2025-04-23T18:32:34+02:00
tags: ['Kubernetes', 'Proxmox']
draft: true
---

Der Entwickler von Portfolio Perfomance hat die Arbeit and seinem freien Softwareprojekt einst als »Therapeutisches Programmieren« beschrieben. Die Idee dahinter ist, dass es bisweilen wohltuend ist, ein technisches Projekt zu bearbeiten, an dem man selbst alle gestalterischen Entscheidungen trifft, und einem keine Einschränkungen auferlegt werden. Man kann sich ganz auf das vorliegende Problem konzentrieren, ohne dass Zeitdruck oder Einflußnahme von Außen, die Freude und den Entdeckungsprozess schmälern. Ich habe viel über die Werkzeuge, welche ich in meiner Arbeit verwende, gelernt, indem ich einen Nutzen für sie in meiner Freizeit gefunden habe. Normalerweise stoße ich zwangsläufig auf die Notizen und Dokumentation anderer Leute, die genau das Selbe tun, was immer sehr hilfreich war. Also werde ich, um diese schöne Tradition zu pflegen dokumentieren, wie ich mein eigenes kleines Heimrechenzentrum einrichte.

Mir schwebte ein Aufbau vor, der gut von Automatisierung und deklarativer Infrastrukturbeschreibung profitieren kann, sodass ich ihn leicht wiederaufbauen kann, wenn Ueble Dinge geschehen. Was die Anwendungen  betraf, die auf der Infrastruktur laufen sollten, war mir schon klar, dass sie ein gewisses Mass an Instabilitaet verkraften koennen muessen, sowohl, weil ich zum Werkeln tendiere, als auch weil alte Hardware in meiner Umgebung staendig wiederverwendet wird, sodass der ein oder andere Ausfall frueher oder spaeter recht wahrscheinlich ist. Das macht Kubernetes sehr interessant fuer mich, weil es entworfen ist, um *etwas* Instabilitaet zu tolerieren. Ganz zu schweigen davon, dass es mir gestattet, die Arbeit, welche andere Leute auf das Schreiben von Kubernetesdeployments fuer all die grossartigen Anwendungen, die es in der weiten Welt gibt, zu nutzen.

Falls mein geneigter Leser wissen moechte, warum ich das eine oder andere Werkzeug verwende, folgt eine kurze Erklaerung im naechsten Absatz. Er moege aber bedenken, dass es sich hierbei um ein Freizeitprojekt handelt, welches vor allem dazu entworfen ist, mir zu gefallen.

# Proxmox

Ich wollte wegen der haeufigen neuen Versionen nicht fuer die Installation und Wartung von physichen Kubernetes Hosts zustaendig sein. VMs sind zunaechst leichter mit VM-Abbildern zu automatisieren, was aber nicht heissen soll, dass ich abgeneigt waere, in Zukunft einen Image-basierten Ansatz zu versuchen. Darueber hinaus wollte ich eine Virtualisierungsumgebung, die ihren Dienst tut, ohne dass sie regelmaessig gehegt und gepflegt werden will, da ich der einzige sein werde, der sie warten wird (dementsprechend war OpenStack keine Option). Irgendeine proprietaere Loesung war auch kein gangbarer Weg, da ich keine nebuloese Organisation mit am Tisch haben moechte, wenn es darum geht, wie ich meine Infrastruktur verwende.

# Kubernetes

# Further Tools

# More to come
