import AppKit
import ServiceManagement

enum SelfTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ name: String) {
        guard condition() else { print("FAIL: \(name)"); exit(1) }
        checks += 1; print("PASS: \(name)")
    }
    static func html(_ input: String) throws -> PreparedText {
        let converter = HTMLTransform()
        var result: Result<PreparedText, Error>?
        converter.run(input) { result = $0 }
        let deadline = Date().addingTimeInterval(20)
        while result == nil && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        guard let result = result else { throw md2notesError.message("Test timeout") }
        return try result.get()
    }
    static func run() {
        do {
            check(TextTransform.plain("Bonjour\nÉté 😊\nFin") == "Bonjour\n\nÉté 😊\n\nFin", "plain paragraphs, accents, emoji")
            check(TextTransform.plain("\nA\n\nB\n\n") == "A\n\nB", "empty edges and existing gaps")
            let list = "Titre\n- Un\n  - Deux\n- Trois\nFin"
            check(TextTransform.plain(list) == "Titre\n\n- Un\n  - Deux\n- Trois\n\nFin", "nested list stays compact")
            let code = "Avant\n```swift\nlet x = 1\n\nprint(x)\n```\nAprès"
            let spacedCode = TextTransform.plain(code)
            check(spacedCode == "Avant\n\n```swift\nlet x = 1\n\nprint(x)\n```\n\nAprès", "fenced code interior remains exact")
            check(TextTransform.plain(spacedCode) == spacedCode, "plain idempotence")
            check(TextTransform.plain("- A\n```\nx\n```\n- B") == "- A\n\n```\nx\n```\n\n- B", "separate neighboring list and code blocks")
            let table = "Avant\n| A | B |\n|---|---|\n| 1 | 2 |\nAprès"
            check(TextTransform.plain(table).contains("| A | B |\n|---|---|\n| 1 | 2 |"), "plain markdown table")

            let fixture = "<h2>Titre</h2><p><strong>Été 😊</strong> et <em>italique</em>, <a href='https://example.com'>lien</a>.</p><ul><li>Un<ul><li>Deux</li></ul></li><li>Trois</li></ul><table border='1'><tr><th>A</th><th>B</th></tr><tr><td>1<br>2</td><td>3</td></tr></table><pre>let x = 1\n\nprint(x)</pre><p>Fin</p>"
            let converted = try html(fixture)
            let markup = String(decoding: converted.html, as: UTF8.self)
            check(markup.components(separatedBy: "data-md2notes-gap").count - 1 == 5, "HTML gaps around headings and protected blocks")
            check(markup.contains("<strong>Été 😊</strong>") && markup.contains("<em>italique</em>"), "HTML bold italic unicode")
            check(markup.contains("https://example.com"), "HTML links")
            check(markup.contains("<td>1<br>2</td>") && markup.contains("<pre style="), "HTML table cells and code")
            check(markup.contains("let x = 1\n\nprint(x)"), "HTML exact code interior")
            let repeated = try html(markup)
            check(repeated.html == converted.html, "HTML idempotence")
            check(converted.plain.contains("\n\n"), "plain alternative has physical empty lines")
            let rich = try NSAttributedString(data: converted.rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            var bold = false, italic = false, link = false, tableFound = false
            rich.enumerateAttributes(in: NSRange(location: 0, length: rich.length)) { attrs, _, _ in
                if let f = attrs[.font] as? NSFont {
                    let traits = NSFontManager.shared.traits(of: f)
                    bold = bold || traits.contains(.boldFontMask)
                    italic = italic || traits.contains(.italicFontMask)
                }
                link = link || attrs[.link] != nil
                if let p = attrs[.paragraphStyle] as? NSParagraphStyle { tableFound = tableFound || !p.textBlocks.isEmpty }
            }
            check(bold && italic && link && tableFound, "RTF preserves bold italic links native table")
            let existing = try html("<p>&nbsp;</p><p>A</p><p>&nbsp;</p><p>B</p><p>&nbsp;</p>")
            check(String(decoding: existing.html, as: UTF8.self).components(separatedBy: "data-md2notes-gap").count == 1, "HTML existing gaps and trimmed edges")
            let bare = try html("<div>Un</div><div>Deux</div>")
            check(bare.plain.contains("Un\n\nDeux"), "HTML bare div paragraphs")
            let unsafe = try html("<script>document.body.innerHTML='EXECUTED'</script><p onclick='alert(1)'>A</p><p style='background:url(https://example.com/x)'>B</p>")
            let sanitized = String(decoding: unsafe.html, as: UTF8.self)
            check(!sanitized.contains("EXECUTED") && !sanitized.contains("onclick") && !sanitized.contains("url("), "untrusted HTML is inert and resource-free")
            do { _ = try html("<p>A</p><img src='https://example.com/a.png'>"); check(false, "reject images") } catch { check(true, "reject images without modifying clipboard") }
            let rtfOriginal = NSAttributedString(string: "A\nB", attributes: [.font: NSFont.boldSystemFont(ofSize: 16)])
            let rtfSpaced = TextTransform.rich(rtfOriginal)
            check(rtfSpaced.string == "A\n\u{00a0}\nB", "RTF adds real separator")
            check(TextTransform.rich(rtfSpaced).string == rtfSpaced.string, "RTF idempotence")
            let markdownText = "# Grand titre\n\n## Sous-titre\n\nUn **gras**, *italique*, [lien](https://example.com) et C# intact.\n\n- Premier\n  - Imbriqué\n- Second\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n```python\n# commentaire\nprint('## littéral')\n```\n\n- [x] Fait\n- [ ] À faire"
            let markdownHTML = try Markdown.html(markdownText)
            check(markdownHTML.contains("<h1>Grand titre</h1>") && markdownHTML.contains("<h2>Sous-titre</h2>"), "Markdown headings become real headings")
            let markdownOutput = try html(markdownHTML)
            check(!markdownOutput.plain.contains("# Grand titre") && !markdownOutput.plain.contains("## Sous-titre"), "Markdown heading hashes removed from paste output")
            check(!markdownOutput.plain.contains("**gras**") && !markdownOutput.plain.contains("[lien]("), "Markdown inline syntax removed")
            check(markdownOutput.plain.contains("C# intact") && markdownOutput.plain.contains("# commentaire") && markdownOutput.plain.contains("## littéral"), "literal hashes and fenced code preserved")
            let mdMarkup = String(decoding: markdownOutput.html, as: UTF8.self)
            check(mdMarkup.contains("<table") && mdMarkup.contains("<ul>") && mdMarkup.contains("<strong>gras</strong>"), "Markdown table nested lists and bold preserved")
            check(markdownOutput.plain.contains("☑") && markdownOutput.plain.contains("☐"), "Markdown task status preserved")
            let mdRich = try NSAttributedString(data: markdownOutput.rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            let titleFont = mdRich.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
            check((titleFont?.pointSize ?? 0) > 16, "Markdown RTF title has heading font")
            check(Markdown.looksLike("## Titre") && !Markdown.looksLike("C# et #hashtag"), "Markdown detection does not strip literal hashes")
            check(Markdown.looksLike("*italique*") && Markdown.looksLike("`code`") && Markdown.looksLike("~~barré~~"), "detect Markdown inline-only text")
            let markerCases = [
                ("**gras**", "<strong>gras</strong>", "gras"),
                ("__gras__", "<strong>gras</strong>", "gras"),
                ("*italique*", "<em>italique</em>", "italique"),
                ("_italique_", "<em>italique</em>", "italique"),
                ("***mixte***", "<strong>mixte</strong>", "mixte"),
                ("~~barré~~", "<del>barré</del>", "barré"),
                ("[référence][id]\n\n[id]: https://example.com", "href=\"https://example.com\"", "référence"),
                ("Titre\n=", "<h1>Titre</h1>", "Titre"),
                ("> Citation", "<blockquote>", "Citation"),
                ("1. Élément", "<ol>", "Élément"),
                ("`un_code`", "<code>un_code</code>", "un_code"),
                ("**gras\nsur deux lignes**", "<strong>", "gras")
            ]
            for (source, expectedHTML, expectedText) in markerCases {
                check(Markdown.looksLike(source), "detect Markdown syntax: \(source.prefix(20))")
                let rendered = try Markdown.html(source)
                check(rendered.contains(expectedHTML), "render Markdown syntax: \(source.prefix(20))")
                let output = try html(rendered)
                check(output.plain.contains(expectedText) && !output.plain.contains(source), "paste output removes syntax: \(source.prefix(20))")
            }
            check(!Markdown.looksLike("2 * 3 = 6, fichier_mon_nom, #hashtag et C#"), "literal stars underscores hashtags remain ordinary text")
            let combinedMarkers = try html(Markdown.html("**gras** et _italique_ et ~~barré~~"))
            let markerRich = try NSAttributedString(data: combinedMarkers.rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            var markerBold = false, markerItalic = false, markerStrike = false
            markerRich.enumerateAttributes(in: NSRange(location: 0, length: markerRich.length)) { attrs, _, _ in
                if let font = attrs[.font] as? NSFont {
                    let traits = NSFontManager.shared.traits(of: font)
                    markerBold = markerBold || traits.contains(.boldFontMask)
                    markerItalic = markerItalic || traits.contains(.italicFontMask)
                }
                markerStrike = markerStrike || ((attrs[.strikethroughStyle] as? NSNumber)?.intValue ?? 0) != 0
            }
            check(markerBold && markerItalic && markerStrike, "stars underscores strike become RTF formatting")
            let escaped = try html(Markdown.html("\\# Ceci reste littéral"))
            check(escaped.plain.contains("# Ceci reste littéral"), "escaped Markdown hash preserved")
            let loginDefaults = UserDefaults(suiteName: "md2notes.selftest.login")!
            defer { loginDefaults.removePersistentDomain(forName: "md2notes.selftest.login") }
            loginDefaults.set(true, forKey: LoginItem.offeredKey)
            let loginBefore = SMAppService.mainApp.status
            LoginItem.registerOnFirstLaunch(loginDefaults)
            check(SMAppService.mainApp.status == loginBefore, "launch at login not re-registered after first launch")
            let fixtureURL = Bundle.main.url(forResource: "markdown-fixture", withExtension: "md")!
            let fileText = try Markdown.readFile(fixtureURL)
            check(fileText.contains("# Exemple md2notes"), "UTF8 Markdown file input")
            do { _ = try Markdown.readFile(fixtureURL.deletingPathExtension().appendingPathExtension("txt")); check(false, "reject other file extensions") } catch { check(true, "reject other file extensions") }
            let board = NSPasteboard.withUniqueName()
            defer { board.releaseGlobally() }
            board.setString("original", forType: .string)
            let custom = NSPasteboard.PasteboardType("com.md2notes.test.original")
            board.setData(Data([0, 1, 2, 255]), forType: custom)
            let snapshot = ClipboardSnapshot(board)
            check(snapshot.isCurrent(board), "transaction accepts unchanged clipboard")
            board.clearContents()
            board.setString("new copy", forType: .string)
            if snapshot.isCurrent(board) { _ = converted.write(to: board) }
            check(board.string(forType: .string) == "new copy", "concurrent copy prevents replacement")
            check(converted.write(to: board), "write HTML RTF plain clipboard")
            check(board.data(forType: .html) != nil && board.data(forType: .rtf) != nil && board.string(forType: .string) == converted.plain, "coherent clipboard representations")
            let count = board.changeCount
            check(snapshot.restore(to: board), "restore original clipboard")
            check(board.string(forType: .string) == "original" && board.data(forType: custom) == Data([0, 1, 2, 255]), "restore all original types byte-for-byte")
            check(board.changeCount != count, "clipboard change detection")
            board.clearContents()
            board.setString("## Clipboard titre", forType: .string)
            board.setString("<pre>## Clipboard titre</pre>", forType: .html)
            if case .markdown(let md) = try ClipboardInput.read(board) { check(md == "## Clipboard titre", "clipboard Markdown selected despite HTML wrapper") }
            else { check(false, "clipboard Markdown selected despite HTML wrapper") }
            board.clearContents()
            board.setString(fixtureURL.absoluteString, forType: .fileURL)
            if case .markdown(let md) = try ClipboardInput.read(board) { check(md == fileText, "Finder file clipboard reads Markdown content") }
            else { check(false, "Finder file clipboard reads Markdown content") }
            board.clearContents()
            let markerOnlyRTF = try NSAttributedString(string: "__RTF gras__").data(from: NSRange(location: 0, length: 12), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            board.setData(markerOnlyRTF, forType: .rtf)
            if case .markdown(let md) = try ClipboardInput.read(board) { check(md == "__RTF gras__", "RTF-only clipboard Markdown detection") }
            else { check(false, "RTF-only clipboard Markdown detection") }
            let readOnlyOriginal = ClipboardSnapshot(NSPasteboard.general)
            check(!readOnlyOriginal.items.isEmpty || NSPasteboard.general.pasteboardItems?.isEmpty != false, "system clipboard readable without mutation")
            if let currentHTML = NSPasteboard.general.string(forType: .html), !currentHTML.isEmpty {
                let currentOutput = try html(currentHTML)
                check(!currentOutput.rtf.isEmpty && !currentOutput.plain.isEmpty, "current system HTML clipboard converts successfully")
                check(readOnlyOriginal.isCurrent(NSPasteboard.general), "current clipboard unchanged after read-only conversion")
            }
            print("SUCCESS: \(checks) checks")
        } catch { print("FAIL: \(error)"); exit(1) }
    }
}
