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
# Coréen
bash main.sh kr tableau-kr
```

# 2. html_to_contexts.sh

```bash
# Bélarussien
bash concat_contexte_par_sens.sh ../contextes/be be

# Coréen
bash concat_contexte_par_sens.sh ../contextes/kr kr 
```

 # 3. make_pals_corpus.sh

! MODE VERBOSE DISPO

 - Pour le dossier dump :

```bash
# Bélarussien
bash make_pals_corpus.sh ../dumps-text/be/ be > ../pals/dump-be.txt

# Coréen
bash make_pals_corpus.sh ../dumps-text/kr/ kr > ../pals/dump-kr.txt
```

- Pour les fichiers contextes :

```bash
# Bélarussien
bash make_pals_corpus_be.sh ../pals/contexte-be-sens1.txt be > ../pals/pals-be-sens1.txt
bash make_pals_corpus_be.sh ../pals/contexte-be-sens2.txt be > ../pals/pals-be-sens2.txt

# Coréen
bash make_pals_corpus_copy.sh ../pals/contexte-kr-sens1.txt kr > ../pals/pals-kr-sens1.txt
bash make_pals_corpus_copy.sh ../pals/contexte-kr-sens2.txt kr > ../pals/pals-kr-sens2.txt
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

```bash
# Coréen
## sens 1
python3.11 cooccurrents.py ../pals/dump-kr.txt \
  --target 자율 \
  -l 10 \
  -s i \
  > cooc-자율.tsv

# Coréen
## sens 2
python3.11 cooccurrents.py ../pals/dump-kr.txt \
  --target 자립 \
  -l 10 \
  -s i \
  > cooc-자립.tsv
```

# 5 partition.py

```bash
# Bélarussien
python3 partition.py \
  -i ../pals/contexte-be-sens1_cleaned.txt \
  -i ../pals/contexte-be-sens2_cleaned.txt \
  >> partition-be.txt
```

```bash
# Coréen
python3.11 partition.py \
  -i ../pals/contexte-kr-sens1.txt \        
  -i ../pals/contexte-kr-sens2.txt \        
  >> partition-kr.txt
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
  
```bash
  # Coréen
wordcloud_cli \      
  --text ../pals/contexte-kr-sens1_cleaned.txt \
  --stopwords stopwords_kr.txt \
  --imagefile nuage-kr-sens1.png \
  --fontfile /System/Library/Fonts/AppleGothic.ttf
  
wordcloud_cli \      
  --text ../pals/contexte-kr-sens2_cleaned.txt \
  --stopwords stopwords_kr.txt \
  --imagefile nuage-kr-sens2.png \
  --fontfile /System/Library/Fonts/AppleGothic.ttf  
  
  