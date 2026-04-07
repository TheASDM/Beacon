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
                Picker("Effect", selection: $selectedFXIndex) {
                    ForEach(supportedFX.indices, id: \.self) { index in
                        Text(supportedFX[index].name).tag(index)
                    }
                }

                if let fx = selectedFX {
                    if fx.needSpeed {
                        GradientSlider(
                            value: $speed,
                            range: 1...10,
                            step: 1,
                            gradient: .speed,
                            label: "SPD",
                            valueLabel: "\(Int(speed))"
                        )
                    }

                    if fx.needBRR {
                        GradientSlider(
                            value: $brr,
                            range: 0...100,
                            step: 1,
                            gradient: .brightness,
                            label: "BRR",
                            valueLabel: "\(Int(brr))%"
                        )
                    }

                    if fx.needCCT {
                        GradientSlider(
                            value: $cctVal,
                            range: Double(light.cctRange.min)...Double(light.cctRange.max),
                            step: 1,
                            gradient: .cct,
                            label: "CCT",
                            valueLabel: "\(Int(cctVal))00K"
                        )
                    }

                    if fx.needGM {
                        GradientSlider(
                            value: $gmVal,
                            range: -50...50,
                            step: 1,
                            gradient: .gm,
                            label: "GM",
                            valueLabel: gmVal >= 0 ? "+\(Int(gmVal))" : "\(Int(gmVal))"
                        )
                    }

                    if fx.needHUE {
                        GradientSlider(
                            value: $hueVal,
                            range: 0...360,
                            step: 1,
                            gradient: .hue,
                            label: "HUE",
                            valueLabel: "\(Int(hueVal))\u{00B0}"
                        )
                    }

                    if fx.needSAT {
                        GradientSlider(
                            value: $satVal,
                            range: 0...100,
                            step: 1,
                            gradient: .saturation,
                            label: "SAT",
                            valueLabel: "\(Int(satVal))%"
                        )
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
        guard let fx = selectedFX else { return }
        if fx.needSpeed { fx.speedValue = Int(speed) }
        if fx.needBRR { fx.brrValue = CGFloat(brr) }
        if fx.needCCT { fx.cctValue = CGFloat(cctVal) }
        if fx.needGM { fx.gmValue = CGFloat(gmVal) }
        if fx.needHUE { fx.hueValue = CGFloat(hueVal) }
        if fx.needSAT { fx.satValue = CGFloat(satVal) }
        light.sendScene(fx)
    }
}
