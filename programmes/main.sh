#!/bin/bash


# =====================
#      UTILISATION     
# =====================
# 1. Se déplacer dans le répertoire miniprojet/programmes
# 2. Lancer le script `main.sh` comme suit : bash main.sh <urls> <tableau> [fichier_sens1 fichier_sens2 = facultatifs]
#   Exemples :
#     `bash main.sh be tableau-be1 data_sens1.txt data_sens2.txt`
#     `bash main.sh kr tableau-kr1`


# ============================== 
#      MODE VERBOSE / DEBUG     
# ==============================
# Utilisation :
#    `-v`  : VERBOSE (affiche des messages lisibles, commençant par [INFO])
#    `-d`  : DEBUG (affiche la trace complète d'exécution bash)
#    `-vd` : possibilité de combiner les modes VERBOSE et DEBUG

# Par défaut, les variables VERBOSE et DEBUG n'affiche rien (0)
VERBOSE=0
DEBUG=0

# Fonction de log
# Affiche un message seulement si VERBOSE = 1
# Les messages sont envoyés sur stderr
log() { (( VERBOSE )) && echo "[INFO] $*" >&2; }
# Affichage pour les encodages
log_step() { (( VERBOSE )) && echo "       ↳ $*" >&2; }

# Fonction d'affichage de l'aide
# Appelée en cas d'erreur ou d'option invalide
usage() {
	echo "Utilisation :"
	echo "  $0 [-v] [-d] <urls> <tableau> [fichier_sens1 fichier_sens2]"
	echo "  -v : verbose (messages lisibles)"
	echo "  -d : debug (trace bash)"
	exit 1
}

# Permet l'implémentation des options `-v` et `-d`, + de l'aide
while getopts ":vd" opt; do
	case "$opt" in
		v) VERBOSE=1 ;;
		d) DEBUG=1 ;;
    	*) usage ;;
	esac
done

# Supprimer les options déjà traitées
shift $((OPTIND-1))

# Active le mode DEBUG : affiche chaque commande exécutée, avec le nom du fichier, le n° de la ligne et la fonction
if (( DEBUG )); then
	export PS4='+ ${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]:-main}: '
	set -x
fi


# ====================================
#      RÉCUPERATION DES ARGUMENTS     
# ====================================
# S1 : nom du fichier contenant les URLs (sans l'extention .txt)
# S2 : nom du fichier HTML de sortie (sans l'extension .html)
# S3 : fichier listants les formes du lemme 1 (facultatif -- avec son extention)
# S4 : fichier listant les formes du lemme 2 (facultatif -- avec son extention)
FICHIER_URLS=$1
FICHIER_SORTIE=$2
FICHIER_MOTS_SENS1=$3
FICHIER_MOTS_SENS2=$4


