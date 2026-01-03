#!/bin/bash

# --- UTILISATION ---
# Ce script a besoin de deux arguments : un dossier et un nom de langue
# Pour dumps-text :
#   bash make_pals_corpus.sh ../dumps-text/be be > ../pals/dump-be.txt
# Pour contextes (fichiers TSV) :
#   bash make_pals_corpus.sh ../contextes/be be > ../pals/contexte-be.txt

VERBOSE=0

# Gestion de l'option -v
if [[ "$1" == "-v" ]]; then
    VERBOSE=1
    shift
fi

INPUT=$1
LANG=$2

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 [-v] <dossier> <lang>" >&2
    echo "Exemple: $0 ../dumps-text/be be > ../pals/dump-be.txt" >&2
    exit 1
fi

# Fonction de log
log() {
    (( VERBOSE )) && echo "[INFO] $*" >&2
}

log "Dossier fourni : $DOSSIER"
log "Langue fournie : $LANG"

# Vérification du dossier
if [[ ! -d "$INPUT" && ! -f "$INPUT" ]]; then
    echo "Erreur : $INPUT n'est ni un fichier ni un dossier valide" >&2
    exit 1
fi

# Création automatique du dossier pals
mkdir -p ../pals
log "Dossier ../pals prêt"

FILES_FOUND=0

FILES=()

if [[ -f "$INPUT" ]]; then
    # Cas 1 : fichier unique
    FILES=("$INPUT")
    log "Entrée : fichier unique"

elif [[ -d "$INPUT" ]]; then
    # Cas 2 : dossier (comportement actuel)
    log "Entrée : dossier"

    if [[ "$INPUT" == *"contextes"* ]]; then
        FILES=("$INPUT/$LANG"-*-kwic.tsv)
    else
        FILES=("$INPUT/$LANG"-*.txt)
    fi
fi

FILES_FOUND=0

for file in "${FILES[@]}"; do
    [[ ! -f "$file" ]] && continue
    FILES_FOUND=1
    log "Traitement du fichier : $file"

    FILES_FOUND=1
    log "Traitement du fichier : $file"

    # Si c'est un fichier TSV (contextes), extraire les colonnes 2, 3, 4
    if [[ "$file" == *.tsv ]]; then
        # Extraire contexte gauche (col 2) + mot (col 3) + contexte droit (col 4)
        cut -f2,3,4 "$file" | tr '\t' ' ' | perl -CSD -Mutf8 -ne '
            use utf8;
            use open qw(:std :utf8);
            
            if (/^\s*$/) { print "\n"; next; }
            
            while (/([가-힣]+|[A-Za-zА-Яа-яЁёІіЎўЄєҐґ]+(?:[\x{0027}\x{2019}\-][A-Za-zА-Яа-яЁёІіЎўЄєҐґ]+)*|[0-9]+(?:-[A-Za-zА-Яа-яЁёІіЎўЄєҐґ]+)?)/g) {
                print lc($1) . "\n";
            }
            print "\n";
        '
        echo ""
        continue
    fi

    # Sinon, traitement normal pour les fichiers TXT
    # Utiliser perl pour une meilleure gestion de l'UTF-8 et du cyrillique
    perl -CSD -Mutf8 -ne '
        use utf8;
        use open qw(:std :utf8);
        
        # Ligne vide dans le fichier source = séparateur de phrase dans la sortie
        if (/^\s*$/) {
            print "\n";
            next;
        }
        
        # Insérer des marqueurs de fin de phrase AVANT la tokenisation
        # Détecte : point/!/? suivi d'\''un espace et d'\''une majuscule (cyrillique ou latine)
        s/([.!?])\s+([A-ZА-ЯЁІЎЄҐ])/$1\n\n$2/g;
        
        # Tokenisation adaptée aux différentes langues :
        # - Coréen (Hangul) : 가-힣
        # - Cyrillique (russe/biélorusse) : А-Яа-яЁёІіЎўЄєҐґ
        # - Latin : A-Za-z
        # - Chiffres : 0-9
        # Le motif garde les mots avec tirets/apostrophes internes (ex: quelqu'\''un, 1930-х)
        
        # Parcourir chaque "segment" (séparé par les marqueurs de fin de phrase)
        for my $segment (split /\n\n/) {
            while ($segment =~ /([가-힣]+|[A-Za-zА-Яа-яЁёІіЎўЄєҐґ]+(?:[\x{0027}\x{2019}\-][A-Za-zА-Яа-яЁёІіЎўЄєҐґ]+)*|[0-9]+(?:-[A-Za-zА-Яа-яЁёІіЎўЄєҐґ]+)?)/g) {
                my $word = $1;
                # Conversion en minuscules (fonctionne pour cyrillique ET latin grâce à Perl)
                $word = lc($word);
                print "$word\n";
            }
            # Ligne vide après chaque phrase
            print "\n";
        }
        
    ' "$file"

    # Ligne vide entre chaque fichier (séparateur de document)
    echo ""

done

if (( ! FILES_FOUND )); then
    echo "Aucun fichier correspondant à $PATTERN" >&2
    exit 1
fi

log "Terminé"