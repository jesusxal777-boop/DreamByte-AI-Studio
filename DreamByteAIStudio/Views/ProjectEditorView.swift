import SwiftUI
import AVKit
import UniformTypeIdentifiers
import AVFoundation
import PhotosUI
import CoreTransferable
import UIKit

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
    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var importError: String?
    @State private var isPlaying = false
    @State private var previewTime: Double = 0
    @State private var timeObserverToken: Any?
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
                        Image("DreamByteLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EDITOR").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(2).foregroundStyle(accent)
                            Text(project.name).font(.system(size: 25, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        }
                        Spacer()
                        if let exportedURL {
                            ShareLink(item: exportedURL) {
                                Image(systemName: "square.and.arrow.up").font(.title3.weight(.semibold)).foregroundStyle(.white)
                                    .frame(width: 44, height: 44).background(accent.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        Button { exportTimeline() } label: {
                            if isExporting { ProgressView().tint(.white).frame(width: 44, height: 44) }
                            else { Image(systemName: "film.stack").font(.title3.weight(.semibold)).foregroundStyle(.white).frame(width: 44, height: 44).background(accent.opacity(0.3), in: RoundedRectangle(cornerRadius: 14)) }
                        }.disabled(isExporting || mediaURL == nil)
                        Button { showingImporter = true } label: {
                            Image(systemName: "plus.rectangle.on.folder").font(.title3.weight(.semibold)).foregroundStyle(.white)
                                .frame(width: 44, height: 44).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    previewPanel
                    editorToolStrip
                    timelinePanel
                    VStack(alignment: .leading, spacing: 8) {
                        Label("DreamByte AI Studio · Edición multipista", systemImage: "sparkles").font(.caption.weight(.semibold)).foregroundStyle(accent)
                        Text("Selecciona una capa para ajustar su posición y duración. Los elementos visuales activos se muestran sobre la vista previa y se incorporan a la exportación.")
                            .font(.caption).foregroundStyle(.white.opacity(0.58)).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
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
        .onAppear { configurePlayer() }
        .onDisappear {
            player?.pause()
            removeTimeObserver()
            onUpdate(project)
        }
    }

    private func configurePlayer() {
        guard let url = mediaURL else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            player = nil
            importError = "El vídeo de este proyecto ya no está disponible en el almacenamiento de la app. Puedes volver a importarlo desde Medios."
            return
        }
        removeTimeObserver()
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        let start = normalizedTrimStart
        previewTime = start
        newPlayer.seek(to: CMTime(seconds: start, preferredTimescale: 600))
        timeObserverToken = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { time in
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            previewTime = min(max(seconds, normalizedTrimStart), normalizedTrimEnd)
            if isPlaying && seconds >= normalizedTrimEnd - 0.05 {
                newPlayer.pause()
                isPlaying = false
                newPlayer.seek(to: CMTime(seconds: normalizedTrimStart, preferredTimescale: 600))
                previewTime = normalizedTrimStart
            }
        }
    }

    private func removeTimeObserver() {
        if let timeObserverToken, let player {
            player.removeTimeObserver(timeObserverToken)
        }
        timeObserverToken = nil
    }

    private var normalizedTrimStart: Double {
        min(max(0, project.trimStart), max(0, project.duration - 0.1))
    }

    private var normalizedTrimEnd: Double {
        min(max(normalizedTrimStart + 0.1, project.trimEnd), max(normalizedTrimStart + 0.1, project.duration))
    }

    private var editorToolStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                compactTool("Medios", icon: "plus.rectangle.on.folder") { showingImporter = true }
                compactTool("Audio", icon: "waveform") { showingImporter = true }
                compactTool(isRecording ? "Detener" : "Grabar", icon: isRecording ? "stop.circle.fill" : "mic.fill") { startRecording() }
                compactTool("Texto", icon: "textformat") { addOverlay(.text, label: "Texto nuevo") }
                compactTool("Subtítulo", icon: "captions.bubble") { addOverlay(.subtitle, label: "Escribe un subtítulo") }
                compactTool("Sticker", icon: "face.smiling") { addOverlay(.sticker, label: "⭐") }
                compactTool("Efecto", icon: "sparkles") { addOverlay(.effect, label: "Tinte azul") }
                compactTool("Imagen", icon: "photo") { showingImagePicker = true }
            }.padding(.vertical, 2)
        }.scrollIndicators(.hidden)
    }

    private func compactTool(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(title == "Detener" ? .red : accent)
                Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.86))
            }.frame(width: 72, height: 58).background(panel, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.07), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func mediaFileURL(_ filename: String) -> URL {
        (try? mediaFolder().appendingPathComponent(filename)) ?? FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    private var activeVisualClips: [TimelineClip] {
        project.timelineClips.filter { clip in
            [.image, .text, .subtitle, .sticker, .effect].contains(clip.kind) && previewTime >= clip.startTime && previewTime < clip.startTime + clip.duration
        }
    }

    private var timelinePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Timeline multipista", systemImage: "rectangle.3.group").font(.headline).foregroundStyle(.white)
                Spacer()
                Text("\(project.timelineClips.count) clips").font(.caption.monospacedDigit()).foregroundStyle(accent)
            }
            HStack(spacing: 12) {
                Label("00:00", systemImage: "playhead")
                Text("Regla · 1 s = 22 px").foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("MULTITRACK").tracking(1.2).foregroundStyle(accent)
            }.font(.system(size: 10, weight: .semibold, design: .monospaced))
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { tick in
                        VStack(spacing: 4) {
                            Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 7)
                            Text("\(tick * 5)s").font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                        }.frame(width: 110, alignment: .leading)
                    }
                }.padding(.leading, 68)
            }.scrollIndicators(.hidden)
            ForEach(0..<4, id: \.self) { trackIndex in
                HStack(alignment: .top, spacing: 9) {
                    VStack(spacing: 5) {
                        Image(systemName: trackIcon(trackIndex)).font(.system(size: 13, weight: .semibold)).foregroundStyle(accent)
                        Text(trackName(trackIndex)).font(.system(size: 8, weight: .heavy)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                    }.frame(width: 60).padding(.top, 8)
                    ScrollView(.horizontal) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.025))
                            HStack(spacing: 0) {
                                ForEach(project.timelineClips.filter { $0.trackIndex == trackIndex }.sorted { $0.startTime < $1.startTime }) { clip in
                                    if clip.startTime > 0 { Color.clear.frame(width: min(2400, CGFloat(clip.startTime) * 22)) }
                                    Button {
                                        selectedClipID = clip.id
                                        previewTime = min(max(clip.startTime, normalizedTrimStart), normalizedTrimEnd)
                                        player?.seek(to: CMTime(seconds: previewTime, preferredTimescale: 600))
                                    } label: {
                                        timelineClipCard(clip)
                                    }.buttonStyle(.plain)
                                }
                                if project.timelineClips.filter({ $0.trackIndex == trackIndex }).isEmpty {
                                    Text("+ Añade medios a esta pista").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.34)).padding(.horizontal, 10)
                                }
                            }.frame(minHeight: 62, alignment: .leading)
                            Rectangle().fill(accent.opacity(0.85)).frame(width: 1.5, height: 62)
                                .offset(x: CGFloat(max(0, previewTime - normalizedTrimStart)) * 22)
                        }.frame(minWidth: 500, minHeight: 62)
                    }.scrollIndicators(.hidden)
                }
            }
            if let selected = project.timelineClips.first(where: { $0.id == selectedClipID }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Inspector de clip").font(.caption.weight(.heavy)).foregroundStyle(accent)
                            Text(selected.label).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            project.timelineClips.removeAll { $0.id == selected.id }
                            selectedClipID = nil
                            onUpdate(project)
                        } label: { Label("Eliminar", systemImage: "trash").font(.caption.weight(.semibold)) }
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text("Posición"); Spacer(); Text(formatTime(selected.startTime)).monospacedDigit() }
                            .font(.caption).foregroundStyle(.white.opacity(0.75))
                        Slider(value: clipDoubleBinding(selected.id, keyPath: \.startTime), in: 0...max(60, project.duration), step: 0.1).tint(accent)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text("Duración"); Spacer(); Text(formatTime(selected.duration)).monospacedDigit() }
                            .font(.caption).foregroundStyle(.white.opacity(0.75))
                        Slider(value: clipDoubleBinding(selected.id, keyPath: \.duration), in: 0.2...max(60, project.duration), step: 0.1).tint(accent)
                    }
                    if selected.kind == .audio {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text("Volumen"); Spacer(); Text("\(Int(selected.volume * 100))%") }
                                .font(.caption).foregroundStyle(.white.opacity(0.75))
                            Slider(value: clipDoubleBinding(selected.id, keyPath: \.volume), in: 0...1, step: 0.01).tint(.green)
                        }
                    }
                    if selected.kind == .text || selected.kind == .subtitle || selected.kind == .sticker || selected.kind == .effect || selected.kind == .transition {
                        TextField("Contenido o nombre", text: clipTextBinding(selected.id))
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack(spacing: 10) {
                        Button { updateClip(selected.id) { $0.startTime = max(0, $0.startTime - 1) } } label: { Label("−1 s", systemImage: "backward.end.fill").font(.caption) }
                        Button { updateClip(selected.id) { $0.startTime += 1 } } label: { Label("+1 s", systemImage: "forward.end.fill").font(.caption) }
                        Spacer()
                        Text("\(selected.kind.label) · Pista \(selected.trackIndex + 1)").font(.caption2).foregroundStyle(.white.opacity(0.45))
                    }.buttonStyle(.bordered).tint(accent)
                }.padding(12).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            }
            if isRecording {
                Label("Grabando voz… toca Grabar voz otra vez para terminar", systemImage: "record.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(.red)
            }
        }
        .padding(15).background(panel, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.07), lineWidth: 1))
    }

    private func timelineClipCard(_ clip: TimelineClip) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: clip.kind == .audio ? "waveform" : clip.kind == .image ? "photo" : clip.kind == .video ? "film" : clip.kind == .sticker ? "face.smiling" : clip.kind == .effect ? "sparkles" : "textformat")
                    .font(.system(size: 9, weight: .bold))
                Text(clip.label).font(.system(size: 10, weight: .bold)).lineLimit(1)
            }
            if clip.kind == .audio {
                HStack(alignment: .center, spacing: 2) { ForEach(0..<18, id: \.self) { i in Capsule().fill(.white.opacity(0.72)).frame(width: 2, height: CGFloat([7,13,9,18,11,6,15,20,10,16,8,13,19,7,11,17,9,14][i])) } }.frame(height: 20)
            } else if clip.kind == .image, let filename = clip.filename, let image = UIImage(contentsOfFile: mediaFileURL(filename).path) {
                Image(uiImage: image).resizable().scaledToFill().frame(height: 20).clipped().clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Text("\(formatTime(clip.startTime))  ·  \(formatTime(clip.duration))").font(.system(size: 8, design: .monospaced)).lineLimit(1).opacity(0.8)
            }
        }.foregroundStyle(.white).padding(6)
            .frame(width: max(CGFloat(76), min(CGFloat(440), CGFloat(max(clip.duration, 0.6)) * 22)), height: 58, alignment: .leading)
            .background(LinearGradient(colors: [colorFor(clip.kind).opacity(selectedClipID == clip.id ? 0.72 : 0.48), colorFor(clip.kind).opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(selectedClipID == clip.id ? .white : colorFor(clip.kind).opacity(0.75), lineWidth: selectedClipID == clip.id ? 1.5 : 0.7))
    }

    private func updateClip(_ id: UUID, mutate: (inout TimelineClip) -> Void) {
        guard let index = project.timelineClips.firstIndex(where: { $0.id == id }) else { return }
        mutate(&project.timelineClips[index])
        project.timelineClips[index].startTime = max(0, project.timelineClips[index].startTime)
        project.timelineClips[index].duration = max(0.2, project.timelineClips[index].duration)
        project.timelineClips[index].volume = min(1, max(0, project.timelineClips[index].volume))
        onUpdate(project)
    }

    private func clipDoubleBinding(_ id: UUID, keyPath: WritableKeyPath<TimelineClip, Double>) -> Binding<Double> {
        Binding(
            get: { project.timelineClips.first(where: { $0.id == id }).map { $0[keyPath: keyPath] } ?? 0 },
            set: { newValue in updateClip(id) { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func clipTextBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { project.timelineClips.first(where: { $0.id == id }).map { $0.text ?? $0.label } ?? "" },
            set: { newValue in updateClip(id) { $0.text = newValue; $0.label = newValue } }
        )
    }

    private var trimStartBinding: Binding<Double> {
        Binding(
            get: { normalizedTrimStart },
            set: { newValue in
                project.trimStart = min(max(0, newValue), max(0, normalizedTrimEnd - 0.1))
                if previewTime < project.trimStart { previewTime = project.trimStart }
                onUpdate(project)
            }
        )
    }

    private var trimEndBinding: Binding<Double> {
        Binding(
            get: { normalizedTrimEnd },
            set: { newValue in
                project.trimEnd = max(normalizedTrimStart + 0.1, min(newValue, project.duration))
                if previewTime > project.trimEnd { previewTime = project.trimEnd }
                onUpdate(project)
            }
        )
    }

    private func exportTimeline() {
        guard !isExporting, let sourceURL = mediaURL else { return }
        isExporting = true
        exportedURL = nil
        Task {
            do {
                let source = AVURLAsset(url: sourceURL)
                let videoTracks = try await source.loadTracks(withMediaType: .video)
                guard let sourceVideoTrack = videoTracks.first else { throw importFailure("El vídeo principal no contiene una pista de vídeo compatible.") }
                let sourceDuration = try await source.load(.duration).seconds
                let start = min(max(0, project.trimStart), max(0, sourceDuration - 0.1))
                let end = min(max(start + 0.1, project.trimEnd), sourceDuration)
                let duration = max(0.1, end - start)
                let composition = AVMutableComposition()
                guard let outputVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    throw importFailure("No se pudo crear la pista de vídeo de salida.")
                }
                try outputVideo.insertTimeRange(CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: CMTime(seconds: duration, preferredTimescale: 600)), of: sourceVideoTrack, at: .zero)
                var mixParameters: [AVAudioMixInputParameters] = []
                if let sourceAudioTrack = try await source.loadTracks(withMediaType: .audio).first {
                    let audioAvailable = max(0, min(duration, sourceDuration - start))
                    if audioAvailable > 0, let outputMainAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                        try outputMainAudio.insertTimeRange(CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: CMTime(seconds: audioAvailable, preferredTimescale: 600)), of: sourceAudioTrack, at: .zero)
                        let originalAudioParameters = AVMutableAudioMixInputParameters(track: outputMainAudio)
                        originalAudioParameters.setVolume(1, at: .zero)
                        mixParameters.append(originalAudioParameters)
                    }
                }
                let folder = try mediaFolder()
                for clip in project.timelineClips where clip.kind == .audio {
                    guard let filename = clip.filename else { continue }
                    let audioURL = folder.appendingPathComponent(filename)
                    guard FileManager.default.fileExists(atPath: audioURL.path) else { continue }
                    let audioAsset = AVURLAsset(url: audioURL)
                    guard let sourceAudio = try await audioAsset.loadTracks(withMediaType: .audio).first else { continue }
                    let audioDuration = try await audioAsset.load(.duration).seconds
                    let clipDuration = min(max(0.1, clip.duration), audioDuration)
                    // Los clips se guardan en el reloj del vídeo fuente; al exportar
                    // deben trasladarse al reloj local del segmento recortado.
                    let insertionStart = max(0, clip.startTime - start)
                    guard insertionStart < duration else { continue }
                    let usableDuration = min(clipDuration, duration - insertionStart)
                    guard let outputAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }
                    try outputAudio.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: usableDuration, preferredTimescale: 600)), of: sourceAudio, at: CMTime(seconds: insertionStart, preferredTimescale: 600))
                    let parameters = AVMutableAudioMixInputParameters(track: outputAudio)
                    parameters.setVolume(Float(clip.volume), at: .zero)
                    mixParameters.append(parameters)
                }
                let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("DreamByte-Export-\(UUID().uuidString).mp4")
                guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                    throw importFailure("No se pudo iniciar el exportador de vídeo.")
                }
                exporter.outputURL = outputURL
                exporter.outputFileType = .mp4
                exporter.shouldOptimizeForNetworkUse = true
                if !mixParameters.isEmpty {
                    let audioMix = AVMutableAudioMix()
                    audioMix.inputParameters = mixParameters
                    exporter.audioMix = audioMix
                }
                let naturalSize = try await sourceVideoTrack.load(.naturalSize)
                let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
                let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform).standardized
                let renderSize = CGSize(width: max(2, abs(transformedRect.width)), height: max(2, abs(transformedRect.height)))
                let videoComposition = AVMutableVideoComposition()
                videoComposition.renderSize = renderSize
                videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: outputVideo)
                let normalizedTransform = preferredTransform.concatenating(CGAffineTransform(translationX: -transformedRect.minX, y: -transformedRect.minY))
                layerInstruction.setTransform(normalizedTransform, at: .zero)
                instruction.layerInstructions = [layerInstruction]
                videoComposition.instructions = [instruction]
                let parentLayer = CALayer()
                parentLayer.frame = CGRect(origin: .zero, size: renderSize)
                parentLayer.masksToBounds = true
                let videoLayer = CALayer()
                videoLayer.frame = parentLayer.bounds
                parentLayer.addSublayer(videoLayer)
                for clip in project.timelineClips where [.image, .text, .subtitle, .sticker, .effect].contains(clip.kind) {
                    let localStart = max(0, clip.startTime - start)
                    let localEnd = min(duration, clip.startTime + clip.duration - start)
                    guard localEnd > localStart else { continue }
                    let overlay = CALayer()
                    let inset = renderSize.width * 0.06
                    overlay.frame = CGRect(x: inset, y: renderSize.height * 0.08, width: renderSize.width - inset * 2, height: renderSize.height * 0.84)
                    overlay.opacity = 0
                    if clip.kind == .image, let filename = clip.filename, let image = UIImage(contentsOfFile: mediaFileURL(filename).path) {
                        overlay.contents = image.cgImage
                        overlay.contentsGravity = .resizeAspect
                        overlay.frame = CGRect(x: renderSize.width * 0.62, y: renderSize.height * 0.58, width: renderSize.width * 0.32, height: renderSize.height * 0.32)
                    } else if clip.kind == .text || clip.kind == .subtitle || clip.kind == .sticker {
                        let textLayer = CATextLayer()
                        textLayer.string = clip.text ?? clip.label
                        textLayer.alignmentMode = .center
                        textLayer.isWrapped = true
                        textLayer.contentsScale = 2
                        textLayer.foregroundColor = UIColor.white.cgColor
                        if clip.kind == .subtitle {
                            textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.62).cgColor
                            textLayer.cornerRadius = 8
                            textLayer.masksToBounds = true
                        }
                        textLayer.fontSize = clip.kind == .subtitle ? max(18, renderSize.width * 0.035) : max(24, renderSize.width * 0.05)
                        textLayer.shadowColor = UIColor.black.cgColor
                        textLayer.shadowOpacity = 0.95
                        textLayer.shadowRadius = 4
                        textLayer.frame = clip.kind == .subtitle ? CGRect(x: inset, y: renderSize.height * 0.06, width: renderSize.width - inset * 2, height: renderSize.height * 0.14) : overlay.frame
                        overlay.addSublayer(textLayer)
                    } else if clip.kind == .effect {
                        overlay.backgroundColor = UIColor.systemCyan.withAlphaComponent(0.12).cgColor
                    }
                    let fade = CAKeyframeAnimation(keyPath: "opacity")
                    fade.values = [0, 1, 1, 0]
                    fade.keyTimes = [0, 0.03, 0.97, 1]
                    fade.beginTime = AVCoreAnimationBeginTimeAtZero + localStart
                    fade.duration = max(0.05, localEnd - localStart)
                    fade.fillMode = .both
                    fade.isRemovedOnCompletion = false
                    overlay.add(fade, forKey: "clipVisibility")
                    parentLayer.addSublayer(overlay)
                }
                videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
                exporter.videoComposition = videoComposition
                exporter.exportAsynchronously {
                    DispatchQueue.main.async {
                        isExporting = false
                        if exporter.status == .completed {
                            exportedURL = outputURL
                        } else {
                            importError = exporter.error?.localizedDescription ?? "La exportación no se pudo completar."
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    importError = error.localizedDescription
                }
            }
        }
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
                    ForEach(activeVisualClips) { clip in
                        if clip.kind == .image, let filename = clip.filename, let image = UIImage(contentsOfFile: mediaFileURL(filename).path) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: 210, maxHeight: 150).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(16)
                        } else if clip.kind == .text || clip.kind == .subtitle || clip.kind == .sticker {
                            Text(clip.text ?? clip.label).font(.system(size: clip.kind == .subtitle ? 17 : 25, weight: .bold, design: .rounded))
                                .foregroundStyle(.white).shadow(color: .black.opacity(0.9), radius: 4).padding(.horizontal, 12).padding(.vertical, 7)
                                .background(clip.kind == .subtitle ? Color.black.opacity(0.58) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: clip.kind == .subtitle ? .bottom : .center)
                                .padding(.bottom, clip.kind == .subtitle ? 20 : 0)
                        } else if clip.kind == .effect {
                            Color.cyan.opacity(0.12).allowsHitTesting(false)
                        }
                    }
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
                    if isPlaying {
                        player.pause()
                    } else {
                        if previewTime >= normalizedTrimEnd - 0.05 {
                            previewTime = normalizedTrimStart
                            player.seek(to: CMTime(seconds: normalizedTrimStart, preferredTimescale: 600))
                        }
                        player.play()
                    }
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
            HStack(spacing: 10) {
                Text(formatTime(previewTime)).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(accent)
                Slider(value: $previewTime, in: normalizedTrimStart...normalizedTrimEnd, step: 0.1) { editing in
                    if !editing { player?.seek(to: CMTime(seconds: previewTime, preferredTimescale: 600)) }
                }.tint(accent)
                Text(formatTime(normalizedTrimEnd)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
            }.padding(.top, 8)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Recorte del proyecto").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("\(formatTime(normalizedTrimStart)) – \(formatTime(normalizedTrimEnd))")
                        .font(.caption.monospacedDigit()).foregroundStyle(accent)
                }
                HStack(spacing: 10) {
                    Text("IN").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(accent)
                    Slider(value: trimStartBinding, in: 0...max(0, project.duration - 0.1), step: 0.1).tint(accent)
                    Text("OUT").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(accent)
                    Slider(value: trimEndBinding, in: 0.1...max(0.1, project.duration), step: 0.1).tint(accent)
                }
            }.padding(.top, 8)
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
        let clip = TimelineClip(label: label, kind: kind, filename: nil, duration: 3, startTime: max(0, previewTime), trackIndex: kind == .audio ? 1 : 3, effectName: kind == .effect ? label : nil, transitionName: kind == .transition ? label : nil, text: [.text, .subtitle, .sticker].contains(kind) ? label : nil)
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
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                guard granted else { importError = "Activa el permiso de micrófono en Ajustes para grabar audio."; return }
                do {
                    let url = try mediaFolder().appendingPathComponent("Voz-\(UUID().uuidString).m4a")
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                    try session.setActive(true)
                    let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
                    let recorder = try AVAudioRecorder(url: url, settings: settings)
                    recorder.delegate = nil
                    guard recorder.prepareToRecord(), recorder.record() else {
                        throw importFailure("iPadOS no pudo iniciar la grabación. Comprueba el micrófono y vuelve a intentarlo.")
                    }
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
                        // El proyecto usa un vídeo fuente principal; reemplazarlo
                        // evita que la biblioteca muestre una pista que no puede
                        // participar en la exportación actual.
                        project.timelineClips.removeAll { $0.kind == .video }
                        project.sourceVideoFilename = filename
                        project.duration = seconds.isFinite ? max(seconds, 0) : 0
                        project.trimStart = 0
                        project.trimEnd = project.duration
                        project.timelineClips.append(TimelineClip(label: destination.deletingPathExtension().lastPathComponent, kind: .video, filename: filename, duration: project.duration, startTime: 0, trackIndex: 0))
                        isPlaying = false
                        configurePlayer()
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
