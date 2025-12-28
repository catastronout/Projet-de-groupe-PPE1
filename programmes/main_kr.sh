#!/bin/bash

# --- UTILISATION ---
# 1. Se mettre dans le répertoire miniprojet/programmes
# 2. Lancer la commande suivante : bash main.sh nom_du_fichier_URLs nom_du_tableau fichier_liste_mots
# Exemple : bash main.sh kr tableau-kr1 data.txt

FICHIER_URLS=$1
FICHIER_SORTIE=$2
FICHIER_MOTS=$3

if (( $# != 3 )); 
then
	echo "Ce script a besoin de trois arguments pour fonctionner !"
	echo "Usage: $0 <fichier_URLs> <nom_tableau> <fichier_liste_mots>"
	exit 1
fi

if [[ ! -f "../URLs/$FICHIER_URLS.txt" ]]; then
	echo "Erreur : le fichier ../URLs/$FICHIER_URLS.txt n'existe pas !"
	exit 1
fi

if [[ ! -f "$FICHIER_MOTS" ]]; then
	echo "Erreur : le fichier $FICHIER_MOTS n'existe pas !"
	exit 1
fi

n=1
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Créer les répertoires pour les dumps
mkdir -p "../dumps-text/${FICHIER_URLS}"
mkdir -p "../aspirations/${FICHIER_URLS}"

# === Fonction pour générer le badge du code HTTP ===
generer_badge_code() {
	local code=$1
	if [[ "$code" == "200" ]]; then
		echo "<span class=\"tag is-success is-light\">${code}</span>"
	elif [[ "$code" =~ ^4 ]]; then
		echo "<span class=\"tag is-danger is-light\">${code}</span>"
	elif [[ "$code" == "000" ]]; then
		echo "<span class=\"tag is-dark is-light\">-</span>"
	fi
}

{
# === Génération du head et du début du tableau ===
cat << 'HEADER'
<!DOCTYPE html>
<html>
	<head>
		<meta charset="UTF-8"/>
		<meta name="viewport" content="width=device-width, initial-scale=1">
		<title>Tableau des résultats</title>
		<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css">
		<style>
			.hero {
				background: linear-gradient(135deg, #667eea 0%, #764ba2 100%)
			}
			.card {
				border-radius: 8px;
				box-shadow: 0 2px 15px rgba(0,0,0,0.1)
			}
			.table thead th {
				background-color: #f8f9fa;
				color: #4a5568;
				border-bottom: 2px solid #667eea;
			}
			.table tbody tr:hover {
				background-color: #f5f3ff
			}
			.url-cell {
				max-width: 350px;
				word-break: break-all;
				font-family: monospace;
				font-size: 0.85rem;
				color: #555
			}
			.back-link {
				color: #667eea
			}
			.back-link:hover {
				color: #764ba2
			}
			.count-cell {
				font-weight: bold;
				color: #667eea
			}
		</style>	
	</head>

	<body>
		<section class="hero is-small">
			<div class="hero-body">
				<div class="container has-text-centered">
					<h1 class="title has-text-white">Tableau des résultats</h1>
				</div>
			</div>
		</section>
		
		<section class="section">
			<div class="container">
				<p class="mb-4"><a href="../../../index.html" class="back-link">Retour</a></p>

				<div class="card">
					<div class="card-content">
						<div class="table-container">
							<table class="table is-fullwidth is-hoverable">				
								<thead>
									<tr>
										<th>N°</th>
										<th>URL</th>
										<th>Code HTTP</th>
										<th>Encodage</th>
										<th>Nb mots</th>
										<th>Occurrences</th>
										<th>Dump HTML</th>
										<th>Dump Text</th>
									</tr>
								</thead>
								<tbody>
HEADER

TOTAL=$(wc -l < "../URLs/$FICHIER_URLS.txt")

# === Génération des lignes du tableau ===
while read -r line;
do
	CODE=$(curl -sL -A "$UA" -o /dev/null -w "%{http_code}\n" "$line")
	[[ -z "$CODE" || "$CODE" == "000" ]] && CODE="-"

	ENCODAGE=$(curl -sIL -A "$UA" "$line" | tr -d '\r' | grep -i "charset" | head -n1 | cut -d= -f2)
	[[ -z "$ENCODAGE" ]] && ENCODAGE="-"

	NB_MOTS="-"
	OCCURRENCES="-"
	LIEN_HTML="-"
	LIEN_TEXT="-"
	
	# === SI LA PAGE EST EN UTF-8 ===
	if [[ "$ENCODAGE" =~ [Uu][Tt][Ff]-8 ]]; then
		# Sauvegarder le HTML brut
		FICHIER_HTML="../aspirations/${FICHIER_URLS}/${FICHIER_URLS}-${n}.html"
		curl -sL -A "$UA" "$line" > "$FICHIER_HTML"
		LIEN_HTML="<a href='../aspirations/${FICHIER_URLS}/${FICHIER_URLS}-${n}.html' style='color: #667eea;'>HTML</a>"
		
		# Extraire le texte avec lynx et sauvegarder
		FICHIER_TEXTE="../dumps-text/${FICHIER_URLS}/${FICHIER_URLS}-${n}.txt"
		lynx -dump -nolist -assume_charset=utf-8 -display_charset=utf-8 "$FICHIER_HTML" > "$FICHIER_TEXTE" 2>/dev/null
		LIEN_TEXT="<a href='../dumps-text/${FICHIER_URLS}/${FICHIER_URLS}-${n}.txt' style='color: #667eea;'>TXT</a>"
		
		# Compter les mots
		NB_MOTS=$(wc -w < "$FICHIER_TEXTE")
		
		# Compter les occurrences
		OCCURRENCES=0
		while IFS= read -r mot; do
			mot=$(echo "$mot" | tr -d '\r\n ')  # Nettoyer le mot
			[[ -z "$mot" ]] && continue
			count=$(grep -o "$mot" "$FICHIER_TEXTE" | wc -l)
			OCCURRENCES=$((OCCURRENCES + count))
		done < "$FICHIER_MOTS"
	
	# === SINON : essayer de convertir ===
	else
		# Sauvegarder le HTML brut
		FICHIER_HTML="../aspirations/${FICHIER_URLS}/${FICHIER_URLS}-${n}.html"
		curl -sL -A "$UA" "$line" > "$FICHIER_HTML"
		LIEN_HTML="<a href='../aspirations/${FICHIER_URLS}/${FICHIER_URLS}-${n}.html' style='color: #667eea;'>HTML</a>"
		
		# Détecter l'encodage avec file
		ENCODAGE_DETECTE=$(file -b --mime-encoding "$FICHIER_HTML")
		
		# Si l'encodage est reconnu
		if [[ -n "$ENCODAGE_DETECTE" && "$ENCODAGE_DETECTE" != "binary" && "$ENCODAGE_DETECTE" != "unknown-8bit" ]]; then
			# Convertir en UTF-8
			FICHIER_UTF8="../dumps-text/${FICHIER_URLS}/temp-utf8-${n}.html"
			iconv -f "$ENCODAGE_DETECTE" -t UTF-8 "$FICHIER_HTML" > "$FICHIER_UTF8" 2>/dev/null
			
			if [[ -s "$FICHIER_UTF8" ]]; then
				# Extraire le texte avec lynx et sauvegarder
				FICHIER_TEXTE="../dumps-text/${FICHIER_URLS}/${FICHIER_URLS}-${n}.txt"
				lynx -dump -nolist -assume_charset=utf-8 -display_charset=utf-8 "$FICHIER_UTF8" > "$FICHIER_TEXTE" 2>/dev/null
				LIEN_TEXT="<a href='../dumps-text/${FICHIER_URLS}/${FICHIER_URLS}-${n}.txt' style='color: #667eea;'>TXT</a>"
				
				# Compter les mots
				NB_MOTS=$(wc -w < "$FICHIER_TEXTE")
				
				# Compter les occurrences
				OCCURRENCES=0
				while IFS= read -r mot; do
					mot=$(echo "$mot" | tr -d '\r\n ')  # Nettoyer le mot
					[[ -z "$mot" ]] && continue
					count=$(grep -o "$mot" "$FICHIER_TEXTE" | wc -l)
					OCCURRENCES=$((OCCURRENCES + count))
				done < "$FICHIER_MOTS"
				
				rm -f "$FICHIER_UTF8"
			fi
		fi
	fi

	BADGE_CODE=$(generer_badge_code "$CODE")	
	echo "<tr>
			<td>${n}</td>
			<td class=\"url-cell\">${line}</td>
			<td>${BADGE_CODE}</td>
			<td>${ENCODAGE}</td>
			<td>${NB_MOTS}</td>
			<td class=\"count-cell\">${OCCURRENCES}</td>
			<td>${LIEN_HTML}</td>
			<td>${LIEN_TEXT}</td>
		</tr>"

    echo -ne "Progression : $n/$TOTAL\r" >&2

	n=$((n+1))

done < "../URLs/$FICHIER_URLS.txt"

echo -e "\n✓ Terminé ! $((n-1)) URLs traitées." >&2

# Génération du pied de page
cat << 'FOOTER'

</tbody>
							</table>
						</div>
					</div>				
				</div>
			</div>
		</section>

		<footer class="footer" style="padding: 1.5rem; background-color: #f9f9f9">
			<div class="content has-text-centered">
				<p class="is-size-7 has-text-grey">Miniprojet PPE1 - M1 TAL</p>
			</div>
		</footer>
	</body>
</html>

FOOTER

} > "../tableaux/$FICHIER_SORTIE.html"