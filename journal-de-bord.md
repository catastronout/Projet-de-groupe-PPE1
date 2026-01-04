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

## 30 décembre

**Sarah** : Aujourd’hui, j’ai repris le script principal (main) pour y intégrer plusieurs fonctionnalités qu’on avait dans main_kr.sh. Ça m’a pris un moment parce qu’il fallait tout fusionner proprement, sans redondances, pour que tout tourne bien peu importe la langue.

Pour le bélarussien, j’ai fusionné les deux fichiers texte (les deux sens du mot) en un seul tableau avec deux colonnes d’occurrences, une pour chaque sens. C’est plus clair comme ça, on voit direct les différences.

J’ai aussi ajouté une liste de mots spécifiques au bélarussien pour repérer les occurrences dans le corpus. Et j’ai intégré un mode verbose/debug, super pratique pour suivre ce que fait le script et comprendre où ça plante. J’ai aussi un peu bossé sur la lisibilité : noms de colonnes plus clairs et liens cliquables dans les tableaux pour checker les sources plus vite.

## 31 décembre

**Sarah** : J’ai continué le script en bossant surtout sur le mode verbose. Je l’ai amélioré pour qu’il affiche l’encodage des fichiers traités, parce qu’on a eu pas mal de soucis avec des pages en Windows-1251 qui passaient mal en UTF-8, donc perte de données.

Maintenant, pour chaque URL, le script affiche le charset des headers HTTP, l’encodage détecté (avec file), et il balance un message clair quand y a un souci d’encodage. Grâce à ça, j’ai mieux capté pourquoi certaines pages posaient problème et j’ai pu documenter les cas à traiter à la main.

## 1e janvier

**Sarah** : J’ai bossé sur la génération du concordancier. J’ai ajouté des vérifs automatiques : combien de fichiers sont traités, si les motifs sont bien trouvés, etc. Ça évite d’avoir un résultat tout pété ou incomplet.

J’en ai profité pour nettoyer un peu le code, virer des doublons qui traînaient depuis plusieurs itérations, et solidifier le tout. Niveau affichage, j’ai standardisé le style des concordanciers avec Bulma, pour que ça soit propre et uniforme entre toutes les langues.

## 2 janvier

**Sarah** : Journée un peu galère. Surtout des bugs avec le corpus coréen : certaines occurrences étaient plus détectées correctement. En plus, des blocs intermédiaires plantaient parfois.

Après pas mal de tests et d’essais, Yeji a réussi à trouver et corriger le souci. Une fois que c’était réglé, j’ai relancé toute la chaîne : make_pals, extraction des cooccurrents, partition du corpus, etc. Bref, beaucoup d’ajustements, de relances et de mini-fixes pour que tout tourne bien.


## 3-4 janvier

**Sarah** : Je me suis concentrée sur le site web du projet, surtout sur la page d’analyse du bélarussien. J’ai posé les bases du design général : typographie, couleurs, grilles, pour que toutes les pages aient une cohérence visuelle et que ça ne donne pas un effet brouillon entre les langues.

Ensuite, j’ai intégré les résultats du pipeline sur la page bélarussienne : tableaux, nuages de mots, et les premiers commentaires d’analyse. J’ai fait en sorte que la structure de la page suive la logique de l’analyse, avec d’abord les données, ensuite les visualisations, puis l’interprétation, tout en gardant l’ensemble clair et agréable à lire.

Le lendemain, j’ai repris le texte analytique pour qu’il soit bien aligné avec les résultats obtenus, que ce soit sur les cooccurrences, les spécificités lexicales ou les nuages. J’ai fait attention à rester rigoureuse dans les interprétations, surtout pour les nuages de mots, histoire d’éviter les surinterprétations.

J’ai terminé par une série de tests pour vérifier la navigation et l’affichage des différents éléments : liens, images, tableaux, graphiques. Tout semble bien en place, la page tient la route, et le projet commence vraiment à prendre sa forme finale.