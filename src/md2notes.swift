import AppKit
import WebKit
import UniformTypeIdentifiers

enum md2notesError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(s) = self { return s }; return nil }
}

struct ClipboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
    let changeCount: Int
    func isCurrent(_ board: NSPasteboard) -> Bool { board.changeCount == changeCount }
    init(_ board: NSPasteboard) {
        changeCount = board.changeCount
        items = (board.pasteboardItems ?? []).map { item in
            var data: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let value = item.data(forType: type) { data[type] = value } }
            return data
        }
    }
    func restore(to board: NSPasteboard) -> Bool {
        let objects = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: type) }
            return item
        }
        board.clearContents()
        return board.writeObjects(objects)
    }
}

struct PreparedText {
    static let markerVersion = "1.2"
    let html: Data
    let rtf: Data
    let plain: String
    func write(to board: NSPasteboard) -> Bool {
        let item = NSPasteboardItem()
        item.setData(html, forType: .html)
        item.setData(rtf, forType: .rtf)
        item.setString(plain, forType: .string)
        item.setString(Self.markerVersion, forType: NSPasteboard.PasteboardType("com.md2notes.transformed"))
        board.clearContents()
        return board.writeObjects([item])
    }
}

enum TextTransform {
    static func plain(_ input: String) -> String {
        let lines = input.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var output: [String] = []
        var fence: String? = nil
        var previousKind = ""
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let currentFence = fence {
                output.append(line)
                if trimmed.hasPrefix(currentFence) { fence = nil }
                previousKind = "code"
                continue
            }
            if trimmed.isEmpty {
                if !output.isEmpty && !(output.last?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) { output.append("") }
                previousKind = ""
                continue
            }
            let startsFence = trimmed.hasPrefix("```") ? "```" : (trimmed.hasPrefix("~~~") ? "~~~" : nil)
            let kind = startsFence != nil || line.hasPrefix("    ") || line.hasPrefix("\t") ? "code" : (trimmed.hasPrefix("|") ? "table" : (trimmed.range(of: #"^(?:[-+*]\s|\d+[.)]\s)"#, options: .regularExpression) != nil ? "list" : ""))
            if let last = output.last, !last.trimmingCharacters(in: .whitespaces).isEmpty, !(kind != "" && kind == previousKind) { output.append("") }
            output.append(line)
            previousKind = kind
            if let f = startsFence { fence = f }
        }
        while output.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { output.removeLast() }
        return output.joined(separator: "\n")
    }

    static func rich(_ source: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: source)
        let string = source.string as NSString
        var cursor = 0
        var previousKind = ""
        var previousBlank = true
        var insertions: [Int] = []
        while cursor < string.length {
            let range = string.paragraphRange(for: NSRange(location: cursor, length: 0))
            let text = string.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            let attrs = source.attributes(at: cursor, effectiveRange: nil)
            let style = attrs[.paragraphStyle] as? NSParagraphStyle
            let font = attrs[.font] as? NSFont
            let kind = !(style?.textBlocks.isEmpty ?? true) ? "table" : (!(style?.textLists.isEmpty ?? true) ? "list" : (font?.isFixedPitch == true ? "code" : ""))
            if !text.isEmpty && !previousBlank && !(kind != "" && kind == previousKind) { insertions.append(cursor) }
            previousKind = kind
            previousBlank = text.isEmpty
            cursor = NSMaxRange(range)
        }
        let gap = NSAttributedString(string: "\u{00a0}\n", attributes: [.font: NSFont.systemFont(ofSize: 16), .paragraphStyle: NSParagraphStyle.default])
        for index in insertions.reversed() { result.insert(gap, at: index) }
        // Remove empty paragraphs at the document edges without touching internal structure.
        while result.length > 0 {
            let s = result.string as NSString
            let r = s.paragraphRange(for: NSRange(location: 0, length: 0))
            if !s.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
            result.deleteCharacters(in: r)
        }
        while result.length > 0 {
            let s = result.string as NSString
            let r = s.paragraphRange(for: NSRange(location: s.length - 1, length: 0))
            if !s.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
            result.deleteCharacters(in: r)
        }
        return result
    }

    static func prepare(_ attributed: NSAttributedString, html: String? = nil) throws -> PreparedText {
        guard !attributed.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw md2notesError.message("Le presse-papiers ne contient pas de texte.") }
        let range = NSRange(location: 0, length: attributed.length)
        let rtf = try attributed.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let htmlData = try html.map { Data($0.utf8) } ?? attributed.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
        return PreparedText(html: htmlData, rtf: rtf, plain: attributed.string.replacingOccurrences(of: "\u{00a0}\n", with: "\n"))
    }
}

