# md2notes

Une petite application Mac pour convertir le Markdown du presse-papiers en texte mis en forme, prêt à coller dans Apple Notes.

Utile pour copier-coller les réponses de **ChatGPT, Claude et d’autres IA** dans Apple Notes, en conservant la mise en forme et des espaces entre les paragraphes.

**Copier → cliquer sur md2notes dans la barre des menus → coller avec ⌘V.**

## Fonctionnalités

- Conversion des titres `#`, du gras `**`/`__`, de l’italique `*`/`_`, du texte barré `~~`, des liens, citations, listes et tableaux.
- Ajout d’une vraie ligne vide entre les paragraphes, sans doubler les espacements existants.
- Conservation du contenu des blocs de code et des caractères littéraux.
- Lecture des fichiers `.md` ou `.markdown` copiés depuis le Finder, ouverts avec l’application ou choisis dans son menu.
- Restauration du presse-papiers original par clic droit, jusqu’à la prochaine copie.
- Traitement local, sans serveur et sans historique enregistré.

Version actuelle : **1.2**. Les fichiers Markdown doivent être en UTF-8 et faire moins de 5 Mo. Les images et pièces jointes ne sont pas converties. Le rendu visuel dans Notes Mac/iPhone reste à confirmer ; les contrôles automatisés vérifient les sorties HTML/RTF et le presse-papiers.

## Construire et tester

Requiert macOS 13 ou ultérieur et les outils de compilation Swift/Xcode. L’application actuelle cible les **Mac Intel**. Les dépendances nécessaires à l’exécution sont incluses dans le dépôt.

```sh
zsh scripts/build.sh
open build/md2notes.app
```

La construction signe l’application localement, vérifie la signature et exécute les tests. Aucun certificat de développeur n’est nécessaire pour cet usage local. L’application n’est pas notarisée.

Pour créer l’archive distribuable :

```sh
ditto -c -k --sequesterRsrc --keepParent build/md2notes.app build/md2notes-macOS.zip
```

Pour relancer uniquement les tests :

```sh
build/md2notes.app/Contents/MacOS/md2notes --self-test
```

## Organisation

- `src/` : application native, presse-papiers et détection Markdown.
- `resources/` : description de l’application et transformation HTML.
- `tests/` : contrôles automatisés et exemple Markdown.
- `vendor/marked/` : parseur Markdown fourni localement et sa licence MIT.
- `scripts/` : construction reproductible.
- `docs/guide.md` : guide d’utilisation.

Les tests utilisent un presse-papiers isolé pour les opérations d’écriture et de restauration. Ils peuvent également lire le presse-papiers réel pour un contrôle de conversion, sans le modifier ni afficher son contenu.

Consultez [le guide d’utilisation](docs/guide.md) pour les détails et limites.
