---
title: Challenge DGSE/ESIEE - Steganosaurus
date: 2020-11-10 15:59:46+01:00
tags: [writeup, DGSEESIEE, Flutter, Android, Steganography]
image: "/Challenge_DGSE_ESIEE_Steganosaurus/first.png"
---

> <a href="https://www.youtube.com/watch?v=s0rTz2NY3RQ" target="_blank">**Avertissement : vous allez pénétrer dans les arcanes de la DGSE, il vous saurait gré de 
> lire ce WriteUp avec la compilation du service en fond sonore, cliquez ici ou la**</a>

<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/steganosaurus.jpg">
<figcaption>© Nobu Tamura</figcaption>
</figure>

Sacrés agents du *Service Action* ! Ils nous ont dégoté une clé USB abandonnée dans un camion de 
livraison. Elle y contient apparemment les plus sombres secrets de notre ennemie juré : **Evil 
Country**. On nous transmet pour analyse un fichier nommé `message`, représentant le *filesystem* de cette clé. 

Le challenge est classé dans la catégorie Forensic, commençons par passer un petit coup de commande `file`,
et un tour de moulinette avec `binwalk` :

```bash
$ file message
message: DOS/MBR boot sector, code offset 0x58+2, OEM-ID "mkfs.fat", Media descriptor 0xf8, sectors/track 32, heads 64, hidden sectors 7256064, sectors 266240 (volumes > 32 MB), FAT (32 bit), sectors/FAT 2048, reserved 0x1, serial number 0xccd8d7cd, unlabeled
$ binwalk -e message
DECIMAL       HEXADECIMAL     DESCRIPTION                                                                                                                       
--------------------------------------------------------------------------------                                                                                
2114048       0x204200        PNG image, 1000 x 514, 8-bit/color RGBA, non-interlaced                                                                           
3061760       0x2EB800        Zip archive data, at least v2.0 to extract, compressed size: 318, uncompressed size: 442, name: kotlin/ranges/UIntProgressionItera
tor.kotlin_metadata                                                                                                                                             
3085941       0x2F1675        Zip archive data, at least v2.0 to extract, compressed size: 459, uncompressed size: 725, name: kotlin/collections/HashMap.kotlin_
metadata                                                                                                                                                        
3086472       0x2F1888        Zip archive data, at least v2.0 to extract, compressed size: 255, uncompressed size: 320, name: kotlin/SuspendKt.kotlin_metadata  
3086789       0x2F19C5
--- 3< snip ---
```

Effectivement, `file` reconnait un système de fichier FAT32, `binwalk` quant a lui va passer au
peigne fin chaque octet du fichier pour essayer de trouver des en-têtes de format de fichier connus. Ainsi il
trouve un fichier PNG d'une résolution de 100x514, des archives Zip etc... L'option **-e** permet
d'extraire automatiquement ce qu'il trouve.

Gardons les résultats de `binwalk` pour plus tard, et essayons de monter le fichier pour 
accéder à cette *partition* FAT32 :

```bash
$ sudo mount message mnt/
$ ls -l mnt/
total 37327
-rwxr-xr-x 1 root root      532 Oct 15 17:48 readme
-rwxr-xr-x 1 root root 38221331 Jul  8 16:02 steganausorus.apk
```

Deux fichiers sont présents, dont un possédant l'extension en .apk, qui nous fait penser
naturellement au format *Android Application Package*. l'APK est un paquet
au format Zip servant de conteneur pour une application Android. Regardons le `readme`, et
parce que ça ne mange pas de pain un petit coup de `file` sur l'APK pour s'assurer du format :

```
$ cat readme
Bonjour evilcollegue !
Je te laisse ici une note d'avancement sur mes travaux !
J'ai réussi à implémenter complétement l'algorithme que j'avais présenté au QG au sein d'une application.
Je te joins également discrétement mes premiers résultats avec de vraies données sensibles ! Ils sont bons pour la corbeille mais ça n'est que le début !
Je t'avertis, l'application souffre d'un serieux defaut de performance ! je m'en occuperai plus tard.
contente-toi de valider les résultats.
Merci d'avance

For the worst,

QASKAB

$ file steganosaurus.apk
steganausorus.apk: Zip archive data, at least v2.0 to extract
```

