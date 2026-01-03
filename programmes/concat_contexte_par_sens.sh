#!/bin/bash

# --- UTILISATION ---
# Ce script concatène tous les fichiers TSV d'un sens en un seul fichier TXT
# Format de sortie : une ligne par contexte (contexte_gauche mot contexte_droit)
#
# Exemples :
#   bash concat_contextes.sh ../contextes/be be
#   → Crée ../pals/contexte-be-sens1.txt et ../pals/contexte-be-sens2.txt

DOSSIER=$1
LANG=$2

if [[ -z "$DOSSIER" || -z "$LANG" ]]; then
    echo "Usage: $0 <dossier_contextes> <lang>" >&2
    echo "Exemple: $0 ../contextes/be be" >&2
    exit 1
fi

if [[ ! -d "$DOSSIER" ]]; then
    echo "Erreur : le dossier $DOSSIER n'existe pas" >&2
    exit 1
fi

# Créer le dossier pals s'il n'existe pas
mkdir -p ../pals

# Fichiers de sortie
OUT_SENS1="../pals/contexte-${LANG}-sens1.txt"
OUT_SENS2="../pals/contexte-${LANG}-sens2.txt"

# Vider les fichiers de sortie
> "$OUT_SENS1"
> "$OUT_SENS2"

# Compteurs
COUNT1=0
COUNT2=0

# Parcourir les fichiers sens1
for file in "$DOSSIER/${LANG}"-*-sens1.tsv; do
    [[ ! -f "$file" ]] && continue
    # Extraire colonnes 2, 3, 4 et les joindre avec des espaces
    while IFS=$'\t' read -r label gauche mot droit; do
        echo "$gauche $mot $droit" \
            | sed 's/[!?.]//g; s/$/./' \
            >> "$OUT_SENS1"
        ((COUNT1++))
    done < "$file"
done

# Parcourir les fichiers sens2
for file in "$DOSSIER/${LANG}"-*-sens2.tsv; do
    [[ ! -f "$file" ]] && continue
    while IFS=$'\t' read -r label gauche mot droit; do
        echo "$gauche $mot $droit" \
            | sed 's/[!?.]//g; s/$/./' \
            >> "$OUT_SENS2"
        ((COUNT2++))
    done < "$file"
done

echo "✓ Fichiers créés :"
echo "  $OUT_SENS1 ($COUNT1 lignes)"
echo "  $OUT_SENS2 ($COUNT2 lignes)"