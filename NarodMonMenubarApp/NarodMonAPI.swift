//
//  NarodMonAPI.swift
//  NarodMonWidget
//
//  Created by Никита Тимофеев on 27.10.16.
//  Copyright © 2016 Никита Тимофеев. All rights reserved.
//

import CoreLocation

public struct App {
    let lat: Float
    let lng: Float
    let latest: String
    let url: String
    
    init?(json: [String : Any]) {
        guard let lat = json["lat"] as? Float,
            let lng = json["lng"] as? Float,
            let url = json["url"] as? String,
            let latest = json["latest"] as? String
            else { return nil }
        
        self.lat = lat
        self.lng = lng
        self.url = url
        self.latest = latest
    }
}

public struct Sensor {
    let id: Int
    let type: Type
    init?(json: [String : Any], types: [Int : Type]) {
        guard let id = json["id"] as? Int,
            let type = types[json["type"] as? Int ?? 0]
            else { return nil }
        
        self.id = id
        self.type = type
    }
}

public struct Reading {
    let value: Float
    let sensor: Int
    let time: Int
    
    init?(json: JSONDict) {
        guard let value = json["value"] as? Float,
            let sensor = json["id"] as? Int,
            let time = json["time"] as? Int
            else { return nil }
        
        self.value = value
        self.sensor = sensor
        self.time = time
    }
}

public struct Type : Hashable {
    let id: Int
    let name: String
    let unit: String
    
    public var hashValue: Int {
        return id.hashValue
    }
    
    public static func == (lhs: Type, rhs: Type) -> Bool {
        return lhs.id == rhs.id
    }
    
    init?(json: [String : Any]) {
        guard let id = json["type"] as? Int,
            let name = json["name"] as? String,
            let unit = json["unit"] as? String
            else { return nil }
        
        self.id = id
        self.name = String(name.characters.split(separator: ",")[0]).uppercaseFirst
        self.unit = unit
    }
}

public protocol NarodMonAPIDelegate: NSObjectProtocol {
    func appInitiated(app: App?)
    func gotSensorsValues(rdgs: [Reading]?)
    func gotSensorsList(sensors: [Sensor]?)
    func gotLocation(location: CLLocation?)
    func gotError(error: URLError)
    func gotError(error: Error)
}

extension String {
    var last: String {return String(characters.suffix(1))}
    var uppercaseFirst: String {return String(characters.prefix(1)).uppercased() + String(characters.dropFirst())}
}

typealias JSONDict = [String : Any]

extension Data {
    func parseJSON() -> JSONDict? {
        do {
            return try JSONSerialization.jsonObject(with: self) as? JSONDict
        } catch {
            return nil
        }
    }
}

extension Dictionary where Key == String {
    func toJSONData() -> Data? {
        do {
            return try JSONSerialization.data(withJSONObject: self)
        } catch {
            return nil
        }
    }
}

