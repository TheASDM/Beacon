import SwiftUI

struct CCTModeView: View {
    var light: LightViewModel

    @State private var brr: Double = 50
    @State private var cctVal: Double = 53
    @State private var gmVal: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            // Brightness
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

            // CCT
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

            // GM (only if supported)
            if light.supportGM {
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
        .onAppear {
            brr = Double(light.brightness)
            cctVal = Double(light.cct)
            gmVal = Double(light.gm)
        }
        .onChange(of: brr) { sendCCT() }
        .onChange(of: cctVal) { sendCCT() }
        .onChange(of: gmVal) { sendCCT() }
    }

    private func sendCCT() {
        light.setCCT(brr: CGFloat(brr), cct: CGFloat(cctVal), gm: CGFloat(gmVal))
    }
}
