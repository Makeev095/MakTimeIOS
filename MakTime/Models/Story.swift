import Foundation

struct Story: Codable, Identifiable, Equatable {
    let id: String
    let type: StoryType
    let fileUrl: String
    var textOverlay: String
    var bgColor: String
    let createdAt: String
    let expiresAt: String
    var viewed: Bool
    var viewCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, type, viewed
        case fileUrl = "fileUrl"
        case textOverlay = "textOverlay"
        case bgColor = "bgColor"
        case createdAt = "createdAt"
        case expiresAt = "expiresAt"
        case viewCount = "viewCount"
    }
    
    var fullFileUrl: String {
        if fileUrl.hasPrefix("http") { return fileUrl }
        return "\(AppConfig.baseURL)\(fileUrl)"
    }
}

enum StoryType: String, Codable {
    case image
    case video
}

struct StoryUser: Codable, Identifiable, Equatable {
    var id: String { userId }
    let userId: String
    let username: String
    let displayName: String
    let avatarColor: String
    let storyCount: Int
    let hasUnviewed: Bool
    let isOwn: Bool
    var stories: [Story]
    
    enum CodingKeys: String, CodingKey {
        case username
        case userId = "userId"
        case displayName = "displayName"
        case avatarColor = "avatarColor"
        case storyCount = "storyCount"
        case hasUnviewed = "hasUnviewed"
        case isOwn = "isOwn"
        case stories
    }
}

struct StoryViewer: Codable, Identifiable {
    var id: String { viewerId }
    let viewerId: String
    let username: String
    let displayName: String
    let viewedAt: String
    
    enum CodingKeys: String, CodingKey {
        case username
        case viewerId = "viewerId"
        case displayName = "displayName"
        case viewedAt = "viewedAt"
    }
}

struct StoryReaction: Codable, Identifiable {
    let id: String
    let emoji: String
    let userId: String
    let displayName: String
    
    enum CodingKeys: String, CodingKey {
        case id, emoji
        case userId = "userId"
        case displayName = "displayName"
    }
}
