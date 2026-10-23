import SwiftUI

private enum DreamGlass {
    static let background = Color(red: 0.018, green: 0.035, blue: 0.075)
    static let panel = Color(red: 0.045, green: 0.075, blue: 0.13)
    static let blue = Color(red: 0.16, green: 0.66, blue: 1.0)
    static let cyan = Color(red: 0.31, green: 0.91, blue: 1.0)
    static let muted = Color.white.opacity(0.58)
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ContentView: View {
    @StateObject private var library = ProjectLibrary()
    @State private var showingCreate = false
    @State private var showingSettings = false
    @State private var projectName = ""
    @State private var activeProject: VideoProject?
    @State private var scrollOffset: CGFloat = 0
    @State private var searchText = ""
    @State private var selectedFilter = "Todos"
    private let columns = [GridItem(.adaptive(minimum: 245), spacing: 16, alignment: .top)]

    private var filteredProjects: [VideoProject] {
        library.projects.filter { p in
            let search = searchText.isEmpty || p.name.localizedCaseInsensitiveContains(searchText)
            let filter = selectedFilter == "Todos" || (selectedFilter == "Con vídeo" && p.sourceVideoFilename != nil) || (selectedFilter == "Sin vídeo" && p.sourceVideoFilename == nil)
            return search && filter
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                DreamGlass.background.ignoresSafeArea()
                ScrollView {
                    GeometryReader { proxy in
                        Color.clear.preference(key: ScrollOffsetKey.self, value: proxy.frame(in: .named("homeScroll")).minY)
                    }.frame(height: 0)
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        VStack(alignment: .leading, spacing: 7) {
                            Text("TU ESPACIO CREATIVO").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2.1).foregroundStyle(DreamGlass.cyan)
                            Text("Tus proyectos.\nTu manera de editar.").font(.system(size: 32, weight: .bold, design: .rounded)).tracking(-0.9).foregroundStyle(.white)
                            Text("Una estación de edición completa, con IA cuando tú quieras.").font(.subheadline).foregroundStyle(DreamGlass.muted)
                        }
                        createButton
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Proyectos").font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                Text("\(library.projects.count) en tu biblioteca").font(.caption).foregroundStyle(DreamGlass.muted)
                            }
                            Spacer()
                            Menu {
                                ForEach(["Todos", "Con vídeo", "Sin vídeo"], id: \.self) { filter in
                                    Button { selectedFilter = filter } label: {
                                        if selectedFilter == filter { Label(filter, systemImage: "checkmark") } else { Text(filter) }
                                    }
                                }
                            } label: {
                                Label(selectedFilter, systemImage: "line.3.horizontal.decrease").font(.caption.weight(.semibold)).foregroundStyle(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(.white.opacity(0.07), in: Capsule())
                                    .overlay(Capsule().stroke(.white.opacity(0.09), lineWidth: 1))
                            }
                        }
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(DreamGlass.muted)
                            TextField("Buscar proyectos", text: $searchText).font(.subheadline).tint(DreamGlass.cyan).foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(DreamGlass.panel, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.07), lineWidth: 1))
                        if filteredProjects.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(filteredProjects) { project in
                                    ProjectCard(project: project, onOpen: {
                                        activeProject = project
                                    }, onDelete: { library.delete(project) })
                                }
                            }
                        }
                        HStack(spacing: 10) {
                            Image(systemName: "slider.horizontal.3").font(.title3).foregroundStyle(DreamGlass.cyan)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Edición manual primero").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Text("Importa, revisa y organiza tus clips sin depender de una IA. Las herramientas inteligentes serán opcionales.")
                                    .font(.caption).foregroundStyle(DreamGlass.muted).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(DreamGlass.panel.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(DreamGlass.blue.opacity(0.18), lineWidth: 1))
                    }
                    .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 110)
                    .frame(maxWidth: 1000).frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: "homeScroll").scrollIndicators(.hidden)
                .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }

                if scrollOffset < -165 {
                    Button { showingCreate = true } label: {
                        Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 54, height: 54)
                            .background(LinearGradient(colors: [DreamGlass.blue, Color(red: 0.07, green: 0.36, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                            .shadow(color: DreamGlass.blue.opacity(0.36), radius: 16, y: 6)
                    }
                    .buttonStyle(.plain).padding(.trailing, 22).padding(.bottom, 22)
                    .transition(.scale.combined(with: .opacity)).accessibilityLabel("Crear proyecto")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingCreate) { createProjectSheet }
            .sheet(isPresented: $showingSettings) { AIProviderSettingsView() }
            .navigationDestination(item: $activeProject) { project in
                ProjectEditorView(project: project) { library.update($0) }
            }
            .onChange(of: showingCreate) { _, isShowing in if !isShowing { projectName = "" } }
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: scrollOffset < -165)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Image("DreamByteLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 49, height: 49)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.22), lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("DreamByte").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("AI STUDIO").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(2.6).foregroundStyle(DreamGlass.cyan)
            }
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 45, height: 45).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain).accessibilityLabel("Configuración de proveedores de IA")
        }.padding(.bottom, 3)
    }

    private var createButton: some View {
        Button { showingCreate = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus").font(.system(size: 17, weight: .bold)).frame(width: 42, height: 42).background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Crear proyecto").font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("Empieza desde cero y añade tus medios").font(.system(size: 12)).foregroundStyle(.white.opacity(0.74))
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
            }
            .foregroundStyle(.white).padding(14)
            .background(LinearGradient(colors: [DreamGlass.blue.opacity(0.96), Color(red: 0.08, green: 0.34, blue: 0.75)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.22), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 23).fill(DreamGlass.blue.opacity(0.11)).frame(width: 82, height: 76)
                Image(systemName: searchText.isEmpty ? "film.stack" : "magnifyingglass").font(.system(size: 31, weight: .light)).foregroundStyle(DreamGlass.cyan)
            }
            Text(searchText.isEmpty ? "Tu próxima edición empieza aquí" : "No encontramos proyectos").font(.headline).foregroundStyle(.white)
            Text(searchText.isEmpty ? "Crea un proyecto, importa tus clips y empieza a construir tu montaje a tu ritmo." : "Prueba con otro nombre o cambia el filtro.")
                .font(.subheadline).foregroundStyle(DreamGlass.muted).multilineTextAlignment(.center).frame(maxWidth: 320)
            if searchText.isEmpty {
                Button("Crear mi primer proyecto") { showingCreate = true }.font(.subheadline.weight(.semibold)).foregroundStyle(DreamGlass.cyan).padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30).padding(.horizontal, 20)
        .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.06), lineWidth: 1))
    }

    private var createProjectSheet: some View {
        NavigationStack {
            ZStack {
                DreamGlass.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "film.stack").font(.system(size: 31, weight: .medium)).foregroundStyle(DreamGlass.cyan)
                        .frame(width: 66, height: 66).background(DreamGlass.blue.opacity(0.13), in: RoundedRectangle(cornerRadius: 20))
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Dale forma a una idea").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text("El proyecto empieza vacío. Tú decides qué importar, cómo editar y cuándo usar herramientas de IA.")
                            .font(.subheadline).foregroundStyle(DreamGlass.muted)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOMBRE DEL PROYECTO").font(.caption.weight(.bold)).tracking(1.3).foregroundStyle(DreamGlass.cyan)
                        TextField("Ej. Mi próximo vídeo", text: $projectName).font(.body).tint(DreamGlass.cyan)
                            .padding(15).background(DreamGlass.panel, in: RoundedRectangle(cornerRadius: 15))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.1), lineWidth: 1))
                    }
                    Spacer()
                    Button {
                        let project = VideoProject(name: projectName)
                        library.add(project)
                        activeProject = project
                        showingCreate = false
                    } label: {
                        HStack { Text("Crear y abrir editor"); Spacer(); Image(systemName: "arrow.right") }
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).padding(17)
                            .background(LinearGradient(colors: [DreamGlass.blue, Color(red: 0.07, green: 0.36, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain)
                }.padding(24)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancelar") { showingCreate = false }.foregroundStyle(DreamGlass.cyan) } }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible).preferredColorScheme(.dark)
    }
}

private struct ProjectCard: View {
    let project: VideoProject
    let onOpen: () -> Void
    let onDelete: () -> Void
    private var dateLabel: String { project.modifiedAt.formatted(date: .abbreviated, time: .omitted) }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 15).fill(LinearGradient(colors: [Color(red: 0.07, green: 0.16, blue: 0.29), Color(red: 0.025, green: 0.075, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Circle().fill(DreamGlass.blue.opacity(0.17)).frame(width: 100, height: 100).offset(x: 16, y: -17)
                    Image(systemName: project.sourceVideoFilename == nil ? "film" : "play.rectangle.fill").font(.system(size: 31, weight: .light)).foregroundStyle(DreamGlass.cyan.opacity(0.9))
                    HStack(spacing: 5) {
                        Circle().fill(project.sourceVideoFilename == nil ? Color.orange : Color.green).frame(width: 6, height: 6)
                        Text(project.sourceVideoFilename == nil ? "BORRADOR" : "MEDIOS").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(0.9).foregroundStyle(.white.opacity(0.82))
                    }
                    .padding(.horizontal, 9).padding(.vertical, 7).background(.black.opacity(0.27), in: Capsule()).padding(10)
                }.frame(height: 125).clipShape(RoundedRectangle(cornerRadius: 15))
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(project.name).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(2).multilineTextAlignment(.leading)
                        Text("Modificado \(dateLabel)").font(.system(size: 11)).foregroundStyle(DreamGlass.muted)
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button(role: .destructive, action: onDelete) { Label("Eliminar proyecto", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold)).foregroundStyle(DreamGlass.muted).frame(width: 30, height: 28).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }.padding(.top, 12).padding(.horizontal, 2).padding(.bottom, 3)
            }
            .padding(11).background(DreamGlass.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 21))
            .overlay(RoundedRectangle(cornerRadius: 21).stroke(.white.opacity(0.075), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
