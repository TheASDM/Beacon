//
//  LightViewModel.swift
//  Beacon
//
//  Bridges the existing NeewerLight model (which uses a custom Observable<T>
//  callback pattern) to SwiftUI's Observation framework, without modifying
//  NeewerLight.swift.
//

import Foundation
import Observation
import CoreBluetooth
import AppKit

@Observable
class LightViewModel: Identifiable {

    let device: NeewerLight

    var id: String { device.identifier }

    // MARK: - Mirrored Observable state (SwiftUI will track these)

    var isOn: Bool = false
    var brightness: Int = 50
    var cct: Int = 53
    var hue: Int = 0
    var saturation: Int = 0
    var gm: Int = -50
    var channel: UInt8 = 1
    var userName: String = ""
    var supportGM: Bool = false
    var selectedMode: NeewerLight.Mode = .CCTMode

    // MARK: - Convenience computed properties

    var displayName: String {
        let custom = device.userLightName.value
        if !custom.isEmpty { return custom }
        return device.nickName
    }

    var isConnected: Bool {
        device.peripheral?.state == .connected
    }

    var hasMac: Bool {
        device.hasMAC()
    }

    var cctRange: (min: Int, max: Int) {
        let range = device.CCTRange()
        return (min: range.minCCT, max: range.maxCCT)
    }

    // MARK: - Initializer

    init(device: NeewerLight) {
        self.device = device

        // Seed local state from current device values
        self.isOn = device.isOn.value
        self.brightness = device.brrValue.value
        self.cct = device.cctValue.value
        self.hue = device.hueValue.value
        self.saturation = device.satValue.value
        self.gm = device.gmmValue.value
        self.channel = device.channel.value
        self.userName = device.userLightName.value
        self.supportGM = device.supportGMRange.value
        self.selectedMode = device.lightMode

        // Bind each Observable<T> so BLE-driven changes propagate to SwiftUI.
        // Dispatching to main ensures thread safety since BLE callbacks can
        // arrive on arbitrary queues.

        device.isOn.bind { [weak self] value in
            DispatchQueue.main.async { self?.isOn = value }
        }

        device.brrValue.bind { [weak self] value in
            DispatchQueue.main.async { self?.brightness = value }
        }

        device.cctValue.bind { [weak self] value in
            DispatchQueue.main.async { self?.cct = value }
        }

        device.hueValue.bind { [weak self] value in
            DispatchQueue.main.async { self?.hue = value }
        }

        device.satValue.bind { [weak self] value in
            DispatchQueue.main.async { self?.saturation = value }
        }

        device.gmmValue.bind { [weak self] value in
            DispatchQueue.main.async { self?.gm = value }
        }

        device.channel.bind { [weak self] value in
            DispatchQueue.main.async { self?.channel = value }
        }

        device.userLightName.bind { [weak self] value in
            DispatchQueue.main.async { self?.userName = value }
        }

        device.supportGMRange.bind { [weak self] value in
            DispatchQueue.main.async { self?.supportGM = value }
        }
    }

    // MARK: - Control methods (delegate to device)

    func togglePower() {
        Logger.debug("[\(device.rawName)] togglePower: peripheral=\(device.peripheral != nil), characteristic=\(device.deviceCtlCharacteristic != nil)")
        if device.isOn.value {
            device.sendPowerOffRequest()
        } else {
            device.sendPowerOnRequest()
        }
    }

    func setBrightness(_ value: CGFloat) {
        let clamped = CGFloat(Int(value).clamped(to: 0...100))
        // Delegate to the appropriate mode command so the brightness is sent
        // together with the current mode parameters.
        switch device.lightMode {
        case .CCTMode:
            device.setCCTLightValues(brr: clamped, cct: CGFloat(device.cctValue.value), gmm: CGFloat(device.gmmValue.value))
        case .HSIMode:
            device.setHSILightValues(brr100: clamped, hue: CGFloat(device.hueValue.value) / 360.0, hue360: CGFloat(device.hueValue.value), sat: CGFloat(device.satValue.value) / 100.0)
        default:
            break
        }
    }

    func setCCT(brr: CGFloat, cct: CGFloat, gm: CGFloat) {
        device.setCCTLightValues(brr: brr, cct: cct, gmm: gm)
    }

    func setHSI(brr: CGFloat, hue: CGFloat, sat: CGFloat) {
        device.setHSILightValues(brr100: brr, hue: hue / 360.0, hue360: hue, sat: sat / 100.0)
    }

    func sendScene(_ fx: NeewerLightFX) {
        device.sendSceneCommand(fx)
    }

    func sendSourceCommand(_ pattern: String) {
        device.sendCommandPattern(pattern)
    }

    func rename(_ name: String) {
        device.userLightName.value = name
    }

    func forget() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.forgetLight(device)
        AppState.shared.removeLight(identifier: id)
    }
}
