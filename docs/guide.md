# md2notes

md2notes convertit le Markdown en texte mis en forme pour Notes et ajoute une ligne vide entre les paragraphes. Il sait également aérer du texte déjà mis en forme.

## Démarrer

Ouvrez **md2notes.app**. Une icône représentant des lignes de texte apparaît dans la barre des menus du Mac. L’application n’a pas de fenêtre principale et n’apparaît pas dans le Dock.

Vous pouvez déplacer md2notes.app dans votre dossier Applications. md2notes ne se lance pas automatiquement au démarrage du Mac.

## Utiliser

1. Copiez une réponse dans ChatGPT, du texte Markdown ou un fichier `.md` depuis le Finder.
2. Cliquez sur l’icône md2notes dans la barre des menus.
3. Une coche confirme que le texte est prêt.
4. Collez dans Notes avec **⌘V**.

Dans Notes, utilisez un dossier du compte iCloud pour retrouver la note sur votre iPhone.

Un **clic droit** sur l’icône permet de **convertir un fichier Markdown…**, de **restaurer le presse-papiers original** ou de **quitter md2notes**. La restauration n’est disponible que tant que vous n’avez pas copié autre chose. Elle agit sur le presse-papiers ; pour annuler un collage déjà effectué dans Notes, utilisez ⌘Z dans Notes.

Pour un fichier `.md` ou `.markdown`, vous pouvez aussi utiliser « Ouvrir avec md2notes » dans le Finder. md2notes lit le fichier sans le modifier et place le texte converti dans le presse-papiers. Les fichiers doivent être encodés en UTF-8 et faire moins de 5 Mo.

## Ce qui est conservé

Le gras, l’italique, les liens, les listes et les tableaux sont conservés pour les contenus HTML/RTF compatibles. Les listes, les cellules de tableau et les blocs de code restent compacts. Les lignes vides déjà présentes ne sont pas doublées.

Le Markdown est détecté automatiquement dans le texte copié, à partir de sa structure : les `#`, `##`, etc. deviennent des titres sans dièses ; `**gras**` et `__gras__` deviennent du gras ; `*italique*` et `_italique_` deviennent de l’italique ; `~~barré~~` devient du texte barré. Les liens directs ou par référence, citations `>`, listes, tableaux et titres soulignés avec `=` ou `-` sont convertis. Les accents graves autour du code disparaissent, mais le contenu du code reste intact. Les listes de tâches utilisent les symboles ☑ et ☐ ; il ne s’agit pas de cases interactives de Notes.

Les marqueurs Markdown ne sont pas supprimés aveuglément : `C#`, les hashtags et les dièses échappés restent présents. Le texte brut sans syntaxe Markdown identifiable est simplement aéré.

md2notes modifie l’espace **entre les paragraphes**, pas l’interligne des lignes qui se replient à l’intérieur d’un paragraphe.

## Limites et confidentialité

- Les images, médias et pièces jointes ne sont pas transformés. Le presse-papiers reste intact en cas de contenu incompatible.
- Si vous copiez un nouveau texte pendant la conversion, cette nouvelle copie est conservée.
- Une conversion réussie remplace le presse-papiers par les versions HTML, RTF et texte brut du résultat ; les formats propres à l’application source sont disponibles via « Restaurer l’original ».
- Le traitement reste sur votre Mac. Aucune donnée n’est envoyée à un serveur, aucun historique n’est enregistré. L’original est conservé temporairement en mémoire pour permettre sa restauration.
- Cette application est signée localement, sans notarisation Apple. Elle est construite pour les Mac Intel sous macOS 13 ou ultérieur et a été testée sur le Mac utilisé pour sa création.

## Validation

Les contrôles couvrent les sauts de paragraphe, la conservation du gras/italique/liens/tableaux dans les sorties HTML et RTF, le code multiligne, les transformations répétées, les changements concurrents et la restauration complète du presse-papiers. Ils vérifient aussi la conversion des titres Markdown, les dièses littéraux et les fichiers `.md` copiés depuis le Finder.

Version 1.2 : conversion Markdown locale avec Marked 18.1.0, bibliothèque fournie dans l’application sous licence MIT. Aucune bibliothèque n’est téléchargée pendant l’utilisation. Les astérisques utilisés comme multiplication et les underscores dans les noms restent présents : seuls les marqueurs Markdown valides sont convertis.

Le rendu visuel du collage dans Notes Mac et de la note synchronisée sur iPhone reste à confirmer. Pour le vérifier, copiez une réponse contenant deux paragraphes, un titre, une liste et un tableau ; transformez-la avec md2notes, puis collez-la dans une nouvelle note iCloud. Les paragraphes doivent être séparés par une ligne vide et le tableau doit rester utilisable.
