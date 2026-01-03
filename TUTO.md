# 1. main.sh

**Exemples** : 
- Avec fichiers contenant toutes les formes des deux lemmes traités ici :

! MODE VERBOSE DISPO

```bash
# Bélarussien
bash main.sh be tableau-be data_be1.txt data_be2.txt
```

- Sans ces fichiers (il faudra rentrer les deux lemmes dans le terminal) :

```bash
# Bélarussien
bash main.sh be tableau-be
```

# 2. html_to_contexts.sh

```bash
# Bélarussien
 bash html_to_contexts.sh ../contextes/be be
 ```

 # 3. make_pals_corpus.sh

! MODE VERBOSE DISPO

 - Pour le dossier dump :

```bash
# Bélarussien
bash make_pals_corpus.sh ../dumps-text/be/ be > ../pals/dump-be.txt
```

- Pour les fichiers contextes :

```bash
# Bélarussien
bash make_pals_corpus_be.sh ../pals/contexte-be-sens1.txt be > ../pals/pals-be-sens1.txt
bash make_pals_corpus_be.sh ../pals/contexte-be-sens2.txt be > ../pals/pals-be-sens2.txt
```

# 4. cooccurrents.py

```bash
# Bélarussien
## sens 1
 python cooccurrents.py ../pals/dump-be.txt \
  --target аўтаномія \
  -l 10 \
  -s i \
  > cooc-autanomiya.tsv

## sens 2
python cooccurrents.py ../pals/dump-be.txt \
  --target "(аўтаномнасьць|аўтаномнасць)" \
  --match-mode regex \
  -l 10 \
  -s i \
  > cooc-autanomnast.tsv
```

# 5 partition.py

```bash
# Bélarussien
python3 partition.py \
  -i ../pals/contexte-be-sens1_cleaned.txt \
  -i ../pals/contexte-be-sens2_cleaned.txt
```

# 6. wordcloud

```bash
# Bélarussien
wordcloud_cli \
  --text ../pals/contexte-be-sens1_cleaned.txt \
  --imagefile nuage_sens1.png \
  --stopwords stopwords_be.txt \
  --fontfile "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"

wordcloud_cli \
  --text ../pals/contexte-be-sens2_cleaned.txt \
  --imagefile nuage_sens2.png \
  --stopwords stopwords_be.txt \
  --fontfile "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
  ```