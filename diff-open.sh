#!/bin/bash

FILENAME=$1

grep 'de.md' <(printf ${FILENAME})

if [[ $? == 0 ]]; then
	TRANSLATION=$( printf ${FILENAME} | sed 's/de.md/en.md/')
else
	TRANSLATION=$( printf ${FILENAME} | sed 's/en.md/de.md/')
fi


vim -d ${FILENAME} ${TRANSLATION}