public class NarodMonAPI {
    private let API_KEY: String!
    private var request = URLRequest(url: URL(string: "https://narodmon.ru/api")!)
    private var UUIDString: String
    
    
    var types: [Int : Type] = [:]
    var delegate: NarodMonAPIDelegate?
    
    
    public init(withAPIKey key: String) {
        API_KEY = key
        request.httpMethod = "POST"
        request.httpShouldUsePipelining = false
        
        if let uuid = UserDefaults.standard.string(forKey: "NarodMonWidgetUUID") {
            UUIDString = uuid
        } else {
            UUIDString = ""
            let uuid = MD5(string: UUID().uuidString)
            UserDefaults.standard.set(uuid, forKey: "NarodMonWidgetUUID")
            UUIDString = uuid
        }
    }

    
    /// Assistant Functions
    private func MD5(string: String) -> String {
        guard let messageData = string.data(using:String.Encoding.utf8) else { return "" }
        var digestData = Data(count: Int(CC_MD5_DIGEST_LENGTH))
        
        _ = digestData.withUnsafeMutableBytes {digestBytes in
            messageData.withUnsafeBytes {messageBytes in
                CC_MD5(messageBytes, CC_LONG(messageData.count), digestBytes)
            }
        }
        
        return digestData.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// Processing functions
    private func appFromAppInit(data: Data) -> App? {
        guard let json = data.parseJSON() else {
            let log = "[API][JSON]: parsing failed, UUID: \(UUIDString), Data: \(data)"
            NSLog(log)
            sendReport(log: log)
            self.delegate?.gotError(error: NSError())
            return nil
        }
        
        types.removeAll()
        guard let thisTypes = json["types"] as? [[String:Any]] else {
            return nil
        }
        
        for type in thisTypes {
            if let thisType = Type(json: type) {
                types[thisType.id] = thisType
            }
        }
        
        return App(json: json)
    }
    
    private func locationFromUserLocation(data: Data) -> CLLocation? {
        guard let json = data.parseJSON() else {
            let log = "[API][JSON]: parsing failed, UUID: \(UUIDString), Data: \(data)"
            NSLog(log)
            sendReport(log: log)
            self.delegate?.gotError(error: NSError())
            return nil
        }
        
        return CLLocation(latitude: CLLocationDegrees(json["lat"] as! Double), longitude: CLLocationDegrees(json["lng"] as! Double))
    }
    
    private func sensorsFromSensorsNearby(data: Data) -> [Sensor]? {
        guard let json = data.parseJSON() else {
            let log = "[API][JSON]: parsing failed, UUID: \(UUIDString), Data: \(data)"
            NSLog(log)
            sendReport(log: log)
            self.delegate?.gotError(error: NSError())
            return nil
        }
        
        var senss: [Sensor] = []
        guard let devices = json["devices"] as? [[String : Any]] else {
            return nil
        }
        for device in devices {
            if let sensors = device["sensors"] as? [[String : Any]] {
                for sensor in sensors {
                    if let thisSensor = Sensor(json: sensor, types: self.types) {
                        senss.append(thisSensor)
                    } else {
                        appInit()
                        return nil
                    }
                }
            }
        }
        
        return senss
    }
    
    private func valuesFromSensorsValues(data: Data) -> [Reading]? {
        guard let json = data.parseJSON() else {
            let log = "[API][JSON]: parsing failed, UUID: \(UUIDString), Data: \(data)"
            NSLog(log)
            sendReport(log: log)
            self.delegate?.gotError(error: NSError())
            return nil
        }
        
        var readings: [Reading] = []
        
        guard let sensors = json["sensors"] as? [[String:Any]] else {
            return nil
        }
        for sensor in sensors {
            if let thisReading = Reading(json: sensor) {
                readings.append(thisReading)
            }
        }
        
        return readings
    }
    
    
    /// API Functions
    public func appInit() {
        let osVersion = ProcessInfo().operatingSystemVersion
        
        post(object: ["cmd": "appInit",
                      "uuid": UUIDString,
                      "api_key": API_KEY,
                      "version": "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String)",
                      "lang": "ru",
                      "platform": String(format: "%d.%d.%d",
                                         osVersion.majorVersion,
                                         osVersion.minorVersion,
                                         osVersion.patchVersion)],
             processWith: appFromAppInit) { (app: Any?) -> () in
                self.delegate?.appInitiated(app: app as! App?)
        }
    }
    
    public func userLocation(location: CLLocation?) {
        let postObject: [String: Any]
        
        if (location != nil) {
            postObject = ["cmd": "userLocation",
                          "uuid": UUIDString,
                          "api_key": API_KEY,
                          "lang": "ru",
                          "lat": location!.coordinate.latitude,
                          "lng": location!.coordinate.longitude]
        } else {
            postObject = ["cmd": "userLocation",
                          "uuid": UUIDString,
                          "api_key": API_KEY,
                          "lang": "ru"]
        }
        
        post(object: postObject,
             processWith: locationFromUserLocation) { (location: Any?) -> () in
                self.delegate?.gotLocation(location: location as? CLLocation)
        }
    }
    
    public func sensorsNearby() {
        post(object: ["cmd": "sensorsNearby",
                      "uuid": UUIDString,
                      "pub": 1,
                      "radius": 5,
                      "api_key": API_KEY],
             processWith: sensorsFromSensorsNearby) { (sensors: Any?) -> () in
                self.delegate?.gotSensorsList(sensors: sensors as! [Sensor]?)
        }
    }
    
    public func sensorsValues(sensors: [Int]) {
        post(object: ["cmd": "sensorsValues",
                      "uuid": UUIDString,
                      "api_key": API_KEY,
                      "sensors": sensors],
             processWith: valuesFromSensorsValues) { (rdgs: Any?) -> () in
                self.delegate?.gotSensorsValues(rdgs: rdgs as! [Reading]?)
        }
    }
    
    public func sendReport(log: String) {
        post(object: ["cmd": "sendReport",
                      "uuid": UUIDString,
                      "api_key": API_KEY,
                      "time": Date().timeIntervalSince1970,
                      "logs": log], processWith: { (data: Data) -> Bool in false }, delegated: { _ in })
    }
    
    
    /// HTTP POST Function
    ///
    /// - Parameters:
    ///   - postObject: Dictionary to post
    ///   - process: Function which will process recieved Data
    ///   - delegated: Delegate function, where processed data will be returned
    private func post(object postObject: [String : Any], processWith process: @escaping (_ data: Data) -> Any?,  delegated: @escaping (_: Any?) -> ()) {
        guard let requestBody = postObject.toJSONData() else {
            let log = "[API][JSON]: parsing failed UUID: \(UUIDString), Data: \(postObject)"
            NSLog(log)
            sendReport(log: log)
            self.delegate?.gotError(error: NSError())
            return
        }
        NSLog("[API]: Trying \"\(postObject["cmd"] ?? "nil")\"")
        request.httpBody = requestBody
        
        let task = URLSession.shared.dataTask(with: request) {data, response, error in guard let data = data, error == nil else {
            self.delegate?.gotError(error: error! as! URLError)
            NSLog("[API][HTTP]: error: \(String(describing: error!.localizedDescription))\n" +
                "for request: \(String.init(data: requestBody, encoding: String.Encoding.utf8) ?? "nil")")
            delegated(_: nil)
            return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                NSLog("[API][HTTP]: got status code: \(httpStatus.statusCode)\n" +
                    "for request: \(String.init(data: requestBody, encoding: String.Encoding.utf8) ?? "nil")")
                return
            }
            
            if let processed = process(data) {
                delegated(_: processed)
            }
        }
        task.resume()
    }
}