D'après le `readme` il fleure bon que l'on va devoir analyser un algorithme contenu dans
une application. De plus la commande `file` reconnait une archive Zip. On est quasiment certain d'être
en présence d'une application Android, regardons sans plus attendre son contenu :

```bash
$ unzip -l steganosaurus.apk
Archive:  steganausorus.apk                                                                                                                                     
  Length      Date    Time    Name                                                                                                                              
---------  ---------- -----   ----                                                                                                                              
     4224  1980-00-00 00:00   AndroidManifest.xml                                                                                                               
     1159  1980-00-00 00:00   META-INF/CERT.RSA                                                                                                                 
    34878  1980-00-00 00:00   META-INF/CERT.SF                                                                                                                  
    34835  1980-00-00 00:00   META-INF/MANIFEST.MF                                                                                                              
        6  1980-00-00 00:00   META-INF/androidx.activity_activity.version                                                                                       
        6  1980-00-00 00:00   META-INF/androidx.arch.core_core-runtime.version                                                                                  
        6  1980-00-00 00:00   META-INF/androidx.core_core.version                                                                                               
        6  1980-00-00 00:00   META-INF/androidx.customview_customview.version                                                                                   
        6  1980-00-00 00:00   META-INF/androidx.fragment_fragment.version                                                                                       
        6  1980-00-00 00:00   META-INF/androidx.lifecycle_lifecycle-livedata-core.version                                                                       
        6  1980-00-00 00:00   META-INF/androidx.lifecycle_lifecycle-livedata.version                                                                            
        6  1980-00-00 00:00   META-INF/androidx.lifecycle_lifecycle-runtime.version                                                                             
        6  1980-00-00 00:00   META-INF/androidx.lifecycle_lifecycle-viewmodel.version  
--- 3< snip ---
```

