import SwiftUI

struct LightCardView: View {
    var light: LightViewModel
    @State private var selectedTab: String = "cct"

    var body: some View {
        VStack(spacing: 0) {
            // Header: name + power toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(light.displayName)
                        .font(.headline)
                    Text(light.device.nickName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Connection indicator
                if !light.isConnected {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.red)
                }
                // Power toggle
                Toggle("", isOn: Binding(
                    get: { light.isOn },
                    set: { _ in light.togglePower() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Tab picker
            Picker("Mode", selection: $selectedTab) {
                Text("CCT").tag("cct")
                if light.device.supportRGB {
                    Text("HSI").tag("hsi")
                }
                Text("Source").tag("source")
                if !light.device.supportedFX.isEmpty {
                    Text("FX").tag("fx")
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Mode content
            Group {
                switch selectedTab {
                case "cct":
                    CCTModeView(light: light)
                case "hsi":
                    HSIModeView(light: light)
                case "source":
                    SourceModeView(light: light)
                case "fx":
                    FXModeView(light: light)
                default:
                    CCTModeView(light: light)
                }
            }
            .padding(16)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .onAppear {
            // Sync tab with device's current mode
            switch light.selectedMode {
            case .CCTMode: selectedTab = "cct"
            case .HSIMode: selectedTab = "hsi"
            case .SCEMode: selectedTab = "fx"
            case .SRCMode: selectedTab = "source"
            }
        }
        .contextMenu {
            Button("Rename...") { /* TODO: rename sheet */ }
            if let link = light.device.productLink {
                Button("Product Page") {
                    if let url = URL(string: link) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
