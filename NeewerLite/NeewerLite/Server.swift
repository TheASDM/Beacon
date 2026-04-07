import Foundation
import AppKit
import Swifter


extension DeviceViewObject {
    /// Matches a lightId against userLightName, rawName, or identifier (case-insensitive)
    func matches(lightId: String) -> Bool {
        let lower = lightId.lowercased()
        return device.userLightName.value.lowercased() == lower
            || device.rawName.lowercased()          == lower
            || device.identifier.lowercased()       == lower
    }
}

final class BeaconServer {
    private let server = HttpServer()
    private let port: in_port_t
    private let appDelegate: AppDelegate?
    public var user_agent: String?
    
    init(appDelegate: AppDelegate, port: in_port_t = 18486) {
        self.appDelegate = appDelegate
        self.port = port
        setupRoutes()
    }

    deinit {
        stop()
    }
    
    /// Configure HTTP routes
    private func setupRoutes() {
        
        server.middleware.append { request in
            guard let ua = request.headers["user-agent"] else {
                // No UA header → reject
                return HttpResponse.unauthorized
            }
            if !ua.starts(with: "neewerlite.sdPlugin/")
            {
                return HttpResponse.unauthorized
            }
            // return nil to let the request continue on to your handlers
            return nil
        }
        
        // GET /listLights → returns lights array with full state
        server.GET["/listLights"] = { _ in
            var lights: [[String: Any]] = []
            self.appDelegate?.viewObjects.forEach {
                let dev = $0.device
                let name = dev.userLightName.value.isEmpty ? dev.rawName : dev.userLightName.value
                let cct = "\(dev.CCTRange().minCCT)-\(dev.CCTRange().maxCCT)"
                var item = ["id": "\(dev.identifier)", "name": name, "cctRange": "\(cct)"]
                item["brightness"] = "\(dev.brrValue.value)"
                item["temperature"] = "\(dev.cctValue.value)"
                item["gmm"] = "\(dev.gmmValue.value)"
                item["hue"] = "\(dev.hueValue.value)"
                item["sat"] = "\(dev.satValue.value)"
                item["supportRGB"] = "\(dev.supportRGB ? 1 : 0)"
                item["maxChannel"] = "\(dev.maxChannel)"
                item["supportGM"] = "\(dev.supportCCTGM ? 1 : 0)"
                // Current mode
                switch dev.lightMode {
                case .CCTMode: item["mode"] = "cct"
                case .HSIMode: item["mode"] = "hsi"
                case .SCEMode: item["mode"] = "sce"
                case .SRCMode: item["mode"] = "src"
                }
                // Current FX/source info
                item["fxId"] = "\(dev.channel.value)"
                if let currentFx = dev.supportedFX.first(where: { $0.id == dev.channel.value }) {
                    item["fxName"] = currentFx.name
                }
                item["fxCount"] = "\(dev.supportedFX.count)"
                item["sourceCount"] = "\(dev.supportedSource.count)"
                if !$0.deviceConnected
                {
                    item["state"] = "-1"
                }
                else if dev.isOn.value
                {
                    item["state"] = "1"
                }
                else
                {
                    item["state"] = "0"
                }
                lights.append(item)
            }
            let payload: [String: Any] = ["lights": lights]
            return HttpResponse.ok(.json(payload))
        }

        // GET /ping → health check
        server.GET["/ping"] = { _ in
            // Logger.info(LogTag.server, "Received /ping")
            return HttpResponse.ok(.json(["status": "pong"]))
        }

        // 4. Switch lights endpoint
        //    Expects JSON payload: { "lights": ["Front", "Back"] }
        server.POST["/switch"] = { request in
            Logger.info(LogTag.server, "Received /switch request")
            let data = Data(request.body)
            struct SwitchPayload: Codable {
                let lights: [String]
                let state: Bool
            }
            let payload: SwitchPayload
            do {
                payload = try JSONDecoder().decode(SwitchPayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/switch: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error", "invalid JSON"]))
            }
            // Perform your switch logic here
            Logger.info(LogTag.server, "Switching lights: \(payload.lights) state: \(payload.state)")
            for light in payload.lights {
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .forEach { viewObj in
                        Task { @MainActor in
                            if payload.state {
                                if !viewObj.isON {
                                    viewObj.toggleLight()
                                }
                            }
                            else{
                                if viewObj.isON {
                                    viewObj.toggleLight()
                                }
                            }
                        }
                    }
            }
            // Respond with success and echoed list
            return HttpResponse.ok(.json(["success": true, "switched": payload.lights]))
        }

        server.POST["/brightness"] = { request in
            let data = Data(request.body)
            struct BrightnessPayload: Codable {
                let lights: [String]
                let brightness: CGFloat
            }
            let payload: BrightnessPayload
            do {
                payload = try JSONDecoder().decode(BrightnessPayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/switch: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error", "invalid JSON"]))
            }
            // Perform your switch logic here
            for light in payload.lights {
                Logger.info(LogTag.server, "light: \(light)")
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .forEach { viewObj in
                        Task { @MainActor in
                            viewObj.device.setBRR100LightValues(payload.brightness)
                        }
                    }
            }
            // Respond with success and echoed list
            return HttpResponse.ok(.json(["success": true, "switched": payload.lights]))
        }
        
        server.POST["/temperature"] = { request in
            let data = Data(request.body)
            struct TemperaturePayload: Codable {
                let lights: [String]
                let temperature: CGFloat
            }
            let payload: TemperaturePayload
            do {
                payload = try JSONDecoder().decode(TemperaturePayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/switch: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error", "invalid JSON"]))
            }
            // Perform your switch logic here
            for light in payload.lights {
                Logger.info(LogTag.server, "light: \(light)")
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .forEach { viewObj in
                       Task { @MainActor in
                            viewObj.device.setCCTLightValues(brr: CGFloat(viewObj.device.brrValue.value), cct: CGFloat(payload.temperature), gmm: CGFloat(viewObj.device.gmmValue.value))
                        }
                    }
            }
            // Respond with success and echoed list
            return HttpResponse.ok(.json(["success": true, "switched": payload.lights]))
        }

        server.POST["/cct"] = { request in
            let data = Data(request.body)
            struct BrightnessPayload: Codable {
                let lights: [String]
                let brightness: CGFloat
                let temperature: CGFloat
            }
            let payload: BrightnessPayload
            do {
                payload = try JSONDecoder().decode(BrightnessPayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/switch: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error", "invalid JSON"]))
            }
            // Perform your switch logic here
            for light in payload.lights {
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .forEach { viewObj in
                         Task { @MainActor in
                            viewObj.changeToCCTMode()
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            viewObj.device.setCCTLightValues(brr: CGFloat(payload.brightness), cct: CGFloat(payload.temperature), gmm: CGFloat(viewObj.device.gmmValue.value))
                        }
                    }
            }
            // Respond with success and echoed list
            return HttpResponse.ok(.json(["success": true, "switched": payload.lights]))
        }
        
        server.POST["/hst"] = { request in
            let data = Data(request.body)
            struct BrightnessPayload: Codable {
                let lights: [String]
                let brightness: CGFloat
                let saturation: CGFloat
                let hex_color: String
            }
            let payload: BrightnessPayload
            do {
                payload = try JSONDecoder().decode(BrightnessPayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/switch: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error", "invalid JSON"]))
            }
            let color = NSColor(hex: payload.hex_color, alpha: 1)
            let hueVal = CGFloat(color.hueComponent * 360.0)
            let satVal = CGFloat(payload.saturation / 100.0)
            // Perform your switch logic here
            for light in payload.lights {
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .forEach { viewObj in
                        if viewObj.device.supportRGB {
                            Task { @MainActor in
                                viewObj.changeToHSIMode()
                                try? await Task.sleep(nanoseconds: 100_000_000)
                                viewObj.updateHSI(hue: hueVal, sat: satVal, brr: CGFloat(payload.brightness))
                            }
                        }
                    }
            }
            // Respond with success and echoed list
            return HttpResponse.ok(.json(["success": true, "switched": payload.lights]))
        }
        
        server.POST["/hue"] = { request in
            let data = Data(request.body)
            struct BrightnessPayload: Codable {
                let lights: [String]
                let hue: CGFloat  // 0-100
            }
            let payload: BrightnessPayload
            do {
                payload = try JSONDecoder().decode(BrightnessPayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/switch: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error", "invalid JSON"]))
            }
            let hueVal = payload.hue / 100.0 * 360.0
            // Perform your switch logic here
            for light in payload.lights {
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .filter { $0.device.supportRGB }
                    .forEach { viewObj in
                        Task { @MainActor in
                            viewObj.changeToHSIMode()
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            viewObj.updateHSI(hue: hueVal, sat: CGFloat(viewObj.device.satValue.value), brr: CGFloat(viewObj.device.brrValue.value))
                        }
                    }
            }
            // Respond with success and echoed list
            return HttpResponse.ok(.json(["success": true, "switched": payload.lights]))
        }
        
        server.POST["/sat"] = { request in
            let data = Data(request.body)
            struct BrightnessPayload: Codable {
                let lights: [String]
                let saturation: CGFloat  // 0-100
            }
            let payload: BrightnessPayload
            do {
                payload = try JSONDecoder().decode(BrightnessPayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/switch: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error", "invalid JSON"]))
            }
            // Perform your switch logic here
            let satVal = CGFloat(payload.saturation / 100.0)
            Logger.info(LogTag.server, "cct lights: \(payload.lights) saturation: \(payload.saturation) satVal: \(satVal)")
            for light in payload.lights {
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .filter { $0.device.supportRGB }
                    .forEach { viewObj in
                        Task { @MainActor in
                            viewObj.changeToHSIMode()
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            viewObj.updateHSI(hue: CGFloat(viewObj.device.hueValue.value), sat: satVal, brr: CGFloat(viewObj.device.brrValue.value))
                        }
                    }
            }
            // Respond with success and echoed list
            return HttpResponse.ok(.json(["success": true, "switched": payload.lights]))
        }
        
        server.POST["/fx"] = { request in
            let data = Data(request.body)
            struct BrightnessPayload: Codable {
                let lights: [String]
                let fx9: Int  // 1-9
                let fx17: Int  // 1-17
            }
            let payload: BrightnessPayload
            do {
                payload = try JSONDecoder().decode(BrightnessPayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/switch: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error", "invalid JSON"]))
            }
            // Perform your switch logic here
            Logger.debug(LogTag.server, "cct lights: \(payload.lights) fx9: \(payload.fx9) fx17: \(payload.fx17)")
            for light in payload.lights {
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .forEach { viewObj in
                         if viewObj.device.maxChannel == 9 {
                            if payload.fx9 > 0 && payload.fx9 <= viewObj.device.maxChannel {
                                Task { @MainActor in
                                    viewObj.changeToSCEMode()
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                    viewObj.changeToSCE(payload.fx9, CGFloat(viewObj.device.brrValue.value))
                                }
                            }
                        }
                        else if viewObj.device.maxChannel == 17 {
                            if payload.fx17 > 0 && payload.fx17 <= viewObj.device.maxChannel {
                                Task { @MainActor in
                                    viewObj.changeToSCEMode()
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                    viewObj.changeToSCE(payload.fx17, CGFloat(viewObj.device.brrValue.value))
                                }
                            }
                        }
                    }
            }
            // Respond with success and echoed list
            return HttpResponse.ok(.json(["success": true, "switched": payload.lights]))
        }
        
        // POST /gm → set green-magenta value
        server.POST["/gm"] = { request in
            let data = Data(request.body)
            struct GMPayload: Codable {
                let lights: [String]
                let gmm: CGFloat  // -50 to +50
            }
            let payload: GMPayload
            do {
                payload = try JSONDecoder().decode(GMPayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/gm: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error": "invalid JSON"]))
            }
            for light in payload.lights {
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .forEach { viewObj in
                        Task { @MainActor in
                            viewObj.device.setCCTLightValues(
                                brr: CGFloat(viewObj.device.brrValue.value),
                                cct: CGFloat(viewObj.device.cctValue.value),
                                gmm: CGFloat(payload.gmm))
                        }
                    }
            }
            return HttpResponse.ok(.json(["success": true, "switched": payload.lights]))
        }

        // POST /mode → switch light mode
        server.POST["/mode"] = { request in
            let data = Data(request.body)
            struct ModePayload: Codable {
                let lights: [String]
                let mode: String  // "cct", "hsi", "sce"
            }
            let payload: ModePayload
            do {
                payload = try JSONDecoder().decode(ModePayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/mode: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error": "invalid JSON"]))
            }
            for light in payload.lights {
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .forEach { viewObj in
                        Task { @MainActor in
                            switch payload.mode {
                            case "cct":
                                viewObj.changeToCCTMode()
                            case "hsi":
                                viewObj.changeToHSIMode()
                            case "sce":
                                viewObj.changeToSCEMode()
                            default:
                                Logger.error(LogTag.server, "/mode: unknown mode \(payload.mode)")
                            }
                        }
                    }
            }
            return HttpResponse.ok(.json(["success": true, "switched": payload.lights, "mode": payload.mode]))
        }

        // POST /fxnext → cycle to next/prev FX effect
        server.POST["/fxnext"] = { request in
            let data = Data(request.body)
            struct FXNextPayload: Codable {
                let lights: [String]
                let direction: Int  // 1 = next, -1 = prev
            }
            let payload: FXNextPayload
            do {
                payload = try JSONDecoder().decode(FXNextPayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/fxnext: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error": "invalid JSON"]))
            }
            var resultFxId: Int = 0
            var resultFxName: String = ""
            for light in payload.lights {
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .forEach { viewObj in
                        let dev = viewObj.device
                        let fxs = dev.supportedFX
                        guard !fxs.isEmpty else { return }
                        let currentId = Int(dev.channel.value)
                        let currentIdx = fxs.firstIndex(where: { $0.id == currentId }) ?? 0
                        var nextIdx = currentIdx + payload.direction
                        if nextIdx >= fxs.count { nextIdx = 0 }
                        if nextIdx < 0 { nextIdx = fxs.count - 1 }
                        let nextFx = fxs[nextIdx]
                        resultFxId = Int(nextFx.id)
                        resultFxName = nextFx.name
                        Task { @MainActor in
                            viewObj.changeToSCEMode()
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            dev.sendSceneCommand(nextFx)
                        }
                    }
            }
            return HttpResponse.ok(.json([
                "success": true, "switched": payload.lights,
                "fxId": resultFxId, "fxName": resultFxName
            ] as [String: Any]))
        }

        // POST /fxspeed → adjust FX speed and resend
        server.POST["/fxspeed"] = { request in
            let data = Data(request.body)
            struct FXSpeedPayload: Codable {
                let lights: [String]
                let speed: Int  // 1-10
            }
            let payload: FXSpeedPayload
            do {
                payload = try JSONDecoder().decode(FXSpeedPayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/fxspeed: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error": "invalid JSON"]))
            }
            for light in payload.lights {
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .forEach { viewObj in
                        let dev = viewObj.device
                        let currentId = Int(dev.channel.value)
                        if let currentFx = dev.supportedFX.first(where: { $0.id == currentId }) {
                            currentFx.featureValues["speed"] = CGFloat(payload.speed)
                            Task { @MainActor in
                                dev.sendSceneCommand(currentFx)
                            }
                        }
                    }
            }
            return HttpResponse.ok(.json(["success": true, "switched": payload.lights]))
        }

        // POST /source → cycle through light sources
        server.POST["/source"] = { request in
            let data = Data(request.body)
            struct SourcePayload: Codable {
                let lights: [String]
                let direction: Int  // 1 = next, -1 = prev
            }
            let payload: SourcePayload
            do {
                payload = try JSONDecoder().decode(SourcePayload.self, from: data)
            } catch {
                Logger.error(LogTag.server, "/source: invalid JSON - \(error)")
                return HttpResponse.badRequest(.json(["error": "invalid JSON"]))
            }
            var resultSourceId: Int = 0
            var resultSourceName: String = ""
            for light in payload.lights {
                self.appDelegate?.viewObjects
                    .filter { $0.matches(lightId: light) }
                    .forEach { viewObj in
                        let dev = viewObj.device
                        let sources = dev.supportedSource
                        guard !sources.isEmpty else { return }
                        let currentId = Int(dev.channel.value)
                        let currentIdx = sources.firstIndex(where: { $0.id == currentId }) ?? 0
                        var nextIdx = currentIdx + payload.direction
                        if nextIdx >= sources.count { nextIdx = 0 }
                        if nextIdx < 0 { nextIdx = sources.count - 1 }
                        let nextSource = sources[nextIdx]
                        resultSourceId = Int(nextSource.id)
                        resultSourceName = nextSource.name
                        if let defaultCmd = nextSource.defaultCmdPattern {
                            Task { @MainActor in
                                dev.lightMode = .SRCMode
                                dev.channel.value = UInt8(nextSource.id)
                                dev.sendCommandPattern(defaultCmd)
                            }
                        }
                    }
            }
            return HttpResponse.ok(.json([
                "success": true, "switched": payload.lights,
                "sourceId": resultSourceId, "sourceName": resultSourceName
            ] as [String: Any]))
        }

        // Fallback for other routes
        server.notFoundHandler = { request in
            Logger.info(LogTag.server, "return notFound for \(request.path)")
            return HttpResponse.notFound
        }
    }

    /// Starts the HTTP server
    func start() {
        do {
            try server.start(self.port, forceIPv4: true)
            Logger.info(LogTag.server, "BeaconServer listening on http://127.0.0.1:\(port)")
        } catch {
            Logger.error(LogTag.server, "Failed to start server: \(error)")
        }
    }

    /// Stops the HTTP server
    func stop() {
        server.stop()
        Logger.info(LogTag.server, "BeaconServer stopped")
    }
}
