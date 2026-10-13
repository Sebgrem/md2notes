# md2notes

A small Mac app that converts Markdown from your clipboard into formatted text, ready to paste into Apple Notes.

Useful for copying and pasting responses from **ChatGPT, Claude, and other AI assistants** into Apple Notes while keeping formatting and readable spacing between paragraphs.

**Copy → click md2notes in the menu bar → paste with ⌘V.**

## Features

- Converts headings `#`, bold `**`/`__`, italics `*`/`_`, strikethrough `~~`, links, blockquotes, lists, and tables.
- Adds a real blank line between paragraphs without duplicating existing spacing.
- Preserves code block contents and literal characters.
- Opens automatically at login (set on first launch, toggle from the right-click menu).
- Reads `.md` or `.markdown` files copied from Finder, opened with the app, or selected through its menu.
- Restores the original clipboard through the right-click menu until you copy something else.
- Processes everything locally, with no server and no saved clipboard history.

Current version: **1.3**. Markdown files must use UTF-8 encoding and be no larger than 5 MB. Images and attachments are not converted. Visual rendering in Notes on Mac and iPhone still needs confirmation; automated checks validate the HTML/RTF output and clipboard behavior.

## Build and test

Requires macOS 13 or later and the Swift/Xcode command-line tools. The build produces a **universal binary** (Apple Silicon and Intel). All runtime dependencies are included in the repository.

```sh
zsh scripts/build.sh
open build/md2notes.app
```

The build signs the app locally, verifies the signature, and runs the tests. No developer certificate is required for local use. The app is not notarized.

To create a distributable archive:

```sh
ditto -c -k --sequesterRsrc --keepParent build/md2notes.app build/md2notes-macOS.zip
```

To run the tests again without rebuilding:

```sh
build/md2notes.app/Contents/MacOS/md2notes --self-test
```

## Repository layout

- `src/`: native app, clipboard handling, and Markdown detection.
- `resources/`: app metadata and HTML transformation.
- `tests/`: automated checks and a sample Markdown file.
- `vendor/marked/`: bundled Markdown parser and its MIT license.
- `scripts/`: reproducible build script.
- `docs/guide.md`: user guide.

The tests use an isolated clipboard for write and restore operations. They may also read the system clipboard to check conversion without changing it or printing its contents.

See the [user guide](docs/guide.md) for details and limitations.
