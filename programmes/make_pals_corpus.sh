#!/bin/bash

# --- UTILISATION ---
# Ce script a besoin de deux arguments : un dossier de dumpe textuels (dumps-text) et un nom de langue (par exemple : kr)
# Exemple pour lancer la commande : cd programmes; bash make_pals_corpus.sh ../dumps-text kr > ../pals/dump-kr.txt

DOSSIER=$1
LANG=$2

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <dossier> <lang>"
    exit 1
fi

# Création automatique du dossier pals (au niveau racine)
mkdir -p ../pals

for file in $DOSSIER/$LANG-*.txt; do
    while read -r line; do
        if [ -z "$line" ]; then
            echo ""
        else
            echo "$line" | grep -oE "[가-힣]+|[A-Za-z]+|[0-9]+" | tr 'A-Z' 'a-z'
        fi
    done < "$file"
done