`AndroidManifest.xml`... c'est manifestement une application Android ! Pour naviguer et
décompiler le contenu de ce paquet APK, nous utiliserons l'outil
[Jadx](https://github.com/skylot/jadx) *Dex to Java decompiler* :

```
$ jadx-gui steganosaurus.apk
```

Une fois dans Jadx avec le fichier `steganosaurus.apk` chargé, nous cliquons sur le
fichier `Resources/AndroidManifest.xml` qui est l'un des plus importants d'une application
Android. En effet ce fichier est obligatoire et contient les informations générales au bon
fonctionnement de cette dernière. C'est un excellent point de départ pour faire
connaissance avec `steganausorus`.

L'application requière l'accès à 3 ressources :

- écriture sur un stockage externe (carte sd...)
- lecture sur un stockage externe (carte sd...)
- Accès Internet

<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/manifest_permissions.png" alt="">
<figcaption>Permissions demandées par l'application</figcaption>
</figure>

La balise `<application>` et ses attributs nous renseigne sur l'application elle
même, comme son nom qui est `stegapp` dans `android:label` et surtout son point d'entrée
dans le code par `android:name=io.flutter.app.FlutterApplication`, précisant qu'elle est la
première classe à appeler.

<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/android_manifest2.png" alt="">
<figcaption>Balise &lt;application&gt;</figcaption>
</figure>

Cette classe n'est d'ailleurs pas écrite par l'auteur de l'application, mais elle correspond au kit de
développement [Flutter](http://flutter.dev), l'analyser serait une perte de temps. 

>Flutter a été créé par Google et met à disposition tout un tas de classes pour développer des
>interfaces graphiques mutliplateforme sur la base d'un seul langage le
>[Dart](http://dart.dev). Le Dart quant à lui est un langage de programmation orienté objet
>se rapprochant syntaxiquement du C, il génère principalement du code natif.

Le code écrit par l'un des membres d'**Evil Country** se situe surement dans l'application
*Flutter/Dart* elle même. Il va nous falloir trouver un moyen le récupérer et de la
décompiler, car malheureusement Jadx comprend que le format .dex *Dalvik Executable
Format*.

Heureusement, nous avons une des plus impressionnante compétence d'un cétéfeur (un gars
qui fait des CTF), celle de pouvoir diagonaliser l'intégralité d'une doc d'un gros SDK en
un temps record et le don sacré dans la composition de bons mots-clés pour *sniper* la
ressource nécessaire, c'est à dire celle-ci : 
[Reverse Engineering Flutter Apps](https://medium.com/@rondalal54/reverse-engineering-flutter-apps-5d620bb105c0)
:

<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/flutter_blog.png" alt="">
<figcaption></figcaption>
</figure>

- "Pardon Monsieur? Si l'application est restée en mode debug on peut récupérer le code
source avec en bonus les commentaires dans le fichier `kernel_blob.bin` de l'apk ?"
- "Oui Madame!"
- "Pôpôpôôôô!"

<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/kernel_blog_jadx.png" alt="">
<figcaption></figcaption>
</figure>

*Target* localisée ! Pour extraire le fichier il suffit d'ouvrir le paquet APK dans 7Zip par
exemple, ou tout simplement de le dézipper. Le contenu est censé être du bytecode + peut-être le code en clair,
voyons ce que nous trouve la commande `strings` :

```go
$ strings -10 kernel_blob.bin
--- 3< snip ---
<org-dartlang-sdk:///third_party/dart/sdk/lib/_http/http.dart
'       // Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
// @dart = 2.6
library dart._http;
import 'dart:async';
import 'dart:collection'
        HashMap,
        HashSet,
        Queue,
        ListQueue,
        LinkedList,
        LinkedListEntry,
        UnmodifiableMapView;
import 'dart:convert';
--- 3< snip ---
```

Well Done **Evil Country**! Qu'est ce c'est beau et tellement rare d'avoir un code lisible et indenté depuis la sortie
de la commande `strings`, un moment rare, restons quelques minutes à contempler...

Comme nous sommes des pros de la DGSE, on va extraire proprement le code lisible du byte code, pour
avoir une belle base de travail. En regardant un peu le code on s'aperçoit qu'il contient un paquet
de lignes, et qu'elles correspondent au code du SDK Flutter. Il nous faut trouver et isoler le
code du fameux *QASKAB*. Il doit bien y avoir un point d'entrée matérialisé par une fonction 
ou un truc du genre... Concentration... Diagonalisation... Following the white rabbit... 
Et Bim [ici](https://dart.dev/guides/language/language-tour#the-main-function). Oui un pauvre `main()`,
manque total d'originalité de la part du Dart.

On tapote frénétiquement sur `n` dans `Vim` avec le pattern mal choisi `main()`. Il nous faut 
tomber sur le bon. Pour cela on remarque en amont de chaque `main()` une en-tête de
début de fichier Dart, avec le chemin vers celui-ci émanant de la machine du développeur. Il devient
facile de faire le *distinguo* entre un `main()` perdu de la bibliothèque Flutter et celui-là
par exemple :

<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/code_main.png" alt="">
<figcaption></figcaption>
</figure>

Extrayons ce fichier. Pour cela nous utilisons ici une recette ultra sophistiquée :
- `vim kernel_blog.bin`
- `530089GV530380Gy` *(on respecte la casse hein)*
- `:e le_code.dart`
- `p:wq`

>C'est une [recette](https://www.vimgolf.com/) de chef, comprendra qui pourra. Sinon on peut le faire
>à la souris, mais ça va mal passer à la *Piscine* car c'est les ptis gars du 
>[GCHQ](https://fr.wikipedia.org/wiki/Government_Communications_Headquarters) qui font ça.

On a beau être en couple avec `Vim` depuis longtemps, mais quand il s'agit d'analyser et surtout
de naviguer efficacement dans du code inconnu, rien ne vaut la souris (*"tu viens pas de dire que 
c'est au GCHQ qu'on fait ça?" "non mais ça c'était dans l'autre paragraphe"*), pour cela 
voici plusieurs armes suivant les caractéristiques du soldat :
- `VsCode` si t'as pas de barbe 
- `VsCodium` barbe naissante 
- `Emacs` barbe de classe [Stallman](https://en.wikipedia.org/wiki/Richard_Stallman)

 >ces 3 éditeurs de code / IDE ont pour point commun d'avoir une extension Vim, (voir même 
 [Evil](https://www.emacswiki.org/emacs/Evil)... Country?!)
 >ouf l'honneur du Service est sauf.

N'oubliez pas d'installer les extensions qui vont bien : Flutter et Dart. Ouvrez votre
code, et la c'est noël à Disney Land, de la couleur partout :

<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/vscode.png" alt="">
<figcaption></figcaption>
</figure>

L'intérêt de VsCode ici, c'est qu'il va nous permettre d'avoir rapidement la doc juste en passant
la souris sur les classes de bibliothèque, et de faire ressortir les variables dans tout 
le code quand on place le curseur sur l'une d'elle (matérialisé par un encadré de couleur rose...)

Bien que le langage Dart nous est inconnu au Service, il est assez facile à comprendre. De
toutes les manières on a pas le temps d'apprendre a coder en Dart, en plus si vous avez vu la série 
*Le Bureau Des Légendes*, vous êtes au courant que l'on est à peine deux au *service informatique*, il y a [lui](https://www.leparisien.fr/resizer/ru0O3UwrS_7vlpGd6T29I1kDoxc=/932x582/cloudfront-eu-central-1.images.arcpublishing.com/leparisien/32V524TJKF3ZIK3RLZSJJJCSAY.jpg) et moi.

Visiblement cette application bidouille une image en entrée pour en ressortir une autre. Avant d'aller plus loin, allons
voir a quoi ressemble cette APK en l'exécutant sur notre [téléphone](https://fr.wikipedia.org/wiki/Teorem) de service... 
Ah bah non... on ne peut toujours pas installer d'application (ni même Candy Crush...) cette mise à jour n'arrivera donc
jamais ! Rabattons nous sur un [émulateur](https://developer.android.com/studio). 

Une fois notre téléphone allumé, il nous reste plus qu'a pousser l'application sur ce
dernier :
```bash
$ adb devices
List of devices attached
emulator-5554   device
$ adb push steganausorus.apk /sdcard/Download/
steganausorus.apk: 1 file...MB/s (38221331 bytes in 0.350s)
```

On paramètre le téléphone pour installer des applications non vérifiées, puis on tapote dé-li-ca-te-ment sur
`Stegapp` :

<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/android_emulator.png" alt="">
<figcaption></figcaption>
</figure>

Un message secret à cacher dans une image... un nom évocateur... nous sommes
très probablement sur une application de stéganographie (quel falair!). On test avec une belle image
de Labrador pour voir le résultat... Punaise ça rame ! En effet le machin souffre d'un
**serieux** problème de performance (on a été prévenu), ça va être râpé pour l'analyse dynamique... 

> Dans VsCode par exemple il possible (avec les extensions) de créer une nouvelle
> application Flutter, coller le code que l'on a extrait, puis de faire une analyse dynamique
> en mode live debug.

Maintenant que l'on y voit un peu plus clair, il n'y
a plus qu'a lire la documentation qui nous est fournie (le code quoi). Un tapotage sur le bouton
*Start Hide & seek game* fait quelques vérifications et appelle la fonction `steggapp` avec
pour paramètres le chemin vers l'image `_image`, et le texte à dissimuler `myController.text`:

<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/start_steggapp.png" alt="">
<figcaption>dans la fonction Build()</figcaption>
</figure>

Chaque caractère du message à dissimuler va être transformé en binaire sous forme d'une
chaîne de caractère ASCII de type `String` à l'aide de la fonction `MessageToBinaryString()` (si
c'est pas explicite ça). Un caractère occupera systématiquement 8 bits, si il fait moins on
le *GaucheCapitonne(padLeft)* avec des 0.
Par exemple, `BOB` donnera `01000010 01001111 01000010` (sans espace) :

```dart
String MessageToBinaryString(String pMessage){
    String Result;
    Result="";
    List<int> bytes = utf8.encode(pMessage);
    bytes.forEach((item) { Result+=item.toRadixString(2).padLeft(8,'0');});
    return Result;
  }
```

Le résultat de la fonction est stocké dans `binaryStringmessage` :
```dart
binaryStringmessage = MessageToBinaryString(pMessage);
```
L'image est ensuite lue et convertie au format RGBA puis redimensionnée de sorte que
l'image ai une largeur de 1000 pixels. Cette première constante est très importante, car
l'image finale embarquant le message fera systématiquement 1000 pixels de large. C'est un
indicateur fort. D'autre part,
ces 1000px ne nous rappelle pas quelque chose? Il disait quoi déjà le `binwalk` du début ?

```dart
A.Image aimage =A.Image.fromBytes(decodedImage.width,decodedImage.height, imgintlist, format: A.Format.rgba);
A.Image resisedimage=A.copyResize(aimage,width:1000);
```

Un petit rappel sur le format RGBA32 (ou en français RVBA pour Rouge Vert Bleu Alpha) ne
va pas faire de mal pour comprendre ce qui va suivre. Un pixel de notre image
est un savant mélange d'intensité de rouge, de vert et de bleu (rappelez vous les trucs 
moches que vous faisiez en Art Plastique). On parle de canal pour chaque couleur, du coup
nous avons 3 canaux Rouge Vert Bleu, plus 1 autre appelé Alpha qui se rapporte à l'intensité de transparence de l'image.
Comme nous sommes dans un format RGBA**32** pour 32bits(4 octets ), il faut qu'un unique pixel tienne dans.... 32 bits !
On a 4 canaux à faire entrer là-dedans, et pour éviter les disputes on fait un partage équitable, 
32bits/4 canaux = 8 bits. Bon voilà, chacun pourra prendre une valeur codée sur 8 bits, 
c'est à dire de 0 à 255 en notation décimale.

<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/rgba.png" alt="">
<figcaption></figcaption>
</figure>

Il faut aussi respecter l'ordre de lecture du format RGBA32 :

<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/rgbabits.png" alt="">
</figure>

Revenons à notre image redimensionnée stockée dans `resisedimage`, l'application va
parcourir cette image - donc un tableau de 32bits (= 1 pixel) - puis transformer cette valeur en binaire
sous forme d'une chaîne de caractère. Un petit problème se pose pendant la conversion en 
binaire avec `toRadixString`, en effet l'ordre des canaux vont être inversés, on se retrouve
avec du ABGR. On ne rentrera pas dans les détails, c'est une sombre histoire de [Boutisme](https://fr.wikipedia.org/wiki/Boutisme) 
(pas la religion hein). Pour contrer ce problème on remet dans l'ordre les canaux puis on concatène
tous les pixels dans une MEGA chaîne de caractère `MegaString`. Remarque importante,
avec le premier `substring(8)` on ignore complètement le canal Alpha.

```dart
MegaString="";
for (int i = 0;i < resisedimage.length;i++){
  RRGGBBString=resisedimage[i].toRadixString(2).padLeft(32, '0').substring(8); // ByeBye l'Alpha
  PixelString=RRGGBBString.substring(16,24)+ // Rouge
              RRGGBBString.substring(8,16)+  // Vert
              RRGGBBString.substring(0,8);   // Bleu
  MegaString+=PixelString;
}
```

Les choses sérieuses commencent, une boucle `while` va mouliner tant que l'on a pas traiter
tous les chiffres binaires de la chaîne `binaryStringmessage` :

```dart
while(messaggelength < binaryStringmessage.length ) {
```

Juste avant cette boucle une nouvelle variable `Megastringtosearch` est initialisée avec
pour valeur le contenu de `MegaString` tronqué de ses N premiers bits. Où N = taille de MegaString / 4:

```dart
String Megastringtosearch= MegaString.substring((MegaString.length/4).round());
```

`Megastringtosearch` va être notre dictionnaire pour coder notre message (`binaryStringmessage`).
Dans le `while` précédent, une nouvelle boucle est créée. C'est une boucle de recherche.
Elle va essayé de déterminer la plus grande suite de bits possibles d'un seul bloc correspondant
à notre message secret. La recherche se fait dans `Megastringtosearch`. On note la position `offset`
et la longueur `lengthtostore` de notre trouvaille :

```dart
// offsettostore != -1, tant que indexOf trouve une suite
// substringtoFind.length<=messagetohide.length-1, tant qu'on ne dépasse pas notre message
while(offsettostore !=-1 && substringtoFind.length<=messagetohide.length-1){
  lengthtostore = substringtoFind.length; // on stocke la taille depuis la pos dans Megastringtosearch
  offset = offsettostore; // on stocke la position dans Megastringtosearch
  // tant qu'on trouve on ajoute un nouveau bit à la recherche
  substringtoFind = messagetohide.substring(0, substringtoFind.length + 1);
  // notre chaîne de bits est trouvable dans Megastrintosearch, sinon indexOf retourne -A
  offsettostore = Megastringtosearch.indexOf(substringtoFind);
}
```

Toujours dans notre première boucle, un test est réalisé pour évaluer si l'on a trouvé 
l'intégralité de notre message dans les données de l'image. Si c'est le cas
on stoppe la première boucle, sinon on
continue à chercher un nouveau morceau restant de notre message sous forme de bits. Pour chaque
bloc trouvé, on stocke la paire de valeurs [`offset`, `lenghtostore`] dans le tableau
`offsetarray`:

```dart
// Tout trouvé ?
if(substringtoFind.length == messagetohide.length  ){
  int lastoffsettostore=Megastringtosearch.indexOf(substringtoFind);
  // ça dépasse un peu?
  if(lastoffsettostore==-1){
    // on stocke les résultats dans offsetarray + le bit qui dépasse
    offsetarray.add([offset, lengthtostore]); 
    offsetarray.add([Megastringtosearch.indexOf(substringtoFind[-1]),1]);
  }
  // ça dépasse pas:
  else{
    offsetarray.add([Megastringtosearch.indexOf(substringtoFind),substringtoFind.length]);
    var lastitem=offsetarray.last;      }
  //
  messaggelength+=substringtoFind.length;
}
// on a trouvé qu'un bloc
else {
  // on retire le bloc trouvé
  messagetohide = messagetohide.substring(substringtoFind.length - 1);
  messaggelength += substringtoFind.length;
  // on stocke le résultat
  offsetarray.add([offset, lengthtostore]);
  offsettostore = 0;
  lengthtostore = 1;
  offset = 0;
  // on recommence à trouver un nouveau bloc
  substringtoFind = messagetohide.substring(0, 1);
}
```

Bon on récapitule un peu, on a dans l'ordre : 
- notre message secret est transformé en binaire sous forme ASCII `101010100...` 
- on fait de même avec les pixels de l'image `10101011...`
- on fait une table de recherche avec les données de cette image moins les 25% du début
- on essaye de trouver une suite identique dans notre message et dans la table
- on stocke la position de cette suite sous forme [position,longueur] dans `offsetarray`
- on fait cette recherche pour l'intégralité de notre message

`offsetarray` devient le précieux résultat permettant de retrouver le message secret
à l'aide de la position|longueur. Il faut donc pouvoir stocker ce tableau dans l'image. C'est
justement l'étape qui suit.

Pour cela une nouvelle variable de type `String` fait son apparition : `stringtowrite`.
Comme son nom l'indique (merci **Evil Country**) elle va contenir notre tableau d'offset
qui sera écrit au tout début de l'image. Voilà à quoi va ressembler ce début d'image :

<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/header.png" alt="">
<figcaption></figcaption>
</figure>

et son code :

```dart
int offsetdatasize = resisedimage.length * 8 * 3;
int lenghtdatasize = binaryStringmessage.length;
int lenghtsizebit = lenghtdatasize.toRadixString(2).length;
int datasizebit = offsetdatasize.toRadixString(2).length;
String stringtowrite = "";
// taille de offsetarray + lenghtdatasize
stringtowrite += offsetarray.length.toRadixString(2).padLeft(datasizebit, '0') +
                  lenghtsizebit.toRadixString(2).padLeft(datasizebit, '0');

// on ajoute toutes les paires [offset,longueur] 
offsetarray.forEach((listofdata) {
  stringtowrite += listofdata[0].toRadixString(2).padLeft(datasizebit, '0') +
                    listofdata[1].toRadixString(2).padLeft(lenghtsizebit, '0');
});
```

`dataSizeBit` correspond au nombre de bits contenus dans la valeur calculée `resised.length * 8 * 3`.
Comme son nom l'indique, elle va nous renseigner sur la taille d'une donnée de l'en-tête, ou 
d'un bloc du schéma précédent si l'on préfère. A chaque fois que l'on voudra extraire 
un message secret d'**Evil Country** il nous faudra faire le calcul ci-dessus pour déterminer
comment lire l'en-tête. Note importante,
dans le code Dart `length` retourne le nombre de pixels (RGBA), la taille n'est donc pas en octet,
mais un multiple de 4 octets. Pour avoir la taille en octet il suffit de diviser
par 4 : `Length/4`. 

- Le premier bloc de notre en-tête contient le nombre de paires [offset,longueur] à lire.
- Le deuxième bloc contient la variable `lengthsizebite` déterminée en comptant le nombre
de bits contenus dans le message secret. Elle indique la dimension d'un 
bloc *longueur* qui eux n'ont pas la taille `dataSizeBit`.
- le reste des blocs correspondent aux paires à lire suivant le nombre récupéré dans le 
premier point.

Voilà ! Avec ces informations on peut déjà coder notre propre décodeur ! Mais... encore
faut-il avoir une image à décoder !?  Une image qui d'après notre analyse fait 1000 pixels
de largeur, et qui en plus devrait avoir des pixels étranges en son début...

Vous vous souvenez du petit coup de `binwalk` en début de page ? Il nous avait pas 
trouvé justement un PNG de 1000 x 514, 8-bits/color RGBA ? Alors ? Bon bah je vais vous
le dire alors, oui on a un PNG planqué qui a du être normalement extrait si vous avez
bien utilisé l'option -e de `binwalk`. Allons voir ça de plus près :

```dart
$ file _message.extracted/204200 
message.extracted/204200: PNG image data, 1000 x 514, 8-bit/color RGBA, non-interlaced
$ eog _message.extracted/204200
```
<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/thepng.png" alt="">
<figcaption></figcaption>
</figure>

Oh la belle image! Les petites barres veulent surement dire quelque chose, comptons les.... **NON**.
Tiens... Il y a des pixels étranges dans le coin supérieur gauche :
<figure>
<img src="/assets/img/Challenge_DGSE_ESIEE_Steganosaurus/strangepixels.png" alt="">
<figcaption></figcaption>
</figure>

Cette image a l'air de contenir un grand secret injecté par l'algorithme que l'on a
analysé plus haut. Réalisons le décodeur. Pour changer du Python on va le faire
en GoLang... En fait pour ne rien vous cacher, on a pas vraiment le choix, les gars du Service Action
sont tous des militaires endurcis, il suffit de dire "[NoGo](https://en.wikipedia.org/wiki/No-go_pill)" 
pour les mettre en pétard, du coup on s'est mis au Go, on est plus serein.

Commençons par faire une petite fonction qui prend en entrée un fichier et nous retourne
une image RGBA :
```golang
func readFileToImgRGBA(f *os.File) (*image.RGBA, error) {
	srcimg, err := png.Decode(f)
	if err != nil {
		return nil, fmt.Errorf("readImgInRGBA: %w", err)
	}
	// on récupère les paramètres de notre image
	bounds := srcimg.Bounds()
	// on crée une image vide avec le format RGBA et les paramètres de notre image
	img := image.NewRGBA(bounds)
	// on copie notre image, en bref on vient de la convertir en RGBA comme dans l'application
	draw.Draw(img, bounds, srcimg, image.Point{0, 0}, draw.Src)
	return img, nil
}
```

Pour ceux qui ne connaissent pas trop le Go, l'opérateur `:=` permet de faire de l'inférence 
de type (il a dit quoi la ?). En gros on se casse pas la tête à choisir un type, on laisse
le compilateur choisir, comme avec `auto` en C++.

On se fait plaisir et on fait une autre petite fonction qui prend en entrée un tableau
d'octets. Elle va nous mouliner tout ça pour en sortir une chaîne de caractère binaire. Plutôt 
utile n'est-ce pas !

```golang
// convertToBitsString convertit chaque octet en chiffre
// binaire sous forme ASCII. Il capitonne de 0 par la gauche
// si le nombre de caractère est inférieur à 8 (bits)
func convertToBitsString(data []byte) *string {
	var build strings.Builder // strings.Builder car performant
	for _, b := range data {
		fmt.Fprintf(&build, "%08b", b) // on convertit + capitonnage
	}
	strbuild := build.String() // on transforme en  string
	return &strbuild
}
```

Vous vous rappelez que l'on n'utilise pas le canal Alpha de l'image pour construire 
le dictionnaire `Megastringtosearch` tronqué depuis `MegaString`. Il nous faut une fonction
pour filtrer ça:  `imgToRGB`  prend une image en RGBA pour retourner un tableau d'octet 
en RGB _sans A_:

```golang
func imgToRGB(img *image.RGBA) (res []byte) {
  Y := img.Bounds().Max.Y
  X := img.Bounds().Max.X
  for y := 0; y < Y; y++ {
    for x := 0; x < X; x++ {
      r := img.RGBAAt(x, y).R
      g := img.RGBAAt(x, y).G
      b := img.RGBAAt(x, y).B
      res = append(res, r, g, b)
    }
  }
  return
}
```
Et pour finir voici la fonction principale, qui est non optimisée mais qui réutilise les
même nom de variable et la même structure que dans le code Dart :

```golang
func decode(imgRGBA *image.RGBA) (flag string) {
	// on supprime le canal Alpha, RGBA => tableau octet format RGB
	imgbytes := imgToRGB(imgRGBA)
	// on calcul la taille de l'image RGBA en mémoire
	imgOrigSize := imgRGBA.Bounds().Max.X * imgRGBA.Bounds().Max.Y * 4

	// on calcule la taille dataSizeBit
	imgPixelLength := imgOrigSize / 4 // ouais c'est pour la lisibilité le /4
	offsetDataSize := imgPixelLength * 8 * 3
	dataSizeBit := len(fmt.Sprintf("%b", offsetDataSize))

	// on convertit les octets de l'image en binaire ASCII
	megaString := *(convertToBitsString(imgbytes))

	// on tronque le début de megaString
	megaStringLen := len(megaString) / 4
	megaOffset := int64(math.Round(float64(megaStringLen)))
	megaStringToSearch := megaString[megaOffset:] // notre dictionnaire

	// strconv.ParseUint("10101011", base 2, nombre de bits à lire) = valeur en UINT
	arraySize, _ := strconv.ParseUint(megaString[0:dataSizeBit], 2, dataSizeBit)
	megaString = megaString[dataSizeBit:]

	lengthSizeBit64, _ := strconv.ParseUint(megaString[0:dataSizeBit], 2, dataSizeBit)
	lengthSizeBit := int(lengthSizeBit64)
	megaString = megaString[dataSizeBit:]

	msgDecoded := ""
	for i := uint64(0); i < arraySize; i++ {
		offset, _ := strconv.ParseUint(megaString[0:dataSizeBit], 2, dataSizeBit) // offset N
		megaString = megaString[dataSizeBit:]
		length, _ := strconv.ParseUint(megaString[0:lengthSizeBit], 2, lengthSizeBit) // longueur N
		megaString = megaString[lengthSizeBit:]
		msgDecoded += megaStringToSearch[offset : offset+length] // notre message décodé mais sous forme binaire
	}

	// transformation du binaire => ASCII
	for i := 0; i < len(msgDecoded); i += 8 {
		val, _ := strconv.ParseUint(msgDecoded[i:i+8], 2, 8)
		flag += fmt.Sprintf("%c", val)
	}

	return flag
}
```

Verdict :

```bash
$ go run decoder.go _message.extracted/204200 
le message secret: DGSEESIEE{FL****R3}
```
**FIN BRUTALE**

- [le_code.dart](/assets/files/le_code.dart)
- [decoder.go](/assets/files/decoder.go)
- [message](https://mega.nz/file/boQyCRZb#y6V-0ec5OSaMkJJHwkksvi1Hpa6nUEh-QbqS4Yo-j3Y)


