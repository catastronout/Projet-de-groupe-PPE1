#!/bin/bash

# --- UTILISATION ---
# 1. Se mettre dans le répertoire miniprojet/programmes
# 2. Lancer : bash main.sh <urls> <tableau> [fichier_sens1 fichier_sens2]
# Exemples :
#   bash main.sh be_sens1_autanomia tableau-be1 data_sens1.txt data_sens2.txt
#   bash main.sh kr tableau-kr1 data_sens1.txt data_sens2.txt

# ===== MODE VERBOSE / DEBUG =====
VERBOSE=0
DEBUG=0

log() { (( VERBOSE )) && echo "[INFO] $*" >&2; }
log_step() { (( VERBOSE )) && echo "       ↳ $*" >&2; }

usage() {
  echo "Usage:"
  echo "  $0 [-v] [-d] <urls> <tableau> [fichier_sens1 fichier_sens2]"
  echo "  -v : verbose (messages lisibles)"
  echo "  -d : debug (trace bash avec numéros de ligne)"
  exit 1
}

while getopts ":vd" opt; do
  case "$opt" in
    v) VERBOSE=1 ;;
    d) DEBUG=1 ;;
    *) usage ;;
  esac
done
shift $((OPTIND-1))

if (( DEBUG )); then
  export PS4='+ ${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]:-main}: '
  set -x
fi
# =================================

FICHIER_URLS=$1
FICHIER_SORTIE=$2
FICHIER_MOTS_SENS1=$3
FICHIER_MOTS_SENS2=$4

