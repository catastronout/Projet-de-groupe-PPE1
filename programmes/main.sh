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

log() {
	(( VERBOSE )) && echo "[INFO] $*" >&2
}

log_step() {
	(( VERBOSE )) && echo "       ↳ $*" >&2
}

die() {
	echo "[ERREUR] $*" >&2
	exit 1
}

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

mkdir -p "../dumps-text/${FICHIER_URLS}"
mkdir -p "../aspirations/${FICHIER_URLS}"
mkdir -p "../contextes/${FICHIER_URLS}"
mkdir -p "../tableaux"

log "Création dossiers dumps/aspirations/contextes/tableaux pour $FICHIER_URLS"

# === Badge HTTP (corrigé) ===
generer_badge_code() {
  local code="$1"

  # normalise : si vide -> 000
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
    # IMPORTANT : on affiche 000 (c’est le “vrai” code curl quand aucune réponse HTTP)
    echo "<span class=\"tag is-light has-text-grey-light\">000</span>"
  else
    echo "<span class=\"tag is-light\">${code}</span>"
  fi
}

# Force/normalise un charset UTF-8 dans le HTML (pour éviter le mojibake dans lynx)
forcer_charset_utf8_html() {
  local f="$1"

  # 1) Remplace toutes les occurrences charset=... par charset=utf-8
  perl -i -pe 's/(charset\s*=\s*)["'\'']?[^"'\'' >;]+/${1}utf-8/ig' "$f"

  # 2) Si malgré tout aucun "charset" n'existe, on injecte un meta charset utf-8 dans <head>
  if ! grep -qi "charset" "$f"; then
    perl -0777 -i -pe 's/<head([^>]*)>/<head$1>\n<meta charset="utf-8">/i' "$f"
  fi
}

# Extraction commune (txt, nb mots, occurrences, contextes) à partir d'un HTML "prêt"
extraire_et_compter() {
  local html_src="$1"
  local idx="$2"

  FICHIER_TEXTE="../dumps-text/${FICHIER_URLS}/${FICHIER_URLS}-${idx}.txt"
  lynx -force_html -dump -nolist -assume_charset=utf-8 -display_charset=utf-8 "$html_src" > "$FICHIER_TEXTE" 2>/dev/null

  if [[ -s "$FICHIER_TEXTE" ]]; then
    LIEN_TEXT="<a href='../dumps-text/${FICHIER_URLS}/${FICHIER_URLS}-${idx}.txt' style='color: #667eea;'>TXT</a>"
    NB_MOTS=$(wc -w < "$FICHIER_TEXTE")

    # Occurrences
    OCC_SENS1=0
    for mot in "${MOTIFS_SENS1[@]}"; do
      mot=$(echo "$mot" | tr -d '\r\n ')
      [[ -z "$mot" ]] && continue
      count=$(grep -o ".*$mot.*" "$FICHIER_TEXTE" | grep -o "$mot" | wc -l)
      OCC_SENS1=$((OCC_SENS1 + count))
    done

    OCC_SENS2=0
    for mot in "${MOTIFS_SENS2[@]}"; do
      mot=$(echo "$mot" | tr -d '\r\n ')
      [[ -z "$mot" ]] && continue
      count=$(grep -o ".*$mot.*" "$FICHIER_TEXTE" | grep -o "$mot" | wc -l)
      OCC_SENS2=$((OCC_SENS2 + count))
    done

    # Contextes sens 1
    if [[ "$OCC_SENS1" -gt 0 ]]; then
      FICHIER_CONTEXTE1="../contextes/${FICHIER_URLS}/${FICHIER_URLS}-${idx}-sens1.txt"
      > "$FICHIER_CONTEXTE1"
      for mot in "${MOTIFS_SENS1[@]}"; do
        mot=$(echo "$mot" | tr -d '\r\n ')
        [[ -z "$mot" ]] && continue
        grep -oP '\S+\s*'"$mot"'\S*(?:\s*\S+)?' "$FICHIER_TEXTE" >> "$FICHIER_CONTEXTE1" 2>/dev/null || \
        grep -oE '(\S+\s*)?'"$mot"'\S*(\s*\S+)?' "$FICHIER_TEXTE" >> "$FICHIER_CONTEXTE1"
      done
    fi

    # Contextes sens 2
    if [[ "$OCC_SENS2" -gt 0 ]]; then
      FICHIER_CONTEXTE2="../contextes/${FICHIER_URLS}/${FICHIER_URLS}-${idx}-sens2.txt"
      > "$FICHIER_CONTEXTE2"
      for mot in "${MOTIFS_SENS2[@]}"; do
        mot=$(echo "$mot" | tr -d '\r\n ')
        [[ -z "$mot" ]] && continue
        grep -oP '\S+\s*'"$mot"'\S*(?:\s*\S+)?' "$FICHIER_TEXTE" >> "$FICHIER_CONTEXTE2" 2>/dev/null || \
        grep -oE '(\S+\s*)?'"$mot"'\S*(\s*\S+)?' "$FICHIER_TEXTE" >> "$FICHIER_CONTEXTE2"
      done
    fi
  else
    log_step "Extraction texte : KO (fichier vide ou lynx a échoué)"
    NB_MOTS="-"
    OCC_SENS1="-"
    OCC_SENS2="-"
    LIEN_TEXT="-"
  fi
}

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

  # ===== CAS 000 : on n'aspire RIEN =====
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
      </tr>"

    echo -ne "Progression : $n/$TOTAL\r" >&2
    n=$((n+1))
    continue
  fi
