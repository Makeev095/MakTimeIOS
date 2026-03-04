import Foundation

struct Message: Codable, Identifiable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    let type: MessageType
    var text: String
    var fileUrl: String?
    var fileName: String?
    var duration: Double?
    var replyToId: String?
    let createdAt: String
    var read: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, type, text, duration, read
        case conversationId = "conversationId"
        case senderId = "senderId"
        case fileUrl = "fileUrl"
        case fileName = "fileName"
        case replyToId = "replyToId"
        case createdAt = "createdAt"
    }
    
    var fullFileUrl: String? {
        guard let fileUrl = fileUrl else { return nil }
        if fileUrl.hasPrefix("http") { return fileUrl }
        return "\(AppConfig.baseURL)\(fileUrl)"
    }
    
    var dateFormatted: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt) else {
            return createdAt
        }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        return timeFormatter.string(from: date)
    }
    
    var date: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt)
    }
}

enum MessageType: String, Codable {
    case text
    case voice
    case image
    case video
    case file
}
