//
//  CBCharacteristicExtensions.swift
//  Beacon
//
//  Created by Xu Lian on 1/16/21.
//

import Foundation
import CoreBluetooth

extension CBCharacteristic {

    public func propertyEnabled(_ property: CBCharacteristicProperties) -> Bool {
        return (self.properties.rawValue & property.rawValue) > 0
    }

    public var canNotify: Bool {
        return propertyEnabled(.notify) || propertyEnabled(.indicate) || propertyEnabled(.notifyEncryptionRequired) || propertyEnabled(.indicateEncryptionRequired)
    }

    public var canRead: Bool {
        return propertyEnabled(.read)
    }

    public var canWrite: Bool {
        return propertyEnabled(.write) || self.propertyEnabled(.writeWithoutResponse)
    }
}

func getConnectedBluetoothDevices() -> [[String: String]]? {
    let task = Process()
    task.launchPath = "/usr/sbin/system_profiler"
    task.arguments = ["SPBluetoothDataType"]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()

    guard let output = String(data: data, encoding: .utf8) else {
        Logger.warn(LogTag.bluetooth, "getConnectedBluetoothDevices: failed to read output")
        return nil
    }

    // Parse the text output line by line
    // Format:
    //   Connected:
    //       DeviceName:
    //           Address: AA:BB:CC:DD:EE:FF
    var result: [[String: String]] = []
    let lines = output.components(separatedBy: "\n")
    var inConnectedSection = false
    var currentDeviceName: String? = nil

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed == "Connected:" || trimmed == "device_connected:" {
            inConnectedSection = true
            continue
        }
        if trimmed == "Not Connected:" || trimmed == "device_not_connected:" || trimmed.isEmpty {
            if trimmed == "Not Connected:" || trimmed == "device_not_connected:" {
                inConnectedSection = false
                currentDeviceName = nil
            }
            continue
        }

        if inConnectedSection {
            if trimmed.hasSuffix(":") && !trimmed.hasPrefix("Address") && !trimmed.hasPrefix("Services")
                && !trimmed.hasPrefix("Minor") && !trimmed.hasPrefix("Major") && !trimmed.hasPrefix("Vendor")
                && !trimmed.hasPrefix("Firmware") && !trimmed.hasPrefix("Manufacturer") {
                // This is a device name line
                currentDeviceName = String(trimmed.dropLast()) // remove trailing ":"
            } else if trimmed.hasPrefix("Address:"), let name = currentDeviceName {
                let address = trimmed.replacingOccurrences(of: "Address: ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                result.append(["name": name, "device_address": address])
            }
        }
    }

    if result.isEmpty {
        Logger.info(LogTag.bluetooth, "getConnectedBluetoothDevices: no connected devices found")
    }

    return result.isEmpty ? nil : result
}