# ===== FIN CAS 000 =====

  # Important : suivre les redirects pour avoir le bon header final
  ENCODAGE=$(curl -sIL -L -A "$UA" "$line" | tr -d '\r' | grep -i -o 'charset=[^;[:space:]]*' | head -n1 | cut -d= -f2)
  [[ -z "$ENCODAGE" ]] && ENCODAGE="-"
  ENCODAGE_AFFICHE="$ENCODAGE"
  log_step "Header charset (serveur) : $ENCODAGE"

  NB_MOTS="-"
  OCC_SENS1="-"
  OCC_SENS2="-"
  LIEN_HTML="-"
  LIEN_TEXT="-"

  # On dump le HTML (même si pas 200, comme tu faisais)
  # On ne télécharge PAS le HTML si pas de réponse HTTP
  if [[ "$CODE" == "000" ]]; then
    log_step "Pas de réponse HTTP → pas d'aspiration HTML"
    LIEN_HTML="-"
    LIEN_TEXT="-"
    NB_MOTS="-"
    OCC_SENS1="-"
    OCC_SENS2="-"
  else
    FICHIER_HTML="../aspirations/${FICHIER_URLS}/${FICHIER_URLS}-${n}.html"
    curl -sL --compressed -A "$UA" "$line" > "$FICHIER_HTML"
    LIEN_HTML="<a href='../aspirations/${FICHIER_URLS}/${FICHIER_URLS}-${n}.html' style='color: #667eea;'>HTML</a>"
  fi

  # Si on n'a pas de HTML exploitable, on skip l'extraction
  if [[ ! -s "$FICHIER_HTML" ]]; then
    log_step "HTML vide → pas d'extraction"
  else
    # Encodage détecté par file (info)
    ENCODAGE_DETECTE=$(file -b --mime-encoding "$FICHIER_HTML")
    log_step "Encodage détecté par file : $ENCODAGE_DETECTE"

    # On va définir un HTML "prêt pour lynx" dans HTML_POUR_LYNX
    HTML_POUR_LYNX="$FICHIER_HTML"
    TEMP_HTML=0

    # Cas 1 : header indique UTF-8 → on force le meta charset à utf-8 (au cas où il ment)
    if [[ "$ENCODAGE" =~ [Uu][Tt][Ff]-8 ]]; then
      ENCODAGE_AFFICHE="UTF-8"
      # On crée une copie temp pour ne pas modifier l'aspiration brute
      HTML_POUR_LYNX="../dumps-text/${FICHIER_URLS}/temp-utf8-${n}.html"
      cp "$FICHIER_HTML" "$HTML_POUR_LYNX"
      TEMP_HTML=1
      forcer_charset_utf8_html "$HTML_POUR_LYNX"
      extraire_et_compter "$HTML_POUR_LYNX" "$n"

    else
      # Cas 2 : header pas UTF-8
      # 2a) si le contenu est déjà UTF-8 valide → pas de conversion, mais on corrige meta pour lynx
      if iconv -f UTF-8 -t UTF-8 "$FICHIER_HTML" >/dev/null 2>&1; then
        log_step "Contenu déjà UTF-8 (même si header != UTF-8) → pas de conversion"
        ENCODAGE_AFFICHE="UTF-8"

        HTML_POUR_LYNX="../dumps-text/${FICHIER_URLS}/temp-utf8-${n}.html"
        cp "$FICHIER_HTML" "$HTML_POUR_LYNX"
        TEMP_HTML=1
        forcer_charset_utf8_html "$HTML_POUR_LYNX"
        extraire_et_compter "$HTML_POUR_LYNX" "$n"

      else
        # 2b) sinon, on tente une conversion iconv vers UTF-8
        ENC_UTILISE="$ENCODAGE"
        ENC_UTILISE=$(echo "$ENC_UTILISE" | tr '[:upper:]' '[:lower:]')
        ENC_UTILISE=${ENC_UTILISE%%;*}
        ENC_UTILISE=${ENC_UTILISE%%,*}

        # si header vide/-, on tente file
        if [[ -z "$ENC_UTILISE" || "$ENC_UTILISE" == "-" ]]; then
          ENC_UTILISE="$ENCODAGE_DETECTE"
        fi

        # fallback
        if [[ "$ENC_UTILISE" == "binary" || "$ENC_UTILISE" == "unknown-8bit" || -z "$ENC_UTILISE" ]]; then
          ENC_UTILISE="windows-1251"
        fi

        log_step "Encodage choisi pour iconv : $ENC_UTILISE"

        HTML_POUR_LYNX="../dumps-text/${FICHIER_URLS}/temp-utf8-${n}.html"
        TEMP_HTML=1

        if iconv -f "$ENC_UTILISE" -t UTF-8 "$FICHIER_HTML" > "$HTML_POUR_LYNX" 2>/dev/null; then
          if [[ -s "$HTML_POUR_LYNX" ]]; then
            log_step "Conversion iconv : OK"
            ENCODAGE_AFFICHE="UTF-8"
            forcer_charset_utf8_html "$HTML_POUR_LYNX"
            extraire_et_compter "$HTML_POUR_LYNX" "$n"
          else
            log_step "Conversion iconv : KO (fichier vide)"
          fi
        else
          log_step "Conversion iconv : KO (erreur iconv)"
        fi
      fi
    fi

    # Nettoyage temp
    if (( TEMP_HTML )); then
      rm -f "$HTML_POUR_LYNX"
    fi
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