# ======================================
#     CONCORDANCIER HTML DEPUIS TSV     
# ======================================
# Fonction qui lit un fichier TSV de contextes KWIC et génère un fichier HTML "concordancier"
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
	# Génère un fichier HTML autonome
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
					<td class="cat-col">$cat</td>
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
<html lang="fr">
  <head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Concordancier $urls_name-$idx — Projet PPE1</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital\@0;1&family=DM+Sans:wght\@400;500;600;700&display=swap" rel="stylesheet">
    <style>
      :root {
        --primary: #667eea;
        --primary-dark: #764ba2;
        --accent: #f093fb;
        --bg: #fafafa;
        --bg-card: #ffffff;
        --text: #1a1a2e;
        --text-muted: #6b7280;
        --border: #e5e7eb;
        --gradient: linear-gradient(135deg, #667eea 0%, #764ba2 50%, #f093fb 100%);
        --shadow: 0 4px 24px rgba(102, 126, 234, 0.12);
        --radius: 16px;
        --radius-sm: 8px;
      }

      body.dark {
        --bg: #0f0f1a;
        --bg-card: #1a1a2e;
        --text: #f1f5f9;
        --text-muted: #94a3b8;
        --border: #2d2d44;
        --shadow: 0 4px 24px rgba(0, 0, 0, 0.3);
      }

      * { margin: 0; padding: 0; box-sizing: border-box; }

      body {
        font-family: 'DM Sans', sans-serif;
        background: var(--bg);
        color: var(--text);
        line-height: 1.6;
        transition: background 0.3s, color 0.3s;
      }

      /* Navigation */
      nav {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        z-index: 1000;
        background: var(--bg-card);
        border-bottom: 1px solid var(--border);
        backdrop-filter: blur(12px);
      }

      .nav-container {
        max-width: 1400px;
        margin: 0 auto;
        padding: 1rem 2rem;
        display: flex;
        justify-content: space-between;
        align-items: center;
      }

      .nav-logo {
        font-family: 'Instrument Serif', serif;
        font-size: 1.5rem;
        font-style: italic;
        background: var(--gradient);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        text-decoration: none;
      }

      .nav-links {
        display: flex;
        gap: 2rem;
        align-items: center;
      }

      .nav-links a {
        color: var(--text-muted);
        text-decoration: none;
        font-size: 0.9rem;
        font-weight: 500;
        transition: color 0.2s;
      }

      .nav-links a:hover { color: var(--primary); }

      .theme-toggle {
        background: var(--border);
        border: none;
        width: 40px;
        height: 40px;
        border-radius: 50%;
        cursor: pointer;
        font-size: 1.1rem;
        transition: transform 0.2s;
      }

      .theme-toggle:hover { transform: scale(1.1); }

      /* Header */
      .page-header {
        padding: 7rem 2rem 3rem;
        text-align: center;
      }

      .page-header h1 {
        font-family: 'Instrument Serif', serif;
        font-size: 2.5rem;
        margin-bottom: 0.5rem;
      }

      .page-header p {
        color: var(--text-muted);
        margin-bottom: 0.5rem;
      }

      .page-header .url-link {
        color: var(--primary);
        text-decoration: none;
        word-break: break-all;
        font-size: 0.9rem;
      }

      .page-header .url-link:hover {
        color: var(--primary-dark);
      }

      /* Main */
      main {
        max-width: 1400px;
        margin: 0 auto;
        padding: 0 2rem 4rem;
      }

      .back-link {
        display: inline-flex;
        align-items: center;
        gap: 0.5rem;
        color: var(--primary);
        text-decoration: none;
        font-weight: 500;
        margin-bottom: 1.5rem;
        transition: gap 0.2s;
      }

      .back-link:hover { gap: 0.75rem; }

      /* Info card */
      .info-card {
        background: var(--bg-card);
        border: 1px solid var(--border);
        border-radius: var(--radius);
        padding: 1.5rem;
        margin-bottom: 2rem;
        box-shadow: var(--shadow);
      }

      .info-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 1rem;
      }

      .info-item strong {
        color: var(--text-muted);
        font-size: 0.85rem;
        display: block;
        margin-bottom: 0.25rem;
      }

      .info-item span {
        font-size: 1.25rem;
        font-weight: 600;
        color: var(--primary);
      }

      /* Table card */
      .table-card {
        background: var(--bg-card);
        border: 1px solid var(--border);
        border-radius: var(--radius);
        box-shadow: var(--shadow);
        overflow: hidden;
      }

      .table-container {
        overflow-x: auto;
      }

      table {
        width: 100%;
        border-collapse: collapse;
        font-size: 0.9rem;
      }

      thead th {
        background: var(--bg);
        color: var(--text);
        font-weight: 600;
        padding: 1rem;
        text-align: left;
        border-bottom: 2px solid var(--primary);
        white-space: nowrap;
      }

      tbody td {
        padding: 0.875rem 1rem;
        border-bottom: 1px solid var(--border);
        vertical-align: middle;
      }

      tbody tr:hover td {
        background: rgba(102, 126, 234, 0.05);
      }

      tbody tr:last-child td {
        border-bottom: none;
      }

      /* KWIC specific styles */
      .cat-col {
        color: var(--text-muted);
        font-weight: 600;
        white-space: nowrap;
        font-size: 0.85rem;
      }

      .kwic-left, .kwic-kw, .kwic-right {
        font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
        font-size: 0.9rem;
      }

      .kwic-left {
        text-align: right;
        width: 40%;
        color: var(--text-muted);
      }

      .kwic-kw {
        text-align: center;
        width: 20%;
        font-weight: 700;
      }

      .kwic-right {
        text-align: left;
        width: 40%;
        color: var(--text-muted);
      }

      mark {
        background: rgba(102, 126, 234, 0.2);
        color: var(--text);
        padding: 0.2rem 0.4rem;
        border-radius: 4px;
        font-weight: 700;
      }

      body.dark mark {
        background: rgba(147, 197, 253, 0.25);
        color: var(--text);
      }

      /* Footer */
      footer {
        text-align: center;
        padding: 2rem;
        border-top: 1px solid var(--border);
        color: var(--text-muted);
        font-size: 0.85rem;
      }

      /* Responsive */
      @media (max-width: 768px) {
        .nav-links { display: none; }
        .page-header h1 { font-size: 2rem; }
        .info-grid { grid-template-columns: 1fr; }
      }
    </style>
  </head>

  <body>
    <nav>
      <div class="nav-container">
        <a href="../../index.html" class="nav-logo">Autonomie</a>
        <div class="nav-links">
          <a href="../../index.html#projet">Projet</a>
          <a href="../../index.html#langues">Langues</a>
          <a href="../../index.html#equipe">Contributeurs</a>
          <a href="../../scripts.html">Scripts</a>
          <button class="theme-toggle" id="themeToggle">🌙</button>
        </div>
      </div>
    </nav>

    <header class="page-header">
      <h1>Concordancier (KWIC)</h1>
      <p>Fenêtre : ±$w mots</p>
      <a href="$url" target="_blank" rel="noopener noreferrer" class="url-link">$url</a>
    </header>

    <main>
      <a href="../../tableaux/tableau-$urls_name.html" class="back-link">← Retour au tableau</a>

      <div class="info-card">
        <div class="info-grid">
          <div class="info-item">
            <strong>Document</strong>
            <span>$urls_name-$idx</span>
          </div>
          <div class="info-item">
            <strong>Occurrences</strong>
            <span>$n</span>
          </div>
        </div>
      </div>

      <div class="table-card">
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Catégorie</th>
                <th>Contexte gauche</th>
                <th>Mot-clé</th>
                <th>Contexte droit</th>
              </tr>
            </thead>
            <tbody>
};

		if (@rows) {
			print $OUT join("\n", @rows), "\n";
		} else {
			print $OUT qq{              <tr><td colspan="4" style="text-align: center; color: var(--text-muted);">Aucune occurrence trouvée.</td></tr>\n};
		}

		print $OUT qq{
            </tbody>
          </table>
        </div>
      </div>
    </main>

    <footer>
      <p>Projet PPE1 — M1 TAL — Université Sorbonne Nouvelle — 2025-2026</p>
    </footer>

    <script>
      const btn = document.getElementById('themeToggle');
      const saved = localStorage.getItem('theme');
      if (saved === 'dark') document.body.classList.add('dark');

      function updateBtn() {
        btn.textContent = document.body.classList.contains('dark') ? '☀️' : '🌙';
      }
      updateBtn();

      btn.addEventListener('click', () => {
        document.body.classList.toggle('dark');
        localStorage.setItem('theme', document.body.classList.contains('dark') ? 'dark' : 'light');
        updateBtn();
      });
    </script>
  </body>
</html>
};

		close $OUT;
	' "$tsv" "$out" "$url" "$CONTEXT_WORDS" "$FICHIER_URLS" "$idx"

	echo "$out"
}
