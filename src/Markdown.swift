import AppKit
import JavaScriptCore

enum Markdown {
    static func looksLike(_ text: String) -> Bool {
        guard text.utf8.count <= 5_000_000, let context = try? makeContext() else { return false }
        let lexer = context.objectForKeyedSubscript("marked")?.objectForKeyedSubscript("lexer")
        guard let tokens = lexer?.call(withArguments: [text, ["gfm": true]])?.toArray() else { return false }
        let formatting: Set<String> = ["heading", "strong", "em", "del", "link", "image", "codespan", "code", "blockquote", "list", "table", "hr", "br", "escape"]
        func containsFormatting(_ value: Any) -> Bool {
            if let token = value as? [String: Any] {
                if let type = token["type"] as? String, formatting.contains(type) { return true }
                return token.values.contains(where: containsFormatting)
            }
            if let array = value as? [Any] { return array.contains(where: containsFormatting) }
            return false
        }
        return tokens.contains(where: containsFormatting)
    }
    private static func makeContext() throws -> JSContext {
        guard let context = JSContext(), let path = Bundle.main.path(forResource: "marked", ofType: "js") else {
            throw md2notesError.message("Le convertisseur Markdown est introuvable.")
        }
        context.evaluateScript(try String(contentsOfFile: path, encoding: .utf8))
        guard context.exception == nil else { throw md2notesError.message("Le convertisseur Markdown n’a pas pu démarrer.") }
        return context
    }
    static func readFile(_ url: URL) throws -> String {
        guard url.isFileURL, ["md", "markdown"].contains(url.pathExtension.lowercased()) else {
            throw md2notesError.message("Choisissez un fichier .md ou .markdown.")
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= 5_000_000 else {
            throw md2notesError.message("Choisissez un fichier Markdown de moins de 5 Mo.")
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.hasPrefix("\u{feff}") ? String(text.dropFirst()) : text
    }
    static func html(_ text: String) throws -> String {
        guard text.utf8.count <= 5_000_000 else { throw md2notesError.message("Ce texte dépasse la limite de 5 Mo.") }
        let context = try makeContext()
        var failure: String?
        context.exceptionHandler = { _, exception in failure = exception?.toString() }
        // Pass the text as a value, never interpolate clipboard contents into JavaScript.
        let parser = context.objectForKeyedSubscript("marked")?.objectForKeyedSubscript("parse")
        let result = parser?.call(withArguments: [text, ["gfm": true, "breaks": false, "async": false]])
        guard failure == nil, let result = result, result.isString, let html = result.toString() else {
            throw md2notesError.message("Le Markdown n’a pas pu être converti. L’original est conservé.")
        }
        return html
    }
}

enum ClipboardInput {
    case markdown(String), html(String), rtf(Data), plain(String)
    static func read(_ board: NSPasteboard) throws -> ClipboardInput {
        guard board.pasteboardItems?.count == 1 else { throw md2notesError.message("Copiez un texte ou un seul fichier Markdown.") }
        if let file = board.string(forType: .fileURL), let url = URL(string: file) {
            return .markdown(try Markdown.readFile(url))
        }
        guard board.types?.contains(.png) != true, board.types?.contains(.tiff) != true else {
            throw md2notesError.message("Les images ne sont pas transformées. L’original est conservé.")
        }
        let plain = board.string(forType: .string)
        // ChatGPT can provide both rendered HTML and a Markdown plain-text representation.
        if let plain = plain, Markdown.looksLike(plain) { return .markdown(plain) }
        if let html = board.string(forType: .html), !html.isEmpty { return .html(html) }
        if let rtf = board.data(forType: .rtf) {
            let rich = try NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            if !rich.containsAttachments, Markdown.looksLike(rich.string) { return .markdown(rich.string) }
            return .rtf(rtf)
        }
        if let plain = plain { return .plain(plain) }
        throw md2notesError.message("Le presse-papiers ne contient pas de texte compatible.")
    }
}
