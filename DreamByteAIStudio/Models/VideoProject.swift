import Foundation
import Combine

struct VideoProject: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    var sourceVideoFilename: String?
    var duration: Double
    var trimStart: Double
    var trimEnd: Double

    init(name: String) {
        id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Proyecto sin título" : name
        createdAt = Date()
        modifiedAt = Date()
        sourceVideoFilename = nil
        duration = 0
        trimStart = 0
        trimEnd = 0
    }
}

@MainActor
final class ProjectLibrary: ObservableObject {
    @Published private(set) var projects: [VideoProject] = []
    private let storageKey = "dreambyte.ai.studio.projects.v1"

    init() { load() }

    func add(_ project: VideoProject) {
        projects.insert(project, at: 0)
        save()
    }

    func update(_ project: VideoProject) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        var value = project
        value.modifiedAt = Date()
        projects[index] = value
        save()
    }

    func delete(_ project: VideoProject) {
        projects.removeAll { $0.id == project.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([VideoProject].self, from: data) else { return }
        projects = saved.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}