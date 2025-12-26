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