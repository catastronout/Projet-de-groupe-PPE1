#!/bin/bash
# Usage: bash html_to_contextes.sh <dossier_html> <out_sens1.txt> <out_sens2.txt>

HTML_DIR="$1"
OUT1="$2"
OUT2="$3"

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <dossier_html> <out_sens1.txt> <out_sens2.txt>" >&2
  exit 1
fi

if [ ! -d "$HTML_DIR" ]; then
  echo "Erreur : dossier '$HTML_DIR' introuvable" >&2
  exit 1
fi

# vide les sorties
> "$OUT1"
> "$OUT2"

perl -CSDA -Mutf8 -0777 -e '
  use strict;
  use warnings;
  use utf8;
  use open qw(:std :utf8);

  my ($out1, $out2, @files) = @ARGV;

  open(my $fh1, ">>", $out1) or die "Cannot open $out1: $!";
  open(my $fh2, ">>", $out2) or die "Cannot open $out2: $!";

  for my $file (@files) {
    open(my $in, "<:utf8", $file) or die "Cannot open $file: $!";
    local $/;
    my $html = <$in>;
    close $in;

    while ($html =~ m{<tr\b[^>]*>(.*?)</tr>}gis) {
      my $row = $1;

      my $sens = "";
      if ($row =~ m{<td\b[^>]*class="[^"]*\bcat-col\b[^"]*"[^>]*>\s*(sens\s*[12])\s*</td>}is) {
        $sens = lc($1);
        $sens =~ s/\s+//g; # "sens 1" -> "sens1"
      } else {
        next;
      }

      # récupère toutes les cellules td
      my @td = ($row =~ m{<td\b[^>]*>(.*?)</td>}gis);
      next if @td < 2;

      # IMPORTANT : ici on prend la 2e cellule td comme "contexte"
      my $ctx = $td[1];

      # Nettoyage HTML
      $ctx =~ s/<[^>]+>/ /g;
      $ctx =~ s/&nbsp;/ /g;
      $ctx =~ s/&amp;/&/g;
      $ctx =~ s/&lt;/</g;
      $ctx =~ s/&gt;/>/g;
      $ctx =~ s/\s+/ /g;
      $ctx =~ s/^\s+|\s+$//g;

      next if $ctx eq "";

      if ($sens eq "sens1") { print $fh1 $ctx, "\n"; }
      elsif ($sens eq "sens2") { print $fh2 $ctx, "\n"; }
    }
  }

  close $fh1;
  close $fh2;
' "$OUT1" "$OUT2" "$HTML_DIR"/*.html