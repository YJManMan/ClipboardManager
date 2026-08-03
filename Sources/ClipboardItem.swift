import Foundation

enum ClipboardItemType {
    case text(String)
    case image(Data)
    case rtf(Data)
    case html(String)
    case fileURLs([URL])
}

extension ClipboardItemType: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    private enum Case: String, Codable {
        case text, image, rtf, html, fileURLs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Case.self, forKey: .type)
        switch type {
        case .text:
            let text = try container.decode(String.self, forKey: .value)
            self = .text(text)
        case .image:
            let data = try container.decode(Data.self, forKey: .value)
            self = .image(data)
        case .rtf:
            let data = try container.decode(Data.self, forKey: .value)
            self = .rtf(data)
        case .html:
            let text = try container.decode(String.self, forKey: .value)
            self = .html(text)
        case .fileURLs:
            let strings = try container.decode([String].self, forKey: .value)
            self = .fileURLs(strings.compactMap { URL(string: $0) })
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode(Case.text, forKey: .type)
            try container.encode(text, forKey: .value)
        case .image(let data):
            try container.encode(Case.image, forKey: .type)
            try container.encode(data, forKey: .value)
        case .rtf(let data):
            try container.encode(Case.rtf, forKey: .type)
            try container.encode(data, forKey: .value)
        case .html(let text):
            try container.encode(Case.html, forKey: .type)
            try container.encode(text, forKey: .value)
        case .fileURLs(let urls):
            try container.encode(Case.fileURLs, forKey: .type)
            try container.encode(urls.map { $0.absoluteString }, forKey: .value)
        }
    }
}

extension ClipboardItemType {
    var previewText: String {
        switch self {
        case .text(let text):
            return text
        case .image:
            return "[图片]"
        case .rtf:
            return "[富文本]"
        case .html(let html):
            let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "[HTML]" : trimmed
        case .fileURLs(let urls):
            return urls.map { $0.lastPathComponent }.joined(separator: ", ")
        }
    }

    var searchText: String {
        previewText.lowercased()
    }
}

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let type: ClipboardItemType
    let timestamp: Date
}
