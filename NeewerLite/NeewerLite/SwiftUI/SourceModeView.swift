import SwiftUI

struct SourceModeView: View {
    var light: LightViewModel

    @State private var selectedSourceIndex: Int = 0
    @State private var brr: Double = 50
    @State private var cctVal: Double = 53
    @State private var gmVal: Double = 0

    private var supportedSources: [NeewerLightSource] {
        light.device.supportedSource
    }

    private var selectedSource: NeewerLightSource? {
        guard !supportedSources.isEmpty,
              selectedSourceIndex >= 0,
              selectedSourceIndex < supportedSources.count else { return nil }
        return supportedSources[selectedSourceIndex]
    }

    var body: some View {
        VStack(spacing: 12) {
            if supportedSources.isEmpty {
                Text("No sources available for this light.")
                    .foregroundStyle(.secondary)
            } else {
                // Source picker
                Picker("Source", selection: $selectedSourceIndex) {
                    ForEach(supportedSources.indices, id: \.self) { index in
                        Text(supportedSources[index].name).tag(index)
                    }
                }

                if let source = selectedSource {
                    // Brightness
                    if source.needBRR {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Brightness")
                                Spacer()
                                Text("\(Int(brr))%")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $brr, in: 0...100, step: 1)
                        }
                    }

                    // CCT
                    if source.needCCT {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Temperature")
                                Spacer()
                                Text("\(Int(cctVal))00K")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(
                                value: $cctVal,
                                in: Double(light.cctRange.min)...Double(light.cctRange.max),
                                step: 1
                            )
                        }
                    }

                    // GM
                    if source.needGM {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("GM")
                                Spacer()
                                Text(gmVal >= 0 ? "+\(Int(gmVal))" : "\(Int(gmVal))")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $gmVal, in: -50...50, step: 1)
                        }
                    }
                }
            }
        }
        .onAppear {
            brr = Double(light.brightness)
            cctVal = Double(light.cct)
            gmVal = Double(light.gm)
        }
        .onChange(of: selectedSourceIndex) {
            guard let source = selectedSource,
                  let pattern = source.defaultCmdPattern else { return }
            light.sendSourceCommand(pattern)
        }
        .onChange(of: brr) { sendCCT() }
        .onChange(of: cctVal) { sendCCT() }
        .onChange(of: gmVal) { sendCCT() }
    }

    private func sendCCT() {
        light.setCCT(brr: CGFloat(brr), cct: CGFloat(cctVal), gm: CGFloat(gmVal))
    }
}
