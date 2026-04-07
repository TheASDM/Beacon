import SwiftUI

struct HSIModeView: View {
    var light: LightViewModel

    @State private var hueVal: Double = 0
    @State private var satVal: Double = 100
    @State private var brr: Double = 50

    var body: some View {
        VStack(spacing: 12) {
            // Hue
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Hue")
                    Spacer()
                    Text("\(Int(hueVal))\u{00B0}")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $hueVal, in: 0...360, step: 1)
            }

            // Saturation
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Saturation")
                    Spacer()
                    Text("\(Int(satVal))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $satVal, in: 0...100, step: 1)
            }

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
        }
        .onAppear {
            hueVal = Double(light.hue)
            satVal = Double(light.saturation)
            brr = Double(light.brightness)
        }
        .onChange(of: hueVal) { sendHSI() }
        .onChange(of: satVal) { sendHSI() }
        .onChange(of: brr) { sendHSI() }
    }

    private func sendHSI() {
        light.setHSI(brr: CGFloat(brr), hue: CGFloat(hueVal), sat: CGFloat(satVal))
    }
}
