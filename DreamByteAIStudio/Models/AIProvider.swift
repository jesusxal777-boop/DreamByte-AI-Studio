import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case openRouter
    case gemini

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openRouter: return "OpenRouter"
        case .gemini: return "Google Gemini"
        }
    }

    var subtitle: String {
        switch self {
        case .openRouter: return "Editing suggestions, cuts and effects"
        case .gemini: return "Motion graphics and animated titles"
        }
    }

    var keychainAccount: String {
        switch self {
        case .openRouter: return "openrouter-api-key"
        case .gemini: return "gemini-api-key"
        }
    }

    var placeholder: String {
        switch self {
        case .openRouter: return "Paste your OpenRouter API key"
        case .gemini: return "Paste your Gemini API key"
        }
    }

    var defaultModel: String {
        switch self {
        case .openRouter: return "openai/gpt-oss-20b"
        case .gemini: return ""
        }
    }
}
