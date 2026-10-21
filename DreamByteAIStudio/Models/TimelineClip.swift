import Foundation

struct TimelineClip: Identifiable, Codable, Hashable {
    var id: UUID
    var label: String
    var kind: TimelineClipKind
    var filename: String?
    var duration: Double
    var startTime: Double
    var trackIndex: Int
    var volume: Double
    var effectName: String?
    var transitionName: String?
    var text: String?

    init(id: UUID = UUID(), label: String, kind: TimelineClipKind, filename: String? = nil, duration: Double, startTime: Double = 0, trackIndex: Int, volume: Double = 1, effectName: String? = nil, transitionName: String? = nil, text: String? = nil) {
        self.id = id
        self.label = label
        self.kind = kind
        self.filename = filename
        self.duration = max(0, duration)
        self.startTime = max(0, startTime)
        self.trackIndex = trackIndex
        self.volume = min(1, max(0, volume))
        self.effectName = effectName
        self.transitionName = transitionName
        self.text = text
    }
}

enum TimelineClipKind: String, Codable, CaseIterable, Hashable {
    case video, audio, image, text, subtitle, sticker, effect, transition

    var label: String {
        switch self {
        case .video: return "Vídeo"
        case .audio: return "Audio"
        case .image: return "Imagen"
        case .text: return "Texto"
        case .subtitle: return "Subtítulo"
        case .sticker: return "Sticker"
        case .effect: return "Efecto"
        case .transition: return "Transición"
        }
    }
}
