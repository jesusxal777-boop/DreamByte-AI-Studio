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
    @State private var showingImagePicker = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var audioRecorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var selectedClipID: UUID?
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
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        toolTile("Vídeo", detail: "Fotos o Archivos", icon: "film") { showingPhotoPicker = true }
                        toolTile("Imagen", detail: "Añadir imagen", icon: "photo") { showingImagePicker = true }
                        toolTile("Archivos", detail: "Vídeo, audio e imagen", icon: "folder") { showingImporter = true }
                        toolTile("Grabar voz", detail: "Micrófono", icon: "mic") { startRecording() }
                        toolTile("Texto", detail: "Pista de texto", icon: "textformat") { addOverlay(.text, label: "Texto nuevo") }
                        toolTile("Subtítulo", detail: "Pista de subtítulo", icon: "captions.bubble") { addOverlay(.subtitle, label: "Escribe un subtítulo") }
                        toolTile("Sticker", detail: "Elemento superpuesto", icon: "face.smiling") { addOverlay(.sticker, label: "⭐") }
                        toolTile("Efecto", detail: "Marcador de efecto", icon: "sparkles") { addOverlay(.effect, label: "Ajuste de color") }
                        toolTile("Transición", detail: "Entre clips", icon: "arrow.left.arrow.right") { addOverlay(.transition, label: "Disolver") }
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
                    timelinePanel
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
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.item], allowsMultipleSelection: true, onCompletion: handleImport)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .videos)
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedImage, matching: .images)
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
        .onChange(of: selectedImage) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw importFailure("No se pudo leer la imagen seleccionada.") }
                    let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                    await MainActor.run { importAssetData(data, fileExtension: ext, kind: .image, label: "Imagen") ; selectedImage = nil }
                } catch { await MainActor.run { importError = error.localizedDescription; selectedImage = nil } }
            }
        }
        .alert("No se pudo importar", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("Aceptar", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "Inténtalo de nuevo.") }
        .onAppear { if let url = mediaURL { player = AVPlayer(url: url) } }
        .onDisappear { player?.pause(); onUpdate(project) }
    }

    private var timelinePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Timeline multipista", systemImage: "rectangle.3.group").font(.headline).foregroundStyle(.white)
                Spacer()
                Text("\(project.timelineClips.count) clips").font(.caption.monospacedDigit()).foregroundStyle(accent)
            }
            Text("Los medios se organizan por pistas. Selecciona un clip para quitarlo.")
                .font(.caption).foregroundStyle(.white.opacity(0.55))
            ForEach(0..<4, id: \.self) { trackIndex in
                HStack(alignment: .top, spacing: 9) {
                    VStack(spacing: 5) {
                        Image(systemName: trackIcon(trackIndex)).font(.system(size: 13, weight: .semibold)).foregroundStyle(accent)
                        Text(trackName(trackIndex)).font(.system(size: 8, weight: .heavy)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                    }.frame(width: 60).padding(.top, 8)
                    ScrollView(.horizontal) {
                        HStack(spacing: 7) {
                            ForEach(project.timelineClips.filter { $0.trackIndex == trackIndex }) { clip in
                                Button {
                                    selectedClipID = clip.id
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(clip.label).font(.system(size: 11, weight: .semibold)).lineLimit(2)
                                        Text(formatTime(clip.duration)).font(.system(size: 9, design: .monospaced)).opacity(0.75)
                                    }
                                    .foregroundStyle(.white).padding(9).frame(width: max(CGFloat(90), min(CGFloat(190), CGFloat(max(clip.duration, 2)) * 13)), height: 55, alignment: .leading)
                                    .background((selectedClipID == clip.id ? accent : colorFor(clip.kind)).opacity(selectedClipID == clip.id ? 0.45 : 0.22), in: RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(selectedClipID == clip.id ? accent : colorFor(clip.kind).opacity(0.55), lineWidth: 1))
                                }.buttonStyle(.plain)
                            }
                            if project.timelineClips.filter({ $0.trackIndex == trackIndex }).isEmpty {
                                Text("Arrastra o añade medios aquí").font(.system(size: 10)).foregroundStyle(.white.opacity(0.35)).padding(.vertical, 18)
                            }
                        }
                    }.scrollIndicators(.hidden)
                }
            }
            if let selected = project.timelineClips.first(where: { $0.id == selectedClipID }) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selected.label).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text("\(selected.kind.label) · \(formatTime(selected.startTime)) · \(formatTime(selected.duration))").font(.caption).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Button(role: .destructive) {
                        project.timelineClips.removeAll { $0.id == selected.id }
                        selectedClipID = nil
                        onUpdate(project)
                    } label: { Label("Eliminar", systemImage: "trash").font(.caption.weight(.semibold)) }
                }.padding(10).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }
            if isRecording {
                Label("Grabando voz… toca Grabar voz otra vez para terminar", systemImage: "record.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(.red)
            }
        }
        .padding(15).background(panel, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.07), lineWidth: 1))
    }

    private func trackName(_ index: Int) -> String {
        switch index { case 0: return "VÍDEO"; case 1: return "AUDIO"; case 2: return "IMÁGENES"; default: return "TEXTO / FX" }
    }

    private func trackIcon(_ index: Int) -> String {
        switch index { case 0: return "film"; case 1: return "waveform"; case 2: return "photo"; default: return "textformat" }
    }

    private func colorFor(_ kind: TimelineClipKind) -> Color {
        switch kind {
        case .video: return accent
        case .audio: return .green
        case .image: return .orange
        case .text, .subtitle: return .cyan
        case .sticker: return .yellow
        case .effect: return .purple
        case .transition: return .pink
        }
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
            let urls = try result.get()
            guard !urls.isEmpty else { return }
            for url in urls { importPickedFile(url) }
        } catch { importError = error.localizedDescription }
    }

    private func importPickedFile(_ sourceURL: URL) {
        let ext = sourceURL.pathExtension.lowercased()
        let type = UTType(filenameExtension: ext)
        if type?.conforms(to: .movie) == true || type?.conforms(to: .video) == true || ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) {
            importVideo(from: sourceURL, usesSecurityScope: true)
        } else if type?.conforms(to: .audio) == true || ["mp3", "m4a", "wav", "aac", "aiff", "caf", "flac"].contains(ext) {
            importFileAsset(from: sourceURL, usesSecurityScope: true, kind: .audio)
        } else if type?.conforms(to: .image) == true || ["png", "jpg", "jpeg", "heic", "webp", "gif"].contains(ext) {
            importFileAsset(from: sourceURL, usesSecurityScope: true, kind: .image)
        } else {
            importError = "Ese tipo de archivo no es compatible. Prueba con vídeo, audio o imagen."
        }
    }

    private func importFailure(_ message: String) -> NSError {
        NSError(domain: "DreamByteAIStudio.Import", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func mediaFolder() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documents.appendingPathComponent("DreamByteMedia", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func importAssetData(_ data: Data, fileExtension ext: String, kind: TimelineClipKind, label: String) {
        do {
            let filename = "\(UUID().uuidString).\(ext)"
            let destination = try mediaFolder().appendingPathComponent(filename)
            try data.write(to: destination, options: .atomic)
            project.timelineClips.append(TimelineClip(label: label, kind: kind, filename: filename, duration: kind == .image ? 5 : 0, startTime: 0, trackIndex: kind == .image ? 2 : 1))
            onUpdate(project)
        } catch { importError = error.localizedDescription }
    }

    private func importFileAsset(from sourceURL: URL, usesSecurityScope: Bool, kind: TimelineClipKind) {
        let hasAccess = usesSecurityScope && sourceURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }
        do {
            let destination = try mediaFolder().appendingPathComponent("\(UUID().uuidString)-\(sourceURL.lastPathComponent)")
            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { coordinatedURL in
                do { try FileManager.default.copyItem(at: coordinatedURL, to: destination) } catch { copyError = error }
            }
            if let coordinationError { throw coordinationError }
            if let copyError { throw copyError }
            let seconds: Double = kind == .audio ? (try? AVURLAsset(url: destination).duration.seconds) ?? 0 : 5
            project.timelineClips.append(TimelineClip(label: sourceURL.deletingPathExtension().lastPathComponent, kind: kind, filename: destination.lastPathComponent, duration: seconds.isFinite ? max(seconds, 0) : 0, startTime: 0, trackIndex: kind == .audio ? 1 : 2))
            onUpdate(project)
        } catch { importError = error.localizedDescription }
    }

    private func addOverlay(_ kind: TimelineClipKind, label: String) {
        let clip = TimelineClip(label: label, kind: kind, filename: nil, duration: 3, startTime: max(0, project.trimStart), trackIndex: kind == .audio ? 1 : 3)
        project.timelineClips.append(clip)
        selectedClipID = clip.id
        onUpdate(project)
    }

    private func startRecording() {
        if isRecording {
            let url = audioRecorder?.url
            audioRecorder?.stop()
            audioRecorder = nil
            isRecording = false
            if let url {
                let asset = AVURLAsset(url: url)
                Task {
                    let seconds = (try? await asset.load(.duration).seconds) ?? 0
                    await MainActor.run {
                        project.timelineClips.append(TimelineClip(label: "Voz grabada", kind: .audio, filename: url.lastPathComponent, duration: seconds.isFinite ? max(seconds, 0) : 0, startTime: 0, trackIndex: 1))
                        onUpdate(project)
                    }
                }
            }
            return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                guard granted else { importError = "Activa el permiso de micrófono en Ajustes para grabar audio."; return }
                do {
                    let url = try mediaFolder().appendingPathComponent("Voz-\(UUID().uuidString).m4a")
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                    try session.setActive(true)
                    let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
                    let recorder = try AVAudioRecorder(url: url, settings: settings)
                    recorder.record()
                    audioRecorder = recorder
                    isRecording = true
                    // A second tap stops the recorder; the completed file becomes a timeline audio clip.
                } catch { importError = error.localizedDescription }
            }
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
                        project.timelineClips.append(TimelineClip(label: destination.deletingPathExtension().lastPathComponent, kind: .video, filename: filename, duration: project.duration, startTime: 0, trackIndex: 0))
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
