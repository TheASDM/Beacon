import SwiftUI
import AppKit

struct MainView: View {
    var appState: AppState
    @State private var scanTimeRemaining: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("NeewerLite")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(appState.lights.count) light\(appState.lights.count == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
                    .font(.callout)

                Button {
                    triggerScan()
                } label: {
                    if appState.isScanning {
                        Label("Scanning \(scanTimeRemaining)s", systemImage: "antenna.radiowaves.left.and.right")
                    } else {
                        Label("Scan", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                .disabled(appState.isScanning)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Discovered lights (pending connection)
                    if !appState.discoveredLights.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Discovered")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            ForEach(appState.discoveredLights) { light in
                                HStack {
                                    Image(systemName: "lightbulb")
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading) {
                                        Text(light.displayName)
                                            .font(.body)
                                        Text(light.device.nickName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Add") {
                                        connectDiscoveredLight(light)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                                .padding(10)
                                .background(.background)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    // Connected lights
                    if appState.lights.isEmpty && appState.discoveredLights.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "lightbulb.slash")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No lights connected")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Click Scan to find nearby Neewer lights")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Button("Scan for Lights") {
                                triggerScan()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340, maximum: 520))], spacing: 16) {
                            ForEach(appState.lights) { light in
                                LightCardView(light: light)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, appState.discoveredLights.isEmpty ? 12 : 0)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }

    private func triggerScan() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appState.isScanning = true
        scanTimeRemaining = 10
        appDelegate.scanningNewLightMode = true
        appDelegate.scanningViewObjects.removeAll()
        appDelegate.scanAction(NSButton())
        // Countdown timer
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            scanTimeRemaining -= 1
            if scanTimeRemaining <= 0 {
                timer.invalidate()
                appDelegate.scanningNewLightMode = false
                appState.isScanning = false
            }
        }
    }

    private func connectDiscoveredLight(_ light: LightViewModel) {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        // Find matching DeviceViewObject in AppDelegate's scanningViewObjects
        if let idx = appDelegate.scanningViewObjects.firstIndex(where: {
            $0.deviceIdentifier == light.id
        }) {
            let viewObj = appDelegate.scanningViewObjects.remove(at: idx)
            appDelegate.viewObjects.append(viewObj)
            appDelegate.saveLightsToDisk()
        }
        appState.connectDiscoveredLight(light)
    }
}
