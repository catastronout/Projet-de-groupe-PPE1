# Journal de bord

## Mercredi 3 décembre
**Sarah** : création du journal de bord, création d'un fichier d'URLs pour le bélarussien

## Jeudi 4 décembre
**Sarah** : En turc, en coréen et en bélarussien, le mot "autonomie" se traduit différemment selon le sens :
- sens 1 - autonomie "humaine / sociale" : utilisé pour une personne, une région, une communauté, etc., quand on parle d’indépendance matérielle, économique ou politique
- sens 2 - autonomie "technique" : utilisé pour les machines, des systèmes ou tout ce qui fonctionne de manière automatique, sans intervention humaine

\+ création des fichiers `be_sens1_autanamia.txt` et `be_sens2_autanamnast.txt`+ ajout de 50 liens pour le sens 1

## Mercredi 24 décembre
**Yeji** : création d’un script 'urls-to-table' pour récupérer des informations telles que le code HTTP, l’encodage, etc

Cependant, lorsque j'ai lancé le script sur la liste d'URLs coréennes, tous les codes HTTP s'affichaient comme 000. Ensuite, j'ai testé directement la commande suivante dans le terminal : 
curl -I https://www.ohmynews.com 

Et le résultat était le suivant :
curl: (60) SSL certificate problem: self signed certificate in certificate chain


## Jeudi 25 décembre
**Sarah** : ajout du script `main.sh` qui permet, pour le moment, d'aspirer le contenu des pages web et de récupérer le code HTTP, l'encodage et le nombre de mots pour chaque page, et de générer une page web avec un style Bulma. J'ai testé le script sur le corpus de bélarussien sens 1 et de coréen. RAS pour le premier. Pour le second en revanche, les colonnes de code HTTP, d'encodage et de nombre de mots étaient vides. Après vérification, le fichier `kr.txt` contenant les URLs contenait des `\r\`, que j'ai supprimé grâce à la commande `sed -i '' 's/\r$//' ../URLs/kr.txt` (`main.sh` est basé sur le travail que j'avais effectué pour le miniprojet)

## Vendredi 26 décembre
**Sarah** : 
- ajout de la page d'accueil de notre site (`index.html`) et déploiement du site à l'adresse suivante : https://catastronout.github.io/Projet-de-groupe-PPE1/index.html (`index.html` est basé sur le travail que j'avais effectué pour le miniprojet)
- recherches pour constituer le corpus pour le sens 2 du mot 'autonomie' en bélarussien ('autonomnast') : il existe peu de page Web spécifiquement consacrée à ce concept, j'ai donc choisi de garder cette langue et de rassembler 65 pages Web au lieu de 50, afin que les résultats soient un peu plus significatifs et l'analyse un peu plus pertinente

## Dimanche 28 décembre
**Yeji** :
- Occurrences de mot :
J'ai ajouté un troisième argument FICHIER_MOTS au script. En coréen, le mot "autonomie" se traduit soit par "자율" soit par "자립". J'ai donc créé un fichier autonomie_kr.txt qui contient ces deux traductions (une par ligne). Le script lit ce fichier et compte toutes les occurrences des mots listés dans chaque page.\
- Problèmes de dumps-text :
Quand on récupère le texte brut avec la commande lynx, le résultat s'affiche comme "Copyright ? 2011 ???. All rights reserved." (les caractères coréens sont remplacés par des ?).
Pour régler ce problème d'encodage, j'ai ajouté les options -assume_charset=utf-8 et -display_charset=utf-8 à la commande lynx, ce qui spécifie que l'entrée et la sortie du fichier sont encodées en UTF-8.
- Contexte du mot 'autonomie':
En coréen, le mot "autonomie" est souvent attaché à d'autres mots sans espace. Par exemple, le terme "véhicule autonome" se traduit par "자율주행차", où "자율" (autonome) et "주행차" (véhicule) sont collés sans espace.
J'ai donc utilisé grep avec le pattern (\S+\s*)?mot\S*(\s*\S+)? pour extraire :

Le mot à gauche (avec ou sans espace)
Le mot cible (avec d'éventuels caractères attachés)
Le mot à droite (avec ou sans espace)

Cela permet de capturer aussi bien "자율 주행" (avec espace) que "자율주행차" (sans espace).

## Lundi 29 décembre
**Yeji**:
[1] Tokenisation : Un script make_pals_corpus.sh a été créé afin de tokeniser le corpus coréen avant l’utilisation des scripts PALS.
La tokenisation repose sur trois conditions, définies à l’aide d’expressions régulières :
— [가-힣]+ pour les mots en coréen
— [A-Za-z]+ pour les mots en alphabet latin (anglais)
— [0-9]+ pour les formes numériques
 => Cette étape est nécessaire afin de garantir un format compatible avec les scripts PALS

[2] Cooccurrences
Après avoir créé deux fichiers - contextes-kr.txt et dumps-text-kr.txt - dans le répertoire pals, on a procédé à l’analyse des cooccurrences à l’aide du script cooccurrents.py. Les mots cibles « 자율 » et « 자립 » ont été traités séparément, afin de distinguer leurs champs lexicaux respectifs. Le script a été exécuté avec l’option --match-mode regex, par exemple : 
python3 cooccurrents.py \
  pals/contextes-kr.txt \
  --target "^자율.*" \
  --match-mode regex \
  > pals/cooccurrents_kr_autonomie.txt

Et La même commande a été utilisée pour le mot « 자립 », en modifiant uniquement la valeur de l’option --target.