final class HTMLTransform: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((Result<PreparedText, Error>) -> Void)?
    private var timer: Timer?
    func run(_ html: String, completion: @escaping (Result<PreparedText, Error>) -> Void) {
        self.completion = completion
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let rules = #"[{"trigger":{"url-filter":".*"},"action":{"type":"block"}}]"#
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "md2notesNoNetwork", encodedContentRuleList: rules) { [weak self] list, error in
            guard let self = self, self.completion != nil else { return }
            guard let list = list else { self.finish(.failure(error ?? md2notesError.message("Impossible de sécuriser la conversion."))); return }
            config.userContentController.add(list)
            let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
            self.webView = view
            view.navigationDelegate = self
            let csp = "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; script-src 'none'; img-src 'none'; connect-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'\">"
            // Prepend policy before any clipboard markup can be parsed.
            view.loadHTMLString("<!doctype html><html><head><meta charset=\"utf-8\">" + csp + "</head><body>" + html + "</body></html>", baseURL: nil)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in self?.finish(.failure(md2notesError.message("La conversion a pris trop de temps. L’original est conservé."))) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        decisionHandler(url == nil || url?.absoluteString == "about:blank" ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let path = Bundle.main.path(forResource: "transform", ofType: "js"), let script = try? String(contentsOfFile: path, encoding: .utf8) else {
            finish(.failure(md2notesError.message("Le module de conversion est introuvable."))); return
        }
        webView.evaluateJavaScript(script) { [weak self] value, error in
            if let error = error { self?.finish(.failure(error)); return }
            do {
                guard let result = value as? [String: Any], let html = result["html"] as? String else { throw md2notesError.message("Le contenu n’a pas pu être converti.") }
                let attributed = try NSAttributedString(data: Data(html.utf8), options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
                self?.finish(.success(try TextTransform.prepare(attributed, html: html)))
            } catch { self?.finish(.failure(error)) }
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    private func finish(_ result: Result<PreparedText, Error>) {
        timer?.invalidate(); timer = nil
        let callback = completion; completion = nil
        webView?.stopLoading(); webView = nil
        callback?(result)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: NSStatusItem!
    private var snapshot: ClipboardSnapshot?
    private var transformedCount: Int?
    private var busy = false
    private var converter: HTMLTransform?
    private var monitor: Timer?
    private var restoreItem: NSMenuItem?
    func applicationDidFinishLaunching(_ notification: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.target = self
        status.button?.action = #selector(clicked)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        setIcon("text.alignleft", tip: "md2notes — cliquer pour aérer le texte copié")
        monitor = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let count = self.transformedCount, NSPasteboard.general.changeCount != count {
                self.snapshot = nil; self.transformedCount = nil; self.restoreItem?.isEnabled = false
            }
        }
    }
    private func setIcon(_ name: String, tip: String) {
        status.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "md2notes")
        status.button?.toolTip = tip
    }
    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu(); return }
        guard !busy else { return }
        let board = NSPasteboard.general
        if board.string(forType: NSPasteboard.PasteboardType("com.md2notes.transformed")) == PreparedText.markerVersion { feedback(success: true, message: "Ce texte est déjà converti et aéré."); return }
        let before = ClipboardSnapshot(board)
        do { transform(try ClipboardInput.read(board), before: before) }
        catch { feedback(success: false, message: error.localizedDescription) }
    }
    private func transform(_ input: ClipboardInput, before: ClipboardSnapshot) {
        busy = true
        setIcon("hourglass", tip: "md2notes — conversion en cours")
        do {
            switch input {
            case .markdown(let text):
                converter = HTMLTransform()
                converter?.run(try Markdown.html(text)) { [weak self] result in self?.complete(result, before: before) }
            case .html(let html):
                converter = HTMLTransform()
                converter?.run(html) { [weak self] result in self?.complete(result, before: before) }
            case .rtf(let data):
                let original = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
                guard !original.containsAttachments else { throw md2notesError.message("Les pièces jointes ne sont pas transformées.") }
                complete(.success(try TextTransform.prepare(TextTransform.rich(original))), before: before)
            case .plain(let plain):
                let attributed: NSAttributedString
                attributed = NSAttributedString(string: TextTransform.plain(plain), attributes: [.font: NSFont.systemFont(ofSize: 16)])
                complete(.success(try TextTransform.prepare(attributed)), before: before)
            }
        } catch { complete(.failure(error), before: before) }
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard !busy, filenames.count == 1 else { sender.reply(toOpenOrPrint: .failure); return }
        do {
            let text = try Markdown.readFile(URL(fileURLWithPath: filenames[0]))
            transform(.markdown(text), before: ClipboardSnapshot(.general))
            sender.reply(toOpenOrPrint: .success)
        } catch { feedback(success: false, message: error.localizedDescription); sender.reply(toOpenOrPrint: .failure) }
    }
    @objc private func chooseMarkdownFile() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.title = "Convertir un fichier Markdown pour Notes"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, UTType(filenameExtension: "markdown") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            do { transform(.markdown(try Markdown.readFile(url)), before: ClipboardSnapshot(.general)) }
            catch { feedback(success: false, message: error.localizedDescription) }
        }
    }
    private func complete(_ result: Result<PreparedText, Error>, before: ClipboardSnapshot) {
        busy = false; converter = nil
        let board = NSPasteboard.general
        guard before.isCurrent(board) else { feedback(success: false, message: "Une nouvelle copie a été détectée. Elle est conservée."); return }
        switch result {
        case .success(let text):
            if text.write(to: board) {
                snapshot = before; transformedCount = board.changeCount
                feedback(success: true, message: "Texte aéré — collez avec ⌘V dans Notes.")
            } else {
                _ = before.restore(to: board)
                feedback(success: false, message: "Échec de la copie du résultat. Original restauré.")
            }
        case .failure(let error): feedback(success: false, message: error.localizedDescription)
        }
    }
    private func feedback(success: Bool, message: String) {
        setIcon(success ? "checkmark" : "exclamationmark.triangle", tip: "md2notes — " + message)
        if !success {
            let popover = NSPopover()
            let controller = NSViewController()
            let label = NSTextField(wrappingLabelWithString: message)
            label.frame = NSRect(x: 14, y: 14, width: 280, height: 65)
            controller.view = NSView(frame: NSRect(x: 0, y: 0, width: 308, height: 93))
            controller.view.addSubview(label)
            popover.contentViewController = controller
            popover.behavior = .transient
            if let button = status.button { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { popover.close() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self, !self.busy else { return }
            self.setIcon("text.alignleft", tip: "md2notes — cliquer pour aérer le texte copié")
        }
    }
    private func showMenu() {
        let menu = NSMenu()
        let restore = NSMenuItem(title: "Restaurer l’original", action: #selector(restoreOriginal), keyEquivalent: "")
        restore.target = self
        restore.isEnabled = !busy && snapshot != nil && transformedCount == NSPasteboard.general.changeCount
        restoreItem = restore
        menu.autoenablesItems = false
        let file = NSMenuItem(title: "Convertir un fichier Markdown…", action: #selector(chooseMarkdownFile), keyEquivalent: "")
        file.target = self
        file.isEnabled = !busy
        menu.addItem(file)
        menu.addItem(restore)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quitter md2notes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        status.menu = menu
        status.button?.performClick(nil)
        status.menu = nil
    }
    @objc private func restoreOriginal() {
        guard let original = snapshot, transformedCount == NSPasteboard.general.changeCount else { return }
        let success = original.restore(to: .general)
        snapshot = nil; transformedCount = nil
        feedback(success: success, message: success ? "Presse-papiers original restauré." : "La restauration a échoué.")
    }
}

extension NSAttributedString {
    var containsAttachments: Bool {
        var found = false
        enumerateAttribute(.attachment, in: NSRange(location: 0, length: length)) { value, _, stop in
            if value != nil { found = true; stop.pointee = true }
        }
        return found
    }
}

@main struct md2notesMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--self-test") { SelfTests.run(); return }
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
