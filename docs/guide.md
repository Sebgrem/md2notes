# md2notes

md2notes converts Markdown into formatted text for Notes and adds a blank line between paragraphs. It can also add spacing to text that is already formatted.

## Getting started

Open **md2notes.app**. An icon showing text lines appears in your Mac’s menu bar. The app has no main window and does not appear in the Dock.

You can move md2notes.app into your Applications folder. On its first launch, md2notes adds itself to your login items so it opens automatically when you log in. To change this, right-click the icon and toggle “Ouvrir au démarrage”, or use System Settings → General → Login Items. Once you turn it off, md2notes does not turn it back on.

## Using md2notes

1. Copy a response from ChatGPT, Claude, or another AI assistant, some Markdown text, or a `.md` file from Finder.
2. Click the md2notes icon in the menu bar.
3. A checkmark confirms that the text is ready.
4. Paste into Notes with **⌘V**.

In Notes, use a folder in your iCloud account to access the note on your iPhone.

**Right-click** the icon to convert a Markdown file, restore the original clipboard, toggle opening at login, or quit md2notes. Restoration is available only until you copy something else. It restores the clipboard; to undo text already pasted into Notes, use ⌘Z in Notes.

For a `.md` or `.markdown` file, you can also choose “Open With → md2notes” in Finder. md2notes reads the file without changing it and places the converted text on the clipboard. Files must use UTF-8 encoding and be no larger than 5 MB.

## Formatting

Bold, italics, links, lists, and tables are preserved for compatible HTML/RTF content. Lists, table cells, and code blocks stay compact. Existing blank lines are not duplicated.

Markdown is detected automatically from its structure:

- `#`, `##`, and other heading markers become headings without the hash signs.
- `**bold**` and `__bold__` become bold text.
- `*italic*` and `_italic_` become italic text.
- `~~deleted~~` becomes strikethrough text.
- Direct and reference-style links, blockquotes `>`, lists, tables, and headings underlined with `=` or `-` are converted.
- Backticks around code are removed while the code itself remains intact.
- Task lists use ☑ and ☐ symbols, rather than interactive Notes checkboxes.

Markdown markers are not removed indiscriminately: `C#`, hashtags, and escaped hash signs remain present. Plain text without recognizable Markdown syntax simply receives paragraph spacing.

md2notes changes spacing **between paragraphs**, not the line spacing within a paragraph that wraps onto multiple lines.

## Limitations and privacy

- Images, media, and attachments are not converted. Unsupported content leaves the clipboard unchanged.
- If you copy new text during conversion, that new copy is preserved.
- A successful conversion replaces the clipboard with HTML, RTF, and plain-text versions of the result. Source-specific clipboard formats can be recovered using the restore command.
- Processing stays on your Mac. No data is sent to a server and no clipboard history is saved. The original clipboard is kept temporarily in memory for restoration.
- The app is signed locally and is not notarized by Apple. It is a universal app (Apple Silicon and Intel) for macOS 13 or later and has been tested on the Mac used to create it.

## Validation

Automated checks cover paragraph breaks, bold/italic/link/table preservation in HTML and RTF output, multiline code, repeated transformations, concurrent clipboard changes, and full clipboard restoration. They also cover Markdown headings, literal hash signs, and `.md` files copied from Finder.

Version 1.3 uses Marked 18.1.0 for local Markdown conversion. The library is bundled under its MIT license; nothing is downloaded during use. Asterisks used for multiplication and underscores within names remain present: only valid Markdown syntax is converted.

Visual rendering when pasted into Notes on Mac and synced to iPhone still needs confirmation. To check it, copy a response containing two paragraphs, a heading, a list, and a table. Convert it with md2notes, then paste it into a new iCloud note. Paragraphs should have a blank line between them, and the table should remain usable.
