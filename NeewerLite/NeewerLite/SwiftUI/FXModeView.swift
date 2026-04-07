import SwiftUI

struct FXModeView: View {
    var light: LightViewModel

    @State private var selectedFXIndex: Int = 0
    @State private var speed: Double = 5
    @State private var brr: Double = 50
    @State private var cctVal: Double = 53
    @State private var gmVal: Double = 0
    @State private var hueVal: Double = 0
    @State private var satVal: Double = 100

    private var supportedFX: [NeewerLightFX] {
        light.device.supportedFX
    }

    private var selectedFX: NeewerLightFX? {
        guard !supportedFX.isEmpty,
              selectedFXIndex >= 0,
              selectedFXIndex < supportedFX.count else { return nil }
        return supportedFX[selectedFXIndex]
    }

    var body: some View {
        VStack(spacing: 12) {
            if supportedFX.isEmpty {
                Text("No effects available for this light.")
                    .foregroundStyle(.secondary)
            } else {
                // FX picker
                Picker("Effect", selection: $selectedFXIndex) {
                    ForEach(supportedFX.indices, id: \.self) { index in
                        Text(supportedFX[index].name).tag(index)
                    }
                }

                if let fx = selectedFX {
                    // Speed
                    if fx.needSpeed {
                        sliderRow(label: "Speed", value: $speed, range: 1...10, step: 1, suffix: "")
                    }

                    // Brightness
                    if fx.needBRR {
                        sliderRow(label: "Brightness", value: $brr, range: 0...100, step: 1, suffix: "%")
                    }

                    // CCT
                    if fx.needCCT {
                        sliderRow(
                            label: "Temperature",
                            value: $cctVal,
                            range: Double(light.cctRange.min)...Double(light.cctRange.max),
                            step: 1,
                            suffix: "00K"
                        )
                    }

                    // GM
                    if fx.needGM {
                        gmSliderRow()
                    }

                    // Hue
                    if fx.needHUE {
                        sliderRow(label: "Hue", value: $hueVal, range: 0...360, step: 1, suffix: "\u{00B0}")
                    }

                    // Saturation
                    if fx.needSAT {
                        sliderRow(label: "Saturation", value: $satVal, range: 0...100, step: 1, suffix: "%")
                    }
                }
            }
        }
        .onAppear {
            syncFromFX()
        }
        .onChange(of: selectedFXIndex) {
            syncFromFX()
            sendFX()
        }
        .onChange(of: speed) { sendFX() }
        .onChange(of: brr) { sendFX() }
        .onChange(of: cctVal) { sendFX() }
        .onChange(of: gmVal) { sendFX() }
        .onChange(of: hueVal) { sendFX() }
        .onChange(of: satVal) { sendFX() }
    }

    // MARK: - Slider Helpers

    private func sliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value.wrappedValue))\(suffix)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func gmSliderRow() -> some View {
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

    // MARK: - Sync & Send

    private func syncFromFX() {
        guard let fx = selectedFX else { return }
        if fx.needSpeed { speed = Double(fx.speedValue) }
        if fx.needBRR { brr = Double(fx.brrValue) }
        if fx.needCCT { cctVal = Double(fx.cctValue) }
        if fx.needGM { gmVal = Double(fx.gmValue) }
        if fx.needHUE { hueVal = Double(fx.hueValue) }
        if fx.needSAT { satVal = Double(fx.satValue) }
    }

    private func sendFX() {
        guard var fx = selectedFX else { return }
        if fx.needSpeed { fx.featureValues["speed"] = CGFloat(speed) }
        if fx.needBRR { fx.featureValues["brr"] = CGFloat(brr) }
        if fx.needCCT { fx.featureValues["cct"] = CGFloat(cctVal) }
        if fx.needGM { fx.featureValues["gm"] = CGFloat(gmVal) }
        if fx.needHUE { fx.featureValues["hue"] = CGFloat(hueVal) }
        if fx.needSAT { fx.featureValues["sat"] = CGFloat(satVal) }
        light.sendScene(fx)
    }
}
