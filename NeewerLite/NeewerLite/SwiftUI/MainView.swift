import SwiftUI

struct MainView: View {
    var appState: AppState

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
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            // Light cards
            ScrollView {
                if appState.lights.isEmpty {
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
                    .padding(16)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }
}
