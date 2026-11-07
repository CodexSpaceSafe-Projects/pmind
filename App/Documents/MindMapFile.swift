import SwiftUI
import UniformTypeIdentifiers
import MindMapCore

extension UTType {
    static let pmind = UTType(exportedAs: "app.pmind.document", conformingTo: .json)
}

struct MindMapFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pmind, .init(filenameExtension: "md") ?? .plainText] }
    static var writableContentTypes: [UTType] { [.pmind] }
    var map: MindMap

    init(map: MindMap = .welcome) { self.map = map }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw MapError.invalidFormat }
        if configuration.contentType == .pmind {
            map = try DocumentCodec.decode(data)
        } else {
            guard let text = String(data: data, encoding: .utf8) else { throw MapError.invalidFormat }
            map = try MarkdownCodec.decode(text)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try DocumentCodec.encode(map))
    }
}