if (( $# < 2 )); then
  echo "Ce script a besoin d'au moins deux arguments !"
  echo "Usage:"
  echo "  $0 <ENTRÉE_fichier_URLs> <SORTIE_fichier_tableau> <fichier_sens1> <fichier_sens2>"
  echo "  $0 <ENTRÉE_fichier_URLs> <SORTIE_fichier_tableau>"
  exit 1
fi

if [[ ! -f "../URLs/$FICHIER_URLS.txt" ]]; then
  echo "Erreur : le fichier ../URLs/$FICHIER_URLS.txt n'existe pas !"
  exit 1
fi

log "URLs: ../URLs/$FICHIER_URLS.txt"
log "Sortie: ../tableaux/$FICHIER_SORTIE.html"
log "Sens1 fichier: $FICHIER_MOTS_SENS1 | Sens2 fichier: $FICHIER_MOTS_SENS2"

# Déterminer la source des motifs (2 fichiers ou saisie terminal)
MOTIFS_SENS1=()
MOTIFS_SENS2=()
LABEL_SENS1=""
LABEL_SENS2=""

if [[ -n "$FICHIER_MOTS_SENS1" && -n "$FICHIER_MOTS_SENS2" && -f "$FICHIER_MOTS_SENS1" && -f "$FICHIER_MOTS_SENS2" ]]; then
  while IFS= read -r m; do
    m=$(echo "$m" | tr -d '\r\n ')
    [[ -n "$m" ]] && MOTIFS_SENS1+=("$m")
  done < "$FICHIER_MOTS_SENS1"

  while IFS= read -r m; do
    m=$(echo "$m" | tr -d '\r\n ')
    [[ -n "$m" ]] && MOTIFS_SENS2+=("$m")
  done < "$FICHIER_MOTS_SENS2"

  read -rp "Nom de colonne / lemme pour le sens 1 : " LABEL_SENS1
  read -rp "Nom de colonne / lemme pour le sens 2 : " LABEL_SENS2
  [[ -z "$LABEL_SENS1" ]] && LABEL_SENS1="sens 1"
  [[ -z "$LABEL_SENS2" ]] && LABEL_SENS2="sens 2"
else
  read -rp "Écris le mot 1 (sens 1) : " m1
  read -rp "Écris le mot 2 (sens 2) : " m2
  [[ -n "$m1" ]] && MOTIFS_SENS1+=("$m1")
  [[ -n "$m2" ]] && MOTIFS_SENS2+=("$m2")
  LABEL_SENS1="$m1"
  LABEL_SENS2="$m2"
fi

n=1
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Taille du contexte KWIC : nombre de mots à gauche et à droite
CONTEXT_WORDS=20

mkdir -p "../dumps-text/${FICHIER_URLS}"
mkdir -p "../aspirations/${FICHIER_URLS}"
mkdir -p "../contextes/${FICHIER_URLS}"
mkdir -p "../tableaux"
mkdir -p "../concordances/${FICHIER_URLS}"

log "Création dossiers dumps/aspirations/contextes/tableaux/concordances pour $FICHIER_URLS"

# ===== Helpers UTF-8 / badge =====

generer_badge_code() {
  local code="$1"
  [[ -z "$code" ]] && code="000"

  if [[ "$code" == "200" ]]; then
    echo "<span class=\"tag is-success is-light\">${code}</span>"
  elif [[ "$code" =~ ^3 ]]; then
    echo "<span class=\"tag is-info is-light\">${code}</span>"
  elif [[ "$code" =~ ^4 ]]; then
    echo "<span class=\"tag is-danger is-light\">${code}</span>"
  elif [[ "$code" =~ ^5 ]]; then
    echo "<span class=\"tag is-warning is-light\">${code}</span>"
  elif [[ "$code" == "000" ]]; then
    echo "<span class=\"tag is-light has-text-grey-light\">000</span>"
  else
    echo "<span class=\"tag is-light\">${code}</span>"
  fi
}

forcer_charset_utf8_html() {
  local f="$1"
  perl -i -pe 's/(charset\s*=\s*)["'\'']?[^"'\'' >;]+/${1}utf-8/ig' "$f"
  if ! grep -qi "charset" "$f"; then
    perl -0777 -i -pe 's/<head([^>]*)>/<head$1>\n<meta charset="utf-8">/i' "$f"
  fi
}

# Join "contenu du tableau bash" avec un délimiteur (compatible bash ancien)
# Usage: join_array DELIM ARRAY_NAME
join_array() {
  local delim="$1"
  local array_name="$2"
  local out=""
  local x

  eval "set -- \"\${${array_name}[@]}\""
  for x in "$@"; do
    x=$(echo "$x" | tr -d '\r\n ')
    [[ -z "$x" ]] && continue
    if [[ -z "$out" ]]; then out="$x"; else out="${out}${delim}${x}"; fi
  done
  printf "%s" "$out"
}

# ===== KWIC TSV generator =====
# Produit un TSV: LABEL \t LEFT \t KW \t RIGHT
# Motif match = token == motif (case-insensitive Unicode via lc)
generer_kwic_tsv() {
  local txt="$1"
  local out_tsv="$2"
  local label="$3"
  local motifs_joined="$4"   # motifs séparés par \x1F
  local w="$5"

  perl -Mutf8 -CS -e '
    use strict; use warnings;
    use Encode qw(decode FB_DEFAULT);

    my ($txt, $out, $label, $joined, $w) = @ARGV;

    # decode args "tolérant" (au cas où)
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

    # Tokenisation Unicode: lettres/nombres + apostrophes + tirets
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

      # TSV brut (on échappera en HTML plus tard)
      $left  =~ s/\t/ /g;
      $kw    =~ s/\t/ /g;
      $right =~ s/\t/ /g;

      print $OUT $label, "\t", $left, "\t", $kw, "\t", $right, "\n";
    }

    close $OUT;
  ' "$txt" "$out_tsv" "$label" "$motifs_joined" "$w"
}

# ===== Concordancier HTML depuis TSV =====
generer_concordancier_html_depuis_tsv() {
  local idx="$1"
  local url="$2"
  local tsv="$3"
  local out="../concordances/${FICHIER_URLS}/${FICHIER_URLS}-${idx}.html"

  perl -Mutf8 -CS -e '
    use strict; use warnings;
    use Encode qw(decode FB_DEFAULT);

    my ($tsv, $out, $url, $w) = @ARGV;
    $url = decode("UTF-8", $url, FB_DEFAULT);

    open my $IN, "<:encoding(UTF-8)", $tsv or die "Cannot open $tsv\n";
    my @rows;
    while (my $line = <$IN>) {
      chomp $line;
      my ($cat, $left, $kw, $right) = split(/\t/, $line, 4);
      $cat   //= ""; $left  //= ""; $kw //= ""; $right //= "";

      # escape HTML minimal
      for ($cat,$left,$kw,$right) {
        s/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g;
      }

      push @rows, qq{<tr><td class="has-text-grey">$cat</td><td class="kwic-left">$left</td><td class="kwic-kw"><mark>$kw</mark></td><td class="kwic-right">$right</td></tr>};
    }
    close $IN;

    open my $OUT, ">:encoding(UTF-8)", $out or die "Cannot write $out\n";

    print $OUT <<"HTML";
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Concordancier - $url</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css">
  <style>
    body { padding: 1.25rem; }
    .kwic-left { text-align: right; width: 45%; font-family: monospace; font-size: 0.9rem; }
    .kwic-kw   { text-align: center; width: 10%; font-family: monospace; font-weight: bold; }
    .kwic-right{ text-align: left; width: 45%; font-family: monospace; font-size: 0.9rem; }
    mark { padding: 0.1rem 0.2rem; }
  </style>
</head>
<body>
  <h1 class="title is-4">Concordancier (KWIC)</h1>
  <p class="mb-3"><strong>URL :</strong> <a href="$url" target="_blank" rel="noopener noreferrer">$url</a></p>
  <p class="mb-5"><strong>Fenêtre :</strong> ±$w mots</p>

  <div class="table-container">
    <table class="table is-fullwidth is-striped">
      <thead>
        <tr>
          <th>Catégorie</th>
          <th>Gauche</th>
          <th>Mot</th>
          <th>Droite</th>
        </tr>
      </thead>
      <tbody>
HTML

    if (@rows) {
      print $OUT join("\n", @rows), "\n";
    } else {
      print $OUT qq{<tr><td colspan="4">Aucune occurrence trouvée.</td></tr>\n};
    }

    print $OUT <<"HTML";
      </tbody>
    </table>
  </div>
</body>
</html>
HTML

    close $OUT;
  ' "$tsv" "$out" "$url" "$CONTEXT_WORDS"

  echo "$out"
}

# ===== Extraction texte + KWIC TSV + concordancier HTML =====
extraire_et_compter() {
  local html_src="$1"
  local idx="$2"
  local url="$3"

  local FICHIER_TEXTE="../dumps-text/${FICHIER_URLS}/${FICHIER_URLS}-${idx}.txt"
  export LC_ALL=en_US.UTF-8

  lynx -force_html -dump -nolist -assume_charset=utf-8 -display_charset=utf-8 "$html_src" > "$FICHIER_TEXTE" 2>/dev/null

  if [[ -s "$FICHIER_TEXTE" ]]; then
    LIEN_TEXT="<a href='../dumps-text/${FICHIER_URLS}/${FICHIER_URLS}-${idx}.txt' style='color: #667eea;'>TXT</a>"
    NB_MOTS=$(wc -w < "$FICHIER_TEXTE")

    # ---- KWIC TSV (vrai tableau) ----
    local DELIM=$'\x1F'
    local motifs1 motifs2
    motifs1=$(join_array "$DELIM" "MOTIFS_SENS1")
    motifs2=$(join_array "$DELIM" "MOTIFS_SENS2")

    local TSV1="../contextes/${FICHIER_URLS}/${FICHIER_URLS}-${idx}-sens1.tsv"
    local TSV2="../contextes/${FICHIER_URLS}/${FICHIER_URLS}-${idx}-sens2.tsv"
    local TSV_ALL="../contextes/${FICHIER_URLS}/${FICHIER_URLS}-${idx}-kwic.tsv"

    : > "$TSV1"
    : > "$TSV2"
    : > "$TSV_ALL"

    # génère TSV
    [[ -n "$motifs1" ]] && generer_kwic_tsv "$FICHIER_TEXTE" "$TSV1" "$LABEL_SENS1" "$motifs1" "$CONTEXT_WORDS"
    [[ -n "$motifs2" ]] && generer_kwic_tsv "$FICHIER_TEXTE" "$TSV2" "$LABEL_SENS2" "$motifs2" "$CONTEXT_WORDS"

    # concat
    cat "$TSV1" "$TSV2" > "$TSV_ALL" 2>/dev/null

    # Occurrences = nombre de lignes TSV par catégorie
    OCC_SENS1=$(awk -F'\t' -v lab="$LABEL_SENS1" '$1==lab {c++} END{print c+0}' "$TSV_ALL")
    OCC_SENS2=$(awk -F'\t' -v lab="$LABEL_SENS2" '$1==lab {c++} END{print c+0}' "$TSV_ALL")

    # Concordancier HTML basé sur le TSV
    generer_concordancier_html_depuis_tsv "$idx" "$url" "$TSV_ALL" >/dev/null
    LIEN_CONC="<a href='../concordances/${FICHIER_URLS}/${FICHIER_URLS}-${idx}.html' style='color: #667eea;'>KWIC</a>"

  else
    log_step "Extraction texte : KO (fichier vide ou lynx a échoué)"
    NB_MOTS="-"
    OCC_SENS1="-"
    OCC_SENS2="-"
    LIEN_TEXT="-"
    LIEN_CONC="-"
  fi
}

# ========================= Génération du tableau HTML =========================

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

TOTAL=$(wc -l < "../URLs/$FICHIER_URLS.txt")

while read -r line; do
  line=$(echo "$line" | tr -d '\r')
  log "[$n/$TOTAL] Traitement URL: $line"

  CODE=$(curl -sL --max-time 20 -A "$UA" -o /dev/null -w "%{http_code}" "$line")
  [[ -z "$CODE" ]] && CODE="000"

  if [[ "$CODE" == "000" ]]; then
    BADGE_CODE=$(generer_badge_code "$CODE")
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
    echo -ne "Progression : $n/$TOTAL\r" >&2
    n=$((n+1))
    continue
  fi

  ENCODAGE=$(curl -sIL -L -A "$UA" "$line" | tr -d '\r' | grep -i -o 'charset=[^;[:space:]]*' | head -n1 | cut -d= -f2)
  [[ -z "$ENCODAGE" ]] && ENCODAGE="-"
  ENCODAGE_AFFICHE="$ENCODAGE"

  NB_MOTS="-"
  OCC_SENS1="-"
  OCC_SENS2="-"
  LIEN_HTML="-"
  LIEN_TEXT="-"
  LIEN_CONC="-"

  FICHIER_HTML="../aspirations/${FICHIER_URLS}/${FICHIER_URLS}-${n}.html"
  curl -sL --compressed -A "$UA" "$line" > "$FICHIER_HTML"
  LIEN_HTML="<a href='../aspirations/${FICHIER_URLS}/${FICHIER_URLS}-${n}.html' style='color: #667eea;'>HTML</a>"

  if [[ -s "$FICHIER_HTML" ]]; then
    ENCODAGE_DETECTE=$(file -b --mime-encoding "$FICHIER_HTML")

    HTML_POUR_LYNX="$FICHIER_HTML"
    TEMP_HTML=0

    if [[ "$ENCODAGE" =~ [Uu][Tt][Ff]-8 ]]; then
      ENCODAGE_AFFICHE="UTF-8"
      HTML_POUR_LYNX="../dumps-text/${FICHIER_URLS}/temp-utf8-${n}.html"
      cp "$FICHIER_HTML" "$HTML_POUR_LYNX"
      TEMP_HTML=1
      forcer_charset_utf8_html "$HTML_POUR_LYNX"
      extraire_et_compter "$HTML_POUR_LYNX" "$n" "$line"

    else
      if iconv -f UTF-8 -t UTF-8 "$FICHIER_HTML" >/dev/null 2>&1; then
        ENCODAGE_AFFICHE="UTF-8"
        HTML_POUR_LYNX="../dumps-text/${FICHIER_URLS}/temp-utf8-${n}.html"
        cp "$FICHIER_HTML" "$HTML_POUR_LYNX"
        TEMP_HTML=1
        forcer_charset_utf8_html "$HTML_POUR_LYNX"
        extraire_et_compter "$HTML_POUR_LYNX" "$n" "$line"
      else
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

        HTML_POUR_LYNX="../dumps-text/${FICHIER_URLS}/temp-utf8-${n}.html"
        TEMP_HTML=1

        if iconv -f "$ENC_UTILISE" -t UTF-8 "$FICHIER_HTML" > "$HTML_POUR_LYNX" 2>/dev/null; then
          if [[ -s "$HTML_POUR_LYNX" ]]; then
            ENCODAGE_AFFICHE="UTF-8"
            forcer_charset_utf8_html "$HTML_POUR_LYNX"
            extraire_et_compter "$HTML_POUR_LYNX" "$n" "$line"
          fi
        fi
      fi
    fi

    if (( TEMP_HTML )); then rm -f "$HTML_POUR_LYNX"; fi
  fi

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

  echo -ne "Progression : $n/$TOTAL\r" >&2
  n=$((n+1))

done < "../URLs/$FICHIER_URLS.txt"

echo -e "\n✓ Terminé ! $((n-1)) URLs traitées." >&2

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