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

