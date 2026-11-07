import Foundation

/// A deliberately small outline dialect: headings, nested lists, paragraphs and quoted notes.
/// Fenced code is preserved as notes and never interpreted as headings or lists.
public enum MarkdownCodec {
    private final class Draft {
        var title: String
        var notes: [String] = []
        var children: [Draft] = []
        init(_ title: String) { self.title = title }
        func topic() -> Topic {
            Topic(title: title, notes: notes.joined(separator: "\n"), children: children.map { $0.topic() })
        }
    }

    public static func decode(_ text: String, title: String = "导入的思维导图") throws -> MindMap {
        guard text.utf8.count <= DocumentCodec.maxBytes else { throw MapError.tooLarge }
        let container = Draft(title)
        var headings: [(level: Int, node: Draft)] = []
        var lists: [(indent: Int, node: Draft)] = []
        var current = container
        var fence: (Character, Int)?
        // The synthetic container may be removed after parsing; count real nodes here.
        var count = 0
        for raw in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let prefix = raw.prefix(while: { $0 == " " || $0 == "\t" })
            let indent = prefix.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
            let line = String(raw.dropFirst(prefix.count))
            let first = line.first
            let run = first.map { c in line.prefix(while: { $0 == c }).count } ?? 0
            if let open = fence {
                current.notes.append(raw)
                if first == open.0 && run >= open.1 && line.dropFirst(run).trimmingCharacters(in: .whitespaces).isEmpty {
                    fence = nil
                }
                continue
            }
            if (first == "`" || first == "~") && run >= 3 {
                fence = (first!, run); current.notes.append(raw); continue
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let hashes = line.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes), line.dropFirst(hashes).first == " " {
                while let last = headings.last, last.level >= hashes { headings.removeLast() }
                let node = Draft(unescape(String(line.dropFirst(hashes + 1))))
                (headings.last?.node ?? container).children.append(node)
                headings.append((hashes, node)); lists.removeAll(); current = node; count += 1
            } else if let content = listContent(line) {
                while let last = lists.last, last.indent >= indent { lists.removeLast() }
                let node = Draft(unescape(content))
                (lists.last?.node ?? headings.last?.node ?? container).children.append(node)
                lists.append((indent, node)); current = node; count += 1
            } else {
                let note = line.hasPrefix("> ") ? String(line.dropFirst(2)) : (line == ">" ? "" : raw)
                current.notes.append(note)
            }
            guard count <= DocumentCodec.maxTopics else { throw MapError.tooManyTopics }
            // Allow one temporary container level; validate the final tree below.
            guard headings.count + lists.count <= DocumentCodec.maxDepth + 1 else { throw MapError.tooDeep }
        }
        let root = container.children.count == 1 && container.notes.isEmpty ? container.children[0] : container
        let map = MindMap(root: root.topic())
        _ = try DocumentCodec.encode(map)
        return map
    }

    public static func encode(_ map: MindMap) -> String {
        var lines = ["# " + escape(map.root.title)]
        func notes(_ text: String, indent: String) {
            guard !text.isEmpty else { return }
            for line in text.components(separatedBy: "\n") { lines.append(indent + "> " + line) }
        }
        notes(map.root.notes, indent: "")
        func visit(_ topic: Topic, depth: Int) {
            let indent = String(repeating: "  ", count: depth)
            lines.append(indent + "- " + escape(topic.title))
            notes(topic.notes, indent: indent + "  ")
            topic.children.forEach { visit($0, depth: depth + 1) }
        }
        map.root.children.forEach { visit($0, depth: 0) }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func listContent(_ line: String) -> String? {
        for prefix in ["- ", "* ", "+ "] where line.hasPrefix(prefix) { return String(line.dropFirst(2)) }
        let digits = line.prefix(while: { $0.isNumber }).count
        guard digits > 0 else { return nil }
        let rest = line.dropFirst(digits)
        if rest.hasPrefix(". ") || rest.hasPrefix(") ") { return String(rest.dropFirst(2)) }
        return nil
    }

    private static func escape(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
        for symbol in ["\\", "#", "*", "_", "`", "[", "]"] {
            result = result.replacingOccurrences(of: symbol, with: "\\" + symbol)
        }
        return result
    }

    private static func unescape(_ text: String) -> String {
        var result = ""; var escaped = false
        for char in text {
            if escaped { result.append(char); escaped = false }
            else if char == "\\" { escaped = true }
            else { result.append(char) }
        }
        if escaped { result.append("\\") }
        return result.replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
