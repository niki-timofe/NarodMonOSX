//
//  NarodMonAPI.swift
//  NarodMonWidget
//
//  Created by Никита Тимофеев on 27.10.16.
//  Copyright © 2016 Никита Тимофеев. All rights reserved.
//

import CoreLocation

struct App {
    let lat: Float
    let lng: Float
    let latest: String
    let url: String
}

struct Sensor {
    let id: Int
    let type: Type
}

struct Reading {
    let value: Float
    let sensor: Int
    let time: Int
}

struct Type : Hashable {
    let id: Int
    let name: String
    let unit: String
    
    var hashValue: Int {
        return id.hashValue
    }
    
    static func == (lhs: Type, rhs: Type) -> Bool {
        return lhs.id == rhs.id
    }
}

protocol NarodMonAPIDelegate: NSObjectProtocol {
    func appInitiated(app: App?)
    func gotSensorsValues(rdgs: [Reading]?)
    func gotSensorsList(sensors: [Sensor]?)
    func gotLocation(location: CLLocation?)
}

extension String {
    var first: String {return String(characters.prefix(1))}
    var last: String {return String(characters.suffix(1))}
    var uppercaseFirst: String {return first.uppercased() + String(characters.dropFirst())}
}

typealias JSONDict = [String:Any]

public class NarodMonAPI {
    private let API_KEY: String!
    private var request = URLRequest(url: URL(string: "https://narodmon.ru/api")!)
    private var keychain = KeychainSwift()
    
    
    var types: [Type] = []
    var delegate: NarodMonAPIDelegate!
    
    
    public init(withAPIKey key: String) {
        API_KEY = key
        request.httpMethod = "POST"
        request.httpShouldUsePipelining = false
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
    private func toJSONData(dict: [String:Any]) -> Data? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict)
            return jsonData
        } catch {
            NSLog("[API][JSON]: parsing failed: \(error.localizedDescription), UUID: \(uuid()), Data: \(dict)")
        }
        return nil
    }
    
    
    /// UUID getting function
    ///
    /// - Returns: generated or saved UUID
    private func uuid() -> String {
        var uuid = keychain.get("NarodMon Widget UUID")
        
        if (uuid == nil) {
            uuid = UUID().uuidString
            keychain.set(uuid!, forKey: "NarodMon Widget UUID", withAccess: .accessibleAlways)
        }
        
        return MD5(string: uuid!)
    }
    
    
    /// Processing functions
    private func appFromAppInit(data: Data) -> App? {
        let json: JSONDict
        
        do {
            json = try JSONSerialization.jsonObject(with: data, options: []) as! JSONDict
        } catch {
            NSLog("[API][JSON]: parsing failed: \(error), UUID: \(uuid()), Data: \(data)")
            return nil
        }
        
        types = []
        
        for type in json["types"] as! [[String:Any]] {
            var title = (type["name"] as! String).uppercaseFirst
            
            title = title.components(separatedBy: ",")[0]
            
            types.append(Type(id: type["type"] as! Int, name: title, unit: type["unit"] as! String))
        }
        
        return App(lat: json["lat"] as! Float,
                   lng: json["lng"] as! Float,
                   latest: json["latest"] as! String,
                   url: json["url"] as! String)
    }
    
    private func locationFromUserLocation(data: Data) -> CLLocation? {
        let json: JSONDict
        
        do {
            json = try JSONSerialization.jsonObject(with: data,
                                                    options: []) as! JSONDict
        } catch {
            NSLog("[API][JSON]: parsing failed: \(error), UUID: \(uuid()), Data: \(data)")
            return nil
        }
        
        return CLLocation(latitude: CLLocationDegrees(json["lat"] as! Double), longitude: CLLocationDegrees(json["lng"] as! Double))
    }
    
    private func sensorsFromSensorsNearby(data: Data) -> [Sensor]? {
        let json: JSONDict
        
        do {
            json = try JSONSerialization.jsonObject(with: data,
                                                    options: []) as! JSONDict
        } catch {
            NSLog("[API][JSON]: parsing failed: \(error), UUID: \(uuid()), Data: \(data)")
            return nil
        }
        
        var senss: [Sensor] = []
        if !(json.keys.contains("devices")) {
            return nil
        }
        for device in json["devices"] as! [[String:Any]] {
            if !(device.keys.contains("sensors")) {
                return nil
            }
            for sensor in device["sensors"] as! [[String:Any]] {
                if !(sensor.keys.contains("id") && sensor.keys.contains("type")) {
                    return nil
                }
                if types.count < sensor["type"] as! Int {
                    appInit()
                    return nil
                }
                senss.append(Sensor(id: sensor["id"] as! Int, type: types[sensor["type"] as! Int]))
            }
        }
        
        return senss
    }
    
    private func valuesFromSensorsValues(data: Data) -> [Reading]? {
        typealias JSONDict = [String:Any]
        let json: JSONDict
        
        do {
            json = try JSONSerialization.jsonObject(with: data,
                                                    options: []) as! JSONDict
        } catch {
            NSLog("[API][JSON]: parsing failed: \(error), UUID: \(uuid()), Data: \(data)")
            return nil
        }
        
        var readings: [Reading] = []
        
        if !(json.keys.contains("sensors")) {
            return nil
        }
        for sensor in json["sensors"] as! [[String:Any]] {
            if !(sensor.keys.contains("value") && sensor.keys.contains("id") && sensor.keys.contains("time")) {
                return nil
            }
            readings.append(Reading(value: sensor["value"] as! Float,
                                    sensor: sensor["id"] as! Int,
                                    time: sensor["time"] as! Int))
        }
        
        return readings
    }
    
    
    /// API Functions
    public func appInit() {
        let osVersion = ProcessInfo().operatingSystemVersion
        
        post(object: ["cmd": "appInit",
                      "uuid": uuid(),
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
                          "uuid": uuid(),
                          "api_key": API_KEY,
                          "lang": "ru",
                          "lat": location!.coordinate.latitude,
                          "lng": location!.coordinate.longitude]
        } else {
            postObject = ["cmd": "userLocation",
                          "uuid": uuid(),
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
                      "uuid": uuid(),
                      "pub": 1,
                      "radius": 5,
                      "api_key": API_KEY],
             processWith: sensorsFromSensorsNearby) { (sensors: Any?) -> () in
                self.delegate?.gotSensorsList(sensors: sensors as! [Sensor]?)
        }
    }
    
    public func sensorsValues(sensors: [Int]) {
        post(object: ["cmd": "sensorsValues",
                      "uuid": uuid(),
                      "api_key": API_KEY,
                      "sensors": sensors],
             processWith: valuesFromSensorsValues) { (rdgs: Any?) -> () in
                self.delegate?.gotSensorsValues(rdgs: rdgs as! [Reading]?)
        }
    }
    
    
    /// HTTP POST Function
    ///
    /// - Parameters:
    ///   - postObject: Dictionary to post
    ///   - process: Function which will process recieved Data
    ///   - delegated: Delegate function, where processed data will be returned
    private func post(object postObject: [String : Any],  processWith process: @escaping (_ data: Data) -> Any?,  delegated: @escaping (_: Any?) -> ()) {
        let requestBody = toJSONData(dict: postObject)
        NSLog("[API]: Trying \"\(postObject["cmd"] ?? "nil")\"")
        request.httpBody = requestBody
        
        let task = URLSession.shared.dataTask(with: request) {data, response, error in guard let data = data, error == nil else {
            NSLog("[API][HTTP]: error: \(String(describing: error!.localizedDescription))\n" +
                "for request: \(String.init(data: requestBody!, encoding: String.Encoding.utf8) ?? "nil")")
            delegated(_: nil)
            return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                NSLog("[API][HTTP]: got status code: \(httpStatus.statusCode)\n" +
                    "for request: \(String.init(data: requestBody!, encoding: String.Encoding.utf8) ?? "nil")")
                return
            }
            
            if let processed = process(data) {
                delegated(_: processed)
            }
        }
        task.resume()
    }
}
