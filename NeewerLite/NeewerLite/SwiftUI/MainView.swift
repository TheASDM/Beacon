import SwiftUI

struct MainView: View {
    var appState: AppState

    var body: some View {
        ScrollView {
            if appState.lights.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "lightbulb.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No lights connected")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Make sure your Neewer lights are powered on and in range")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340, maximum: 520))], spacing: 16) {
                    ForEach(appState.lights) { light in
                        LightCardView(light: light)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 380, minHeight: 300)
    }
}
