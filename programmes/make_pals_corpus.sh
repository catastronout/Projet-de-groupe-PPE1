#!/bin/bash

# --- UTILISATION ---
# Ce script a besoin de deux arguments : un dossier de dumpe textuels (dumps-text) et un nom de langue (par exemple : kr)
# Exemple pour lancer la commande : cd programmes; bash make_pals_corpus.sh ../dumps-text kr > ../pals/dump-kr.txt

VERBOSE=0

# Gestion de l'option -v
if [[ "$1" == "-v" ]]; then
    VERBOSE=1
    shift
fi

DOSSIER=$1
LANG=$2

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <dossier> <lang>"
    exit 1
fi

# Fonction de log
log() {
    (( VERBOSE )) && echo "[INFO] $*" >&2
}

log "Dossier fourni : $DOSSIER"
log "Langue fournie  : $LANG"

# Vérification du dossier
if [[ ! -d "$DOSSIER" ]]; then
    echo "Erreur : le dossier $DOSSIER n'existe pas" >&2
    exit 1
fi

# Création automatique du dossier pals (au niveau racine)
mkdir -p ../pals
log "Dossier ../pals prêt"

FILES_FOUND=0

for file in $DOSSIER/$LANG-*.txt; do
    if [[ ! -f "$file" ]]; then
        continue
    fi

    FILES_FOUND=1
    log "Traitement du fichier : $file"

    while read -r line; do
        if [ -z "$line" ]; then
            echo ""
        else
            echo "$line" | grep -oE "[가-힣]+|[A-Za-z]+|[А-Яа-яЁёІіЎў]+|[0-9]+" | tr 'A-Z' 'a-z'
        fi
    done < "$file"
done

if (( ! FILES_FOUND )); then
    log "Aucun fichier correspondant à $DOSSIER/$LANG-*.txt"
fi

log "Terminé"