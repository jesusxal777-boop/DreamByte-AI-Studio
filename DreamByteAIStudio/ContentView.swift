import SwiftUI

struct ContentView: View {
    @State private var showingSettings = false

    private let electricBlue = Color(red: 0.12, green: 0.62, blue: 1.0)

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.025, green: 0.055, blue: 0.12), Color(red: 0.015, green: 0.025, blue: 0.065)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        VStack(alignment: .leading, spacing: 10) {
                            Label("WORKSPACE", systemImage: "film.stack")
                                .font(.caption.weight(.bold))
                                .tracking(2)
                                .foregroundStyle(electricBlue)

                            Text("Your next cut starts here.")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Import a video to begin building your timeline. Editing tools are being developed in stages.")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 1))

                        Button {
                            showingSettings = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "key.horizontal")
                                    .font(.title2)
                                    .foregroundStyle(electricBlue)
                                    .frame(width: 48, height: 48)
                                    .background(electricBlue.opacity(0.13), in: RoundedRectangle(cornerRadius: 15))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("AI Provider Settings")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("Add your own API keys on this device")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.65))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(16)
                            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(electricBlue)
                            Text("No API keys are bundled with this app. You decide which providers to configure. Keys are stored in the iOS Keychain on this device and are never written into project files.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(20)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSettings) {
                AIProviderSettingsView()
            }
        }
        .tint(electricBlue)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [electricBlue, Color(red: 0.1, green: 0.35, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "waveform.path")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text("DreamByte")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("AI STUDIO")
                    .font(.caption.weight(.heavy))
                    .tracking(3)
                    .foregroundStyle(electricBlue)
            }
            Spacer()
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityLabel("AI provider settings")
        }
    }
}
