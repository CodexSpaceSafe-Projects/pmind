import Foundation

public enum MapError: Error, LocalizedError, Equatable {
    case invalidFormat, unsupportedVersion(Int), duplicateID, tooDeep, tooManyTopics, tooLarge, missingTopic, invalidMove
    public var errorDescription: String? {
        switch self {
        case .invalidFormat: "这不是有效的 pmind 文档。"
        case .unsupportedVersion(let version): "文档格式版本 \(version) 暂不支持，请使用较新版本的 pmind。"
        case .duplicateID: "文档包含重复的主题标识。"
        case .tooDeep: "主题层级不能超过 128 层。"
        case .tooManyTopics: "一份文档最多包含 10,000 个主题。"
        case .tooLarge: "文档不能超过 8 MB。"
        case .missingTopic: "找不到所选主题。"
        case .invalidMove: "无法将主题移动到自身或其后代中。"
        }
    }
}

public enum DocumentCodec {
    public static let maxBytes = 8 * 1024 * 1024
    private struct Envelope: Codable {
        let format: String
        let version: Int
        let root: Topic
        let layout: MapLayout
    }

    public static func validate(_ map: MindMap) throws {
        var seen = Set<UUID>()
        func visit(_ topic: Topic, depth: Int) throws {
            guard depth <= 128 else { throw MapError.tooDeep }
            guard seen.insert(topic.id).inserted else { throw MapError.duplicateID }
            guard seen.count <= 10_000 else { throw MapError.tooManyTopics }
            for child in topic.children { try visit(child, depth: depth + 1) }
        }
        try visit(map.root, depth: 0)
    }

    public static func encode(_ map: MindMap) throws -> Data {
        try validate(map)
        let encoder = JSONEncoder()
        // Whitespace must not make a compact, valid document impossible to save.
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(Envelope(format: "pmind", version: 1, root: map.root, layout: map.layout))
        guard data.count <= maxBytes else { throw MapError.tooLarge }
        return data
    }

    public static func decode(_ data: Data) throws -> MindMap {
        guard data.count <= maxBytes else { throw MapError.tooLarge }
        // Read the version before the body, so newer files cannot be silently downgraded.
        guard let header = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              header["format"] as? String == "pmind",
              let version = header["version"] as? Int else { throw MapError.invalidFormat }
        guard version == 1 else { throw MapError.unsupportedVersion(version) }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        let map = MindMap(root: envelope.root, layout: envelope.layout)
        // Opening establishes the same size and tree invariants as saving/editing.
        _ = try encode(map)
        return map
    }
}
