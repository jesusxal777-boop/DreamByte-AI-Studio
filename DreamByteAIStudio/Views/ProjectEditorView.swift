import SwiftUI
import AVKit
import UniformTypeIdentifiers
import AVFoundation
import PhotosUI
import CoreTransferable

private struct ImportedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let copyURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "-" + received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: copyURL)
            return ImportedMovie(url: copyURL)
        }
    }
}

struct ProjectEditorView: View {
    @State private var project: VideoProject
    @State private var player: AVPlayer?
    @State private var showingImporter = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var importError: String?
    @State private var isPlaying = false
    let onUpdate: (VideoProject) -> Void

    private let accent = Color(red: 0.18, green: 0.68, blue: 1.0)
    private let background = Color(red: 0.018, green: 0.035, blue: 0.075)
    private let panel = Color(red: 0.045, green: 0.075, blue: 0.13)

    init(project: VideoProject, onUpdate: @escaping (VideoProject) -> Void) {
        _project = State(initialValue: project)
        self.onUpdate = onUpdate
    }

    private var mediaURL: URL? {
        guard let filename = project.sourceVideoFilename else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DreamByteMedia", isDirectory: true).appendingPathComponent(filename)
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EDITOR").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(2).foregroundStyle(accent)
                            Text(project.name).font(.system(size: 25, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        }
                        Spacer()
                        Button { showingImporter = true } label: {
                            Image(systemName: "plus.rectangle.on.folder").font(.title3.weight(.semibold)).foregroundStyle(.white)
                                .frame(width: 44, height: 44).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    previewPanel
                    HStack(spacing: 10) {
                        toolTile("Fotos", detail: "Vídeos de tu fototeca", icon: "photo.on.rectangle") { showingPhotoPicker = true }
                        toolTile("Archivos", detail: "Explorar ubicaciones", icon: "folder") { showingImporter = true }
                        toolTile("Recortar", detail: "Rango manual", icon: "crop") {}
                        toolTile("Audio", detail: "Herramientas en desarrollo", icon: "waveform") {}
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Línea de tiempo", systemImage: "timeline.selection").font(.headline).foregroundStyle(.white)
                            Spacer()
                            Text(formatTime(project.duration)).font(.system(.caption, design: .monospaced)).foregroundStyle(.white.opacity(0.62))
                        }
                        if project.sourceVideoFilename != nil {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack { Text("INICIO"); Spacer(); Text(formatTime(project.trimStart)) }
                                    .font(.system(.caption2, design: .monospaced).weight(.bold)).foregroundStyle(accent)
                                Slider(value: $project.trimStart, in: 0...max(project.duration, 0.1), step: 0.1)
                                    .tint(accent).onChange(of: project.trimStart) { _, value in
                                        project.trimStart = min(value, project.trimEnd > 0 ? project.trimEnd : project.duration)
                                        player?.seek(to: CMTime(seconds: project.trimStart, preferredTimescale: 600))
                                        onUpdate(project)
                                    }
                                HStack { Text("FINAL"); Spacer(); Text(formatTime(project.trimEnd > 0 ? project.trimEnd : project.duration)) }
                                    .font(.system(.caption2, design: .monospaced).weight(.bold)).foregroundStyle(accent)
                                Slider(value: $project.trimEnd, in: 0...max(project.duration, 0.1), step: 0.1)
                                    .tint(accent).onChange(of: project.trimEnd) { _, value in
                                        project.trimEnd = max(value, project.trimStart)
                                        onUpdate(project)
                                    }
                                Text("El rango de recorte se guarda en el proyecto. La exportación del vídeo recortado aún está en desarrollo.")
                                    .font(.caption).foregroundStyle(.white.opacity(0.55))
                            }
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "rectangle.stack.badge.plus").font(.system(size: 28, weight: .light)).foregroundStyle(accent)
                                Text("Tu línea de tiempo está vacía").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Text("Importa un vídeo para empezar. No necesitas configurar ninguna IA para trabajar aquí.")
                                    .font(.caption).foregroundStyle(.white.opacity(0.58)).multilineTextAlignment(.center)
                                Button { showingImporter = true } label: {
                                    Label("Importar medios", systemImage: "plus").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                        .padding(.horizontal, 16).padding(.vertical, 11).background(accent.gradient, in: Capsule())
                                }.buttonStyle(.plain)
                            }.frame(maxWidth: .infinity).padding(.vertical, 22)
                        }
                    }
                    .padding(17).background(panel, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.07), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 8) {
                        Label("La IA es opcional", systemImage: "sparkles").font(.subheadline.weight(.semibold)).foregroundStyle(accent)
                        Text("La importación, la vista previa y la organización de medios forman la base. Las funciones inteligentes serán herramientas adicionales que eliges usar.")
                            .font(.caption).foregroundStyle(.white.opacity(0.62)).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(accent.opacity(0.16), lineWidth: 1))
                }.padding(18).frame(maxWidth: 900).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar).preferredColorScheme(.dark)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.movie, .video], allowsMultipleSelection: false, onCompletion: handleImport)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .videos)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let movie = try await item.loadTransferable(type: ImportedMovie.self) else {
                        throw NSError(domain: "DreamByteAIStudio.Import", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo leer el vídeo seleccionado."])
                    }
                    importVideo(from: movie.url, usesSecurityScope: false)
                    await MainActor.run { selectedPhoto = nil }
                } catch {
                    await MainActor.run {
                        importError = error.localizedDescription
                        selectedPhoto = nil
                    }
                }
            }
        }
        .alert("No se pudo importar", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("Aceptar", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "Inténtalo de nuevo.") }
        .onAppear { if let url = mediaURL { player = AVPlayer(url: url) } }
        .onDisappear { player?.pause(); onUpdate(project) }
    }

    private var previewPanel: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                if let player {
                    VideoPlayer(player: player)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "play.rectangle.fill").font(.system(size: 40, weight: .ultraLight)).foregroundStyle(accent.opacity(0.9))
                        Text("Vista previa").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.8))
                        Text("Importa un clip para ver tu material aquí").font(.caption).foregroundStyle(.white.opacity(0.48))
                    }
                }
            }.aspectRatio(16.0 / 9.0, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 17))
            HStack {
                Button {
                    guard let player else { return }
                    if isPlaying { player.pause() } else { player.play() }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(accent, in: Circle())
                }.buttonStyle(.plain).disabled(player == nil)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Monitor de edición").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(project.sourceVideoFilename ?? "Sin medios importados").font(.caption).foregroundStyle(.white.opacity(0.56)).lineLimit(1)
                }
                Spacer()
            }.padding(.top, 12)
        }.padding(12).background(panel, in: RoundedRectangle(cornerRadius: 21))
            .overlay(RoundedRectangle(cornerRadius: 21).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func toolTile(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 11) {
                Image(systemName: icon).font(.system(size: 20, weight: .medium)).foregroundStyle(accent)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(detail).font(.system(size: 10)).foregroundStyle(.white.opacity(0.55)).lineLimit(2).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 93, alignment: .leading).padding(12)
            .background(panel, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.07), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let pickedURL = try result.get().first else { return }
            importVideo(from: pickedURL, usesSecurityScope: true)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func importVideo(from sourceURL: URL, usesSecurityScope: Bool) {
        let hasAccess = usesSecurityScope && sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        do {
            let fm = FileManager.default
            let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let folder = documents.appendingPathComponent("DreamByteMedia", isDirectory: true)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let filename = "\(UUID().uuidString)-\(sourceURL.lastPathComponent)"
            let destination = folder.appendingPathComponent(filename)

            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator(filePresenter: nil).coordinate(
                readingItemAt: sourceURL,
                options: [],
                error: &coordinationError
            ) { coordinatedURL in
                do {
                    try fm.copyItem(at: coordinatedURL, to: destination)
                } catch {
                    copyError = error
                }
            }
            if let coordinationError { throw coordinationError }
            if let copyError { throw copyError }

            let asset = AVURLAsset(url: destination)
            Task {
                do {
                    let seconds = try await asset.load(.duration).seconds
                    await MainActor.run {
                        project.sourceVideoFilename = filename
                        project.duration = seconds.isFinite ? max(seconds, 0) : 0
                        project.trimStart = 0
                        project.trimEnd = project.duration
                        player = AVPlayer(url: destination)
                        isPlaying = false
                        onUpdate(project)
                    }
                } catch {
                    await MainActor.run { importError = error.localizedDescription }
                }
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
