//
//  AppState.swift
//  NeewerLite
//
//  Top-level SwiftUI-facing container for the light collection.
//  The actual BLE management stays in AppDelegate; this class is
//  simply the observable state that SwiftUI views bind to.
//

import Foundation
import Observation

@Observable
class AppState {

    var lights: [LightViewModel] = []
    var isScanning: Bool = false

    static let shared = AppState()

    func addLight(_ device: NeewerLight) {
        guard !lights.contains(where: { $0.device.identifier == device.identifier }) else { return }
        lights.append(LightViewModel(device: device))
    }

    func removeLight(identifier: String) {
        lights.removeAll { $0.id == identifier }
    }

    func findLight(identifier: String) -> LightViewModel? {
        lights.first { $0.id == identifier }
    }
}
