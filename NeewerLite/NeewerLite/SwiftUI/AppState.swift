//
//  AppState.swift
//  Beacon
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
    var discoveredLights: [LightViewModel] = []
    var isScanning: Bool = false

    static let shared = AppState()

    /// Called from AppDelegate when a new light is discovered during scan
    func addDiscoveredLight(_ device: NeewerLight) {
        let id = device.identifier
        guard !lights.contains(where: { $0.device.identifier == id }) else { return }
        guard !discoveredLights.contains(where: { $0.device.identifier == id }) else { return }
        discoveredLights.append(LightViewModel(device: device))
    }

    /// Move a discovered light to the connected lights list
    func connectDiscoveredLight(_ light: LightViewModel) {
        discoveredLights.removeAll { $0.id == light.id }
        if !lights.contains(where: { $0.id == light.id }) {
            lights.append(light)
        }
    }

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