# ====================================
#      VÉRIFICATION DES ARGUMENTS     
# ====================================
# Vérification du nombre d'arguments (minimum 2)
if (( $# < 2 )); then
	echo "Ce script a besoin d'au moins deux arguments !"
	echo "Utilisation :"
	echo "  $0 <ENTRÉE_fichier_URLs> <SORTIE_fichier_tableau> <fichier_sens1> <fichier_sens2>"
	echo "ou"
	echo "  $0 <ENTRÉE_fichier_URLs> <SORTIE_fichier_tableau>"
	exit 1
fi
  
# Vérification de l'existence du fichier d'URLs
if [[ ! -f "../URLs/$FICHIER_URLS.txt" ]]; then
	echo "Erreur : le fichier ../URLs/$FICHIER_URLS.txt n'existe pas !"
	exit 1
fi

# --- Messages d'information (VERBOSE) ----
log "URLs: ../URLs/$FICHIER_URLS.txt"
log "Sortie: ../tableaux/$FICHIER_SORTIE.html"
log "Sens1 fichier: $FICHIER_MOTS_SENS1 | Sens2 fichier: $FICHIER_MOTS_SENS2"

# Vérifications des fichiers de motifs
if [[ -n "$FICHIER_MOTS_SENS1" && -z "$FICHIER_MOTS_SENS2" ]] || \
   [[ -z "$FICHIER_MOTS_SENS1" && -n "$FICHIER_MOTS_SENS2" ]]; then
  echo "Erreur : il faut fournir soit 0 fichier de motifs, soit 2 fichiers (sens 1 et sens 2)." >&2
  echo "Exemples valides :" >&2
  echo "  $0 urls tableau" >&2
  echo "  $0 urls tableau motifs_sens1.txt motifs_sens2.txt" >&2
  exit 1
fi

if (( $# > 4 )); then
  echo "Erreur : trop d'arguments." >&2
  echo "Utilisation : $0 <urls> <tableau> [motifs_sens1 motifs_sens2]" >&2
  exit 1
fi


# ===============================================
#      DÉTERMINATION DE LA SOURCE DES MOTIFS     
# ===============================================
# Motifs = mots cherchés dans les textes
# Tableaux contenant les formes pour chaque lemme
MOTIFS_SENS1=()
MOTIFS_SENS2=()
# Libellés des colonnes dans le tableau HTML
LABEL_SENS1=""
LABEL_SENS2=""

# ----- Cas 1 : deux fichiers de motifs sont fournis en arguments -----
# On vérifie que ces fichiers existent 
if [[ -n "$FICHIER_MOTS_SENS1" && -n "$FICHIER_MOTS_SENS2" && -f "$FICHIER_MOTS_SENS1" && -f "$FICHIER_MOTS_SENS2" ]]; then
    # Lecture du fichier des motifs du lemme 1
	while IFS= read -r m; do
		# Nettoyage : suppression des retours chariot, sauts de ligne et espaces
    	m=$(echo "$m" | tr -d '\r\n ')
		# Ajout du mot au tableau seulement s'il n'est pas vide
    	[[ -n "$m" ]] && MOTIFS_SENS1+=("$m")
  	done < "$FICHIER_MOTS_SENS1"

	# Même chose pour le lemme 2
	while IFS= read -r m; do
    	m=$(echo "$m" | tr -d '\r\n ')
    	[[ -n "$m" ]] && MOTIFS_SENS2+=("$m")
  	done < "$FICHIER_MOTS_SENS2"

	# Input user : choisir le nom des colonnes pour le tableau HTML
	read -rp "Nom de colonne / lemme pour le sens 1 : " LABEL_SENS1
	read -rp "Nom de colonne / lemme pour le sens 2 : " LABEL_SENS2
	# Valeurs par défaut si l'utilisateur ne saisit rien
	[[ -z "$LABEL_SENS1" ]] && LABEL_SENS1="sens 1"
	[[ -z "$LABEL_SENS2" ]] && LABEL_SENS2="sens 2"
# ----- Cas 2 : aucun fichier de motifs fournis -----
else
	# Input user : motif à chercher (pour le coréen)
	read -rp "Écris le mot 1 (sens 1) : " m1
	read -rp "Écris le mot 2 (sens 2) : " m2
	# Ajout des mots aux tableaux correspondants
	[[ -n "$m1" ]] && MOTIFS_SENS1+=("$m1")
	[[ -n "$m2" ]] && MOTIFS_SENS2+=("$m2")
	# Ces mots servent aussi de libellés pour les colonnes dans le tableau HTML
	LABEL_SENS1="$m1"
	LABEL_SENS2="$m2"
fi


# Initialisation du compteur d'URLs, pour numéroter les lignes du tableau et des fichiers générés
n=1

# User Agent utilisé par curl pour simuler un navigateur réel
# (évite certains refus côté serveur)
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Taille du contexte KWIC (Key Word in Context) : nombre de mots à gauche et à droite
CONTEXT_WORDS=20

# Création des répertoires nécessaires au bon fonctionnement du script :
# - aspirations  : pages HTML aspirées
# - concordances : fichiers HTML de concordanciers (KWIC)
# - contextes    : fichiers de contextes textuels
# - dumps-text   : texte brut extrait des pages HTML
# - tableaux     : tableaux HTML 
mkdir -p "../aspirations/${FICHIER_URLS}"
mkdir -p "../concordances/${FICHIER_URLS}"
mkdir -p "../contextes/${FICHIER_URLS}"
mkdir -p "../dumps-text/${FICHIER_URLS}"
mkdir -p "../tableaux"


# --- Messages d'information (VERBOSE) ----
log "Création dossiers dumps/aspirations/contextes/tableaux/concordances pour $FICHIER_URLS"


# =========================================
#      AFFICHAGE BADGES ENCODAGES HTML     
# =========================================
# Fonction pour afficher les badges pour les encodages dans le tableau HTML
generer_badge_code() {
	# Variable locale qui prend le code HTTP en argument
	local code="$1"
	# Si aucun code n'est fourni, affiche `000` par défaut
	[[ -z "$code" ]] && code="000"

	# Mise en page des badges en fonction des codes HTML récupérés
	if [[ "$code" =~ ^2 ]]; then        # le code HTML commence par 2
    	echo "<span class=\"tag is-success is-light\">${code}</span>"
	elif [[ "$code" =~ ^3 ]]; then      # le code HTML commence par 3
    	echo "<span class=\"tag is-info is-light\">${code}</span>"
	elif [[ "$code" =~ ^4 ]]; then      # le code HTML commence par 4
    	echo "<span class=\"tag is-danger is-light\">${code}</span>"
	elif [[ "$code" =~ ^5 ]]; then      # le code HTML commence par 5
    	echo "<span class=\"tag is-warning is-light\">${code}</span>"
	elif [[ "$code" == "000" ]]; then   # le code HTML est `000`
    	echo "<span class=\"tag is-light has-text-grey-light\">000</span>"
	else
    	echo "<span class=\"tag is-light\">${code}</span>"
  	fi
}


# ==============================================
#      NORMALISATION ENCODAGE HTML EN UTF-8     
# ==============================================
# Fonction qui force un encodage UTF-8 dans un fichier HTML
# Permet d'éviter les problèmes d'affichage (mojibake) (lors de l'extraction)
forcer_charset_utf8_html() {
	local f="$1"
	# Remplace toutes les déclarations de charset existantes par "utf-8"
	perl -i -pe 's/(charset\s*=\s*)["'\'']?[^"'\'' >;]+/${1}utf-8/ig' "$f"
	# Si aucune déclaration de chatset existe dans le fichier
	if ! grep -qi "charset" "$f"; then
		# On injecte explicitement la balise `<meta charset="utf-8">`
    	perl -0777 -i -pe 's/<head([^>]*)>/<head$1>\n<meta charset="utf-8">/i' "$f"
  	fi
}


# =======================================
#      MANIPULATION DE TABLEAUX BASH     
# =======================================
# Join le contenu d'un tableau Bash en une seule chaîne avec un délimiteur donné
# Compatible avec les anciennnes versions de Bash
# Utilisation : 
#   join_array "|" MOTIFS_SENS1
#     renvoie par exemple : mot1|mot2|mot3
join_array() {
	local delim="$1"
	local array_name="$2"
	local out=""
	local x

	# Récupère le contenu du tableau dont le nom est dans $array_name et le place dans les paramètres positionnels ($1, $2, ...)
	eval "set -- \"\${${array_name}[@]}\""
	# Parcourt chaque élément du tableau
  	for x in "$@"; do
		# Nettoyage : supprime les retours charriot, les sauts de ligne et les espaces
    	x=$(echo "$x" | tr -d '\r\n ')
		# Ignore les éléments vides
    	[[ -z "$x" ]] && continue
		# Si c'est le 1e élément : pas de délimiteur
		# Sinon, on ajoute le délimiteur avant
    	if [[ -z "$out" ]]; then out="$x"; else out="${out}${delim}${x}"; fi
  	done
	# Affiche la chaîne finale, sans retour à la ligne
  	printf "%s" "$out"
}

# ============================
#      KWIC TSV generator     
# ============================
# Produit un TSV : LABEL \t LEFT \t KW \t RIGHT
# Chaque ligne aura 4 colonnes séparées par des tab : 1) label, 2) contexte gauche, 3) mot trouvé, 4) contexte droit
generer_kwic_tsv() {
	# Variables locales :
	# $1 : fichier texte source
	# $2 : chemin du TSV à écrire
	# S3 : label
	# $4 : motifs concaténés dans une seule chaîne, séparés par \x1F
	# $5 : taille de fenêtre (nb de mots à gauche et à droite)
  	local txt="$1"
  	local out_tsv="$2"
	local label="$3"
  	local motifs_joined="$4"
  	local w="$5"

	# Tokenisation + KWIC
	# Pour chaque motif :
	# - découper le texte en tokens
	# - repérer les occurrences exactes des motifs
	# - extraire une fenêtre de contexte de N mots à gauche et à droite
	# - écrire le résultat dans un fichier TSV : LABEL \t GAUCHE \t MOT \t DROITE
 	perl -Mutf8 -CS -e '
 		use strict; use warnings;
    	use Encode qw(decode FB_DEFAULT);

    	my ($txt, $out, $label, $joined, $w) = @ARGV;

		$label  = decode("UTF-8", $label,  FB_DEFAULT);
		$joined = decode("UTF-8", $joined, FB_DEFAULT);

		my @motifs = grep { length($_) } split(/\x1F/, $joined);
		my %want;
		for my $m (@motifs) {
		my $k = lc($m);
		$want{$k} = 1;
		}

		open my $IN, "<:raw", $txt or die "Cannot open $txt\n";
		local $/;
		my $bytes = <$IN>;
		close $IN;

		my $data = decode("UTF-8", $bytes, FB_DEFAULT);

		my @tok = ($data =~ /[\p{L}\p{N}][\p{L}\p{N}\x{2019}\x{0027}\-]*/gu);

		open my $OUT, ">:encoding(UTF-8)", $out or die "Cannot write $out\n";

		for (my $i=0; $i<@tok; $i++) {
		my $t = $tok[$i];
		next unless $want{ lc($t) };

		my $L = $i - $w; $L = 0 if $L < 0;
		my $R = $i + $w; $R = $#tok if $R > $#tok;

		my $left  = ($i > $L) ? join(" ", @tok[$L .. $i-1]) : "";
		my $kw    = $tok[$i];
		my $right = ($i < $R) ? join(" ", @tok[$i+1 .. $R]) : "";

		$left  =~ s/\t/ /g;
		$kw    =~ s/\t/ /g;
		$right =~ s/\t/ /g;

		print $OUT $label, "\t", $left, "\t", $kw, "\t", $right, "\n";
		}

		close $OUT;
	' "$txt" "$out_tsv" "$label" "$motifs_joined" "$w"
}

# =================================
#      Génération des contextes    
# =================================
# Crée les fichiers de contexte KWIC au format TSV
# - génère un fichier TSV pour chaque sens
# - concatène les deux dans un TSV global
# - calcule le nb d'occurrences par sens
generer_contextes_kwic() {
	local idx="$1"              # idx : numéro de l'URL
	local fichier_texte="$2"    # fichier_texte : texte brut extrait depuis le HTML

	# \x1F est une délimitation rare pour concaténer les motifs
	# Permet d'éviter les collisions
	local DELIM=$'\x1F'
	local motifs1 motifs2
	# Concatène les tableaux de motifs en une seule chaîne
	motifs1=$(join_array "$DELIM" "MOTIFS_SENS1")
	motifs2=$(join_array "$DELIM" "MOTIFS_SENS2")

	# Fichiers TSV de sortie
	local TSV1="../contextes/${FICHIER_URLS}/${FICHIER_URLS}-${idx}-sens1.tsv"
	local TSV2="../contextes/${FICHIER_URLS}/${FICHIER_URLS}-${idx}-sens2.tsv"
	local TSV_ALL="../contextes/${FICHIER_URLS}/${FICHIER_URLS}-${idx}-kwic.tsv"

	# Initiatlisation des fichiers TSV (vides)
	: > "$TSV1"
	: > "$TSV2"
	: > "$TSV_ALL"

	# Génère les contextes KWIC uniquement si les motifs sont définis
	[[ -n "$motifs1" ]] && generer_kwic_tsv "$fichier_texte" "$TSV1" "$LABEL_SENS1" "$motifs1" "$CONTEXT_WORDS"
	[[ -n "$motifs2" ]] && generer_kwic_tsv "$fichier_texte" "$TSV2" "$LABEL_SENS2" "$motifs2" "$CONTEXT_WORDS"

	# Fudionne les contextes des deux sens dans un seul fichier TSV
	cat "$TSV1" "$TSV2" > "$TSV_ALL" 2>/dev/null

	# Comptage des occurrences = nb de lignes par label dans le TSV final
	OCC_SENS1=$(awk -F'\t' -v lab="$LABEL_SENS1" '$1==lab {c++} END{print c+0}' "$TSV_ALL")
	OCC_SENS2=$(awk -F'\t' -v lab="$LABEL_SENS2" '$1==lab {c++} END{print c+0}' "$TSV_ALL")

	# Renvoie le TSV global
 	echo "$TSV_ALL"
}

# ======================================
#     CONCORDANCIER HTML DEPUIS TSV     
# ======================================
# Fonction qui lit un fichier TSV de contextes KWIC et génère un fichier HTML "concornancier"
generer_concordancier_html_depuis_tsv() {
	local idx="$1"     # numéro de l'URL
	local url="$2"     # URL d'origine
	local tsv="$3"     # chemin du fichier TSV
	# chemin vers le fichier sortie
	local out="../concordances/${FICHIER_URLS}/${FICHIER_URLS}-${idx}.html"

	# Lit le TSV ligne par ligne
	# Échappe les caractère HTML 'dangereux'
	# Met chaque occurrence dans un tableau HTML
	# Met en évidence le mot-clé (KWIC)
	# Génère un gichier HTML autonome
	perl -Mutf8 -CS -e '
		use strict; use warnings;
		use Encode qw(decode FB_DEFAULT);

		my ($tsv, $out, $url, $w, $urls_name, $idx) = @ARGV;
		$url       = decode("UTF-8", $url, FB_DEFAULT);
		$urls_name = decode("UTF-8", $urls_name, FB_DEFAULT);

		open my $IN, "<:encoding(UTF-8)", $tsv or die "Cannot open $tsv\n";
		my @rows;
		while (my $line = <$IN>) {
			chomp $line;
			my ($cat, $left, $kw, $right) = split(/\t/, $line, 4);
			$cat   //= ""; $left //= ""; $kw //= ""; $right //= "";

			for ($cat,$left,$kw,$right) { s/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g; }

			push @rows, qq{
				<tr>
					<td class="has-text-grey cat-col">$cat</td>
					<td class="kwic-left">$left</td>
					<td class="kwic-kw"><mark>$kw</mark></td>
					<td class="kwic-right">$right</td>
				</tr>
			};
    	}
    	close $IN;

		my $n = scalar(@rows);

		open my $OUT, ">:encoding(UTF-8)", $out or die "Cannot write $out\n";

		print $OUT qq{<!DOCTYPE html>
	<html>
		<head>
			<meta charset="UTF-8"/>
			<meta name="viewport" content="width=device-width, initial-scale=1">
			<title>Concordancier - $urls_name-$idx</title>
			<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css">
			<style>
				.hero { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) }
				.card { border-radius: 8px; box-shadow: 0 2px 15px rgba(0,0,0,0.1) }

				.back-link { color: #667eea }
				.back-link:hover { color: #764ba2 }

				.table thead th { background-color: #f8f9fa; color: #4a5568; border-bottom: 2px solid #667eea; }
				.table tbody tr:hover td { background-color: #f5f3ff; }

			.kwic-left, .kwic-kw, .kwic-right { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace; font-size: 0.9rem; }
			.kwic-left  { text-align: right;  width: 44%; }
			.kwic-kw    { text-align: center; width: 12%; font-weight: 700; }
			.kwic-right { text-align: left;   width: 44%; }
			mark { padding: 0.12rem 0.25rem; border-radius: 4px; }

			.cat-col { white-space: nowrap; }

			body.dark { background: #0f172a; color: #e2e8f0; }
			body.dark .card { background: #111827; color: #e2e8f0; }
			body.dark .table { background: #111827; color: #e2e8f0; }
			body.dark .table thead th { background: #0b1220; color: #e2e8f0; border-color: #334155; }
			body.dark .table td, body.dark .table th { background: #111827; color: #e2e8f0; border-color: #334155; }
			body.dark .table tbody tr:hover td { background: #1f2937; }
			body.dark .back-link { color: #93c5fd; }
			body.dark .back-link:hover { color: #c4b5fd; }
			body.dark .footer { background: #0b1220 !important; color: #e2e8f0; }
			body.dark .footer .has-text-grey { color: #94a3b8 !important; }

			body.dark mark { background: rgba(147,197,253,0.25); color: #e2e8f0; }
		</style>
	</head>

	<body>
		<section class="hero is-small">
			<div class="hero-body">
				<div class="container has-text-centered">
    				<h1 class="title has-text-white">Concordancier (KWIC)</h1>
					<p class="subtitle has-text-white is-6">Fenêtre : ±$w mots</p>
					<button id="themeToggle" class="button is-light is-small mt-2">🌙 Mode sombre</button>
				</div>
			/div>
		</section>

		<section class="section">
			<div class="container">
				<p class="mb-4">
					<a href="../../../index.html" class="back-link">Retour</a>
					<span class="has-text-grey"> / </span>
					<a href="../tableaux/} . $urls_name . qq{.html" class="back-link">Tableau</a>
				</p>

				<div class="card">
					<div class="card-content">
						<div class="content">
							<p class="mb-2"><strong>URL :</strong> <a href="$url" target="_blank" rel="noopener noreferrer" class="back-link">$url</a></p>
							<p class="mb-4"><strong>Occurrences :</strong> $n</p>
						</div>

						<div class="table-container">
							<table class="table is-fullwidth is-hoverable is-striped">
								<thead>
									<tr>
										<th>Catégorie</th>
										<th>Gauche</th>
										<th>Mot</th>
										<th>Droite</th>
									</tr>
								</thead>
								<tbody>
};

		if (@rows) {
			print $OUT join("\n", @rows), "\n";
		} else {
			print $OUT qq{<tr><td colspan="4">Aucune occurrence trouvée.</td></tr>\n};
		}

		print $OUT qq{
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
			/div>
		</footer>

		<script>
			const btn = document.getElementById("themeToggle");
			const saved = localStorage.getItem("theme");
			if (saved === "dark") document.body.classList.add("dark");

			function refreshLabel() {
				const isDark = document.body.classList.contains("dark");
				btn.textContent = isDark ? "☀️ Mode clair" : "🌙 Mode sombre";
			}
			refreshLabel();

			btn.addEventListener("click", () => {
				document.body.classList.toggle("dark");
				localStorage.setItem("theme", document.body.classList.contains("dark") ? "dark" : "light");
				refreshLabel();
			});
		</script>
	</body>
</html>
};

	close $OUT;
	' "$tsv" "$out" "$url" "$CONTEXT_WORDS" "$FICHIER_URLS" "$idx"

	echo "$out"
}


# ==========================================================
#      EXTRACTION TEXTE + KWIC TSV + CONCORDANCIER HTML     
# ==========================================================
extraire_et_compter() {
	local html_src="$1"   # chemin du HTML
	local idx="$2"        # numéro de l'URL
	local url="$3"        # URL d'origine 

	# Chemin du dump texte final
	local FICHIER_TEXTE="../dumps-text/${FICHIER_URLS}/${FICHIER_URLS}-${idx}.txt"

	# Locale : évite des bugs sur certains caractères (UTF-8)
	export LC_ALL=en_US.UTF-8

	# Extraction du texte brut depuis le HTML
	lynx -force_html -dump -nolist \
       -assume_charset=utf-8 -display_charset=utf-8 \
       "$html_src" > "$FICHIER_TEXTE" 2>/dev/null

	# Si le fichier texte existe ET n’est pas vide, on calcule tout
	if [[ -s "$FICHIER_TEXTE" ]]; then
		# Lien vers le dump TXT
		LIEN_TEXT="<a href='../dumps-text/${FICHIER_URLS}/${FICHIER_URLS}-${idx}.txt' style='color: #667eea;'>TXT</a>"

		# Nombre de mots dans le dump
		NB_MOTS=$(wc -w < "$FICHIER_TEXTE")

		# Chemins des TSV (1 par sens + un TSV global fusionné)
		local TSV1="../contextes/${FICHIER_URLS}/${FICHIER_URLS}-${idx}-sens1.tsv"
		local TSV2="../contextes/${FICHIER_URLS}/${FICHIER_URLS}-${idx}-sens2.tsv"
		local TSV_ALL="../contextes/${FICHIER_URLS}/${FICHIER_URLS}-${idx}-kwic.tsv"

		# On appelle la fonction SANS $(...) pour que OCC_SENS1 et OCC_SENS2 soient bien mises à jour dans ce shell
		generer_contextes_kwic "$idx" "$FICHIER_TEXTE" >/dev/null

		# Génération du concordancier HTML à partir du TSV global
		generer_concordancier_html_depuis_tsv "$idx" "$url" "$TSV_ALL" >/dev/null

		# Lien vers le concordancier
		LIEN_CONC="<a href='../concordances/${FICHIER_URLS}/${FICHIER_URLS}-${idx}.html' style='color: #667eea;'>KWIC</a>"

	else
		# Si lynx a échoué ou a produit un fichier vide : on met des tirets
		# --- Messages d'information (VERBOSE) ----
		log_step "Extraction texte : KO (fichier vide ou lynx a échoué)"
		NB_MOTS="-"
		OCC_SENS1="-"
		OCC_SENS2="-"
		LIEN_TEXT="-"
		LIEN_CONC="-"
	fi
}


# ====================================
#      Génération du tableau HTML     
# ==================================== 

{
cat << HEADER
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Tableau des résultats</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css">
    <style>
      .hero { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) }
      .card { border-radius: 8px; box-shadow: 0 2px 15px rgba(0,0,0,0.1) }
      .table thead th { background-color: #f8f9fa; color: #4a5568; border-bottom: 2px solid #667eea; }
      .table tbody tr:hover { background-color: #f5f3ff }
      .url-cell { max-width: 350px; word-break: break-all; font-family: monospace; font-size: 0.85rem; color: #555 }
      .back-link { color: #667eea }
      .back-link:hover { color: #764ba2 }
      .count-cell { font-weight: bold; color: #667eea }
      .url-cell a { color: #667eea; }
      .url-cell a:hover { color: #764ba2; }

      body.dark { background: #0f172a; color: #e2e8f0; }
      body.dark .card { background: #111827; color: #e2e8f0; }
      body.dark .table { background: #111827; color: #e2e8f0; }
      body.dark .table thead th { background: #0b1220; color: #e2e8f0; }
      body.dark .table td, body.dark .table th { background: #111827; color: #e2e8f0; border-color: #334155; }
      body.dark .table tbody tr:hover td { background: #1f2937; }
      body.dark .url-cell { color: #cbd5e1; }
      body.dark .back-link, body.dark .url-cell a { color: #93c5fd; }
      body.dark .back-link:hover, body.dark .url-cell a:hover { color: #c4b5fd; }
      body.dark .footer { background: #0b1220 !important; color: #e2e8f0; }
      body.dark .footer .has-text-grey { color: #94a3b8 !important; }
    </style>
  </head>

  <body>
    <section class="hero is-small">
      <div class="hero-body">
        <div class="container has-text-centered">
          <h1 class="title has-text-white">Tableau des résultats</h1>
          <button id="themeToggle" class="button is-light is-small mt-2">🌙 Mode sombre</button>
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
                    <th>Occ : ${LABEL_SENS1}</th>
                    <th>Occ : ${LABEL_SENS2}</th>
                    <th>Dump HTML</th>
                    <th>Dump Text</th>
                    <th>Concord.</th>
                  </tr>
                </thead>
                <tbody>
HEADER


# Permet d'afficher la progression de traitement des URLs
TOTAL=$(wc -l < "../URLs/$FICHIER_URLS.txt")


# ==============================================
#      BOUCLE POUR LA GÉNÉRATION DU TABLEAU    
# ==============================================
# Boucle qui lit le fichier ligne pas ligne
while read -r line; do
	line=$(echo "$line" | tr -d '\r')
	# --- Messages d'information (VERBOSE) ----
	log "[$n/$TOTAL] Traitement URL: $line"

	# Récupération du code HTML de l'URL
	CODE=$(curl -sL --max-time 20 -A "$UA" -o /dev/null -w "%{http_code}" "$line")
	# Si curl ne renvoie rien, on affiche "000"
	[[ -z "$CODE" ]] && CODE="000"

	# Si curl n'a pas réussi (000), remplir la ligne du tableau avec des "-", et passer à l'URL suivante
	if [[ "$CODE" == "000" ]]; then
		# Badge coloré selon le code HTML
		BADGE_CODE=$(generer_badge_code "$CODE")
		# Écrire la ligne HTML
		echo "<tr>
			<td>${n}</td>
			<td class=\"url-cell\"><a href=\"${line}\" target=\"_blank\" rel=\"noopener noreferrer\">${line}</a></td>
			<td>${BADGE_CODE}</td>
			<td>-</td>
			<td>-</td>
			<td class=\"count-cell\">-</td>
			<td class=\"count-cell\">-</td>
			<td>-</td>
			<td>-</td>
			<td>-</td>
		</tr>"
		# Affiche la progression
		echo -ne "Progression : $n/$TOTAL\r" >&2
		# Incrémente le compteur d'URLs
		n=$((n+1))
		continue
	fi

	# Récupérer l'encodage déclaré dans les headers
	ENCODAGE=$(curl -sIL -L -A "$UA" "$line" | tr -d '\r' | grep -i -o 'charset=[^;[:space:]]*' | head -n1 | cut -d= -f2)
	# Si pas trouvé : "-"
	[[ -z "$ENCODAGE" ]] && ENCODAGE="-"
	# Variable "affichée" 
	ENCODAGE_AFFICHE="$ENCODAGE"

	# --- Messages d'information (VERBOSE) ----
	log_step "Encodage (header) : $ENCODAGE"

	# Valeurs par défaut si extraction/compteurs échoue
	NB_MOTS="-"
	OCC_SENS1="-"
	OCC_SENS2="-"
	LIEN_HTML="-"
	LIEN_TEXT="-"
	LIEN_CONC="-"

	# Chemin pour la sauvegarde de la page HTML aspirée
	FICHIER_HTML="../aspirations/${FICHIER_URLS}/${FICHIER_URLS}-${n}.html"
	# Aspiration du HTML complet
	curl -sL --compressed -A "$UA" "$line" > "$FICHIER_HTML"
	# Lien HTML cliquable dans le tableau
	LIEN_HTML="<a href='../aspirations/${FICHIER_URLS}/${FICHIER_URLS}-${n}.html' style='color: #667eea;'>HTML</a>"

	# Si le fichier HTML n'est pas vide, on continue vers l'extration du texte + KWIC
	if [[ -s "$FICHIER_HTML" ]]; then
		# Détecte l'encodage "réel" via file
		ENCODAGE_DETECTE=$(file -b --mime-encoding "$FICHIER_HTML")

		# --- Messages d'information (VERBOSE) ----
		log_step "Encodage (file)   : $ENCODAGE_DETECTE"

		# Par défaut, lynx travaille sur le fichier aspiré
		HTML_POUR_LYNX="$FICHIER_HTML"
		# Supprime le fichier temporaire s'il a été crée
		TEMP_HTML=0

		# Si le serveur dit "UTF-8", on force un meta charset utf-8, et on travaille sur une copie temporaire
		if [[ "$ENCODAGE" =~ [Uu][Tt][Ff]-8 ]]; then
			# --- Messages d'information (VERBOSE) ----
			log_step "Choix : header annonce UTF-8 → on force <meta charset=utf-8> et on extrait avec lynx"
			ENCODAGE_AFFICHE="UTF-8"
			# Création d'une copie temporaire (dans dumps-text)
			HTML_POUR_LYNX="../dumps-text/${FICHIER_URLS}/temp-utf8-${n}.html"
			cp "$FICHIER_HTML" "$HTML_POUR_LYNX"
			TEMP_HTML=1
			# Corrige/injecte <meta charset="utf-8"> dans le HTML
			forcer_charset_utf8_html "$HTML_POUR_LYNX"
			# Lynx → txt + calcule nb mots + calcule OCC + génère concordancier
			extraire_et_compter "$HTML_POUR_LYNX" "$n" "$line"
		else
			# Si le fichier est déjà lisible comme UTF-8
			if iconv -f UTF-8 -t UTF-8 "$FICHIER_HTML" >/dev/null 2>&1; then
				# --- Messages d'information (VERBOSE) ----
				log_step "Cas B : le HTML est déjà valide en UTF-8 (iconv UTF-8→UTF-8 OK)"
				ENCODAGE_AFFICHE="UTF-8"
				# Idem
				HTML_POUR_LYNX="../dumps-text/${FICHIER_URLS}/temp-utf8-${n}.html"
				cp "$FICHIER_HTML" "$HTML_POUR_LYNX"
				TEMP_HTML=1
				forcer_charset_utf8_html "$HTML_POUR_LYNX"
				extraire_et_compter "$HTML_POUR_LYNX" "$n" "$line"
			else
				# On choisit un encodage à utiliser :
				# - d'abord : headers (ENCODAGE)
				# - sinon   : encodage détecté par file (ENCODAGE_DETECTE)
				# - sinon.  : fallback windows-1251
				ENC_UTILISE="$ENCODAGE"
				ENC_UTILISE=$(echo "$ENC_UTILISE" | tr '[:upper:]' '[:lower:]')
				ENC_UTILISE=${ENC_UTILISE%%;*}
				ENC_UTILISE=${ENC_UTILISE%%,*}
				if [[ -z "$ENC_UTILISE" || "$ENC_UTILISE" == "-" ]]; then
				ENC_UTILISE="$ENCODAGE_DETECTE"
				fi
				if [[ "$ENC_UTILISE" == "binary" || "$ENC_UTILISE" == "unknown-8bit" || -z "$ENC_UTILISE" ]]; then
				ENC_UTILISE="windows-1251"
				fi

				log_step "Conversion nécessaire → encodage utilisé : $ENC_UTILISE"

				# Fichier temporaire
				HTML_POUR_LYNX="../dumps-text/${FICHIER_URLS}/temp-utf8-${n}.html"
				TEMP_HTML=1

				# Conversion de l'encodage d'origine en UTF-8
				if iconv -f "$ENC_UTILISE" -t UTF-8 "$FICHIER_HTML" > "$HTML_POUR_LYNX" 2>/dev/null; then
					log_step "Conversion réussie ($ENC_UTILISE → UTF-8)"
					# Si la conversion a produit qqch de non vide
					if [[ -s "$HTML_POUR_LYNX" ]]; then
						# On force la balise meta en UTF-8
						ENCODAGE_AFFICHE="UTF-8"
						forcer_charset_utf8_html "$HTML_POUR_LYNX"
						# Extration texte + comptages + KWIC
						extraire_et_compter "$HTML_POUR_LYNX" "$n" "$line"
					fi
				fi
			fi
		fi
		# Nettoyage (supprime le fichier temporaire s'il a été créé)
		if (( TEMP_HTML )); then rm -f "$HTML_POUR_LYNX"; fi
	fi

	# Écrire la ligne finale du tableau HTML
	BADGE_CODE=$(generer_badge_code "$CODE")
	echo "<tr>
		<td>${n}</td>
		<td class=\"url-cell\"><a href=\"${line}\" target=\"_blank\" rel=\"noopener noreferrer\">${line}</a></td>
		<td>${BADGE_CODE}</td>
		<td>${ENCODAGE_AFFICHE}</td>
		<td>${NB_MOTS}</td>
		<td class=\"count-cell\">${OCC_SENS1}</td>
		<td class=\"count-cell\">${OCC_SENS2}</td>
		<td>${LIEN_HTML}</td>
		<td>${LIEN_TEXT}</td>
		<td>${LIEN_CONC}</td>
	</tr>"

	# Màj de la progression
	echo -ne "Progression : $n/$TOTAL\r" >&2
	# URL suivante
	n=$((n+1))

done < "../URLs/$FICHIER_URLS.txt"

# Message final dans le terminal
echo -e "\n✓ Terminé ! $((n-1)) URLs traitées." >&2

# Ajout de la fin du HTML
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

    <script>
      const btn = document.getElementById("themeToggle");
      const saved = localStorage.getItem("theme");
      if (saved === "dark") document.body.classList.add("dark");

      function refreshLabel() {
        const isDark = document.body.classList.contains("dark");
        btn.textContent = isDark ? "☀️ Mode clair" : "🌙 Mode sombre";
      }
      refreshLabel();

      btn.addEventListener("click", () => {
        document.body.classList.toggle("dark");
        localStorage.setItem("theme", document.body.classList.contains("dark") ? "dark" : "light");
        refreshLabel();
      });
    </script>
  </body>
</html>
FOOTER

} > "../tableaux/$FICHIER_SORTIE.html"