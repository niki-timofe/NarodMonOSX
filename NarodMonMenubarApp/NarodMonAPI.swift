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

struct Type {
    let id: Int
    let name: String
    let unit: String
}

protocol NarodMonAPIDelegate: NSObjectProtocol {
    func appInitiated(app: App?)
    func gotSensorsValues(rdgs: [Reading]?)
    func gotSensorsList(sensors: [Sensor]?)
    func gotLocation(location: CLLocation?)
}

extension String {
    var first: String {
        return String(characters.prefix(1))
    }
    var last: String {
        return String(characters.suffix(1))
    }
    var uppercaseFirst: String {
        return first.uppercased() + String(characters.dropFirst())
    }
}

typealias JSONDict = [String:Any]

public class NarodMonAPI {
    let defaults = UserDefaults.standard
    
    var types: [Type] = []
    var delegate: NarodMonAPIDelegate?
    
    public init(withAPIKey key: String) {
        API_KEY = key
    }
    
    private var API_KEY: String!
    private var request = URLRequest(url: URL(string: "https://narodmon.ru/api")!)
    
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
    
    private func uuid() -> String {
        var uuid = defaults.string(forKey: "UUID")
        
        if (uuid == nil) {
            uuid = UUID().uuidString
            defaults.setValue(uuid, forKey: "UUID")
            defaults.synchronize()
        }
        
        return MD5(string: uuid!)
    }
    
    private func toJSONData(dict: [String:Any]) -> Data? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict)
            return jsonData
        } catch {
            NSLog("JSON parsing failed: \(error.localizedDescription)")
            NSLog("UUID: \(uuid())")
            NSLog("Data: \(dict)")
        }
        return nil
    }
    
    private func appFromAppInit(data: Data) -> App? {
        typealias JSONDict = [String:Any]
        let json: JSONDict
        
        do {
            json = try JSONSerialization.jsonObject(with: data, options: []) as! JSONDict
        } catch {
            NSLog("JSON parsing failed: \(error)")
            NSLog("UUID: \(uuid())")
            NSLog("Data: \(data)")
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
    
    public func appInit() {
        request.httpMethod = "POST"
        let osVersion = ProcessInfo().operatingSystemVersion
        let postObject = ["cmd": "appInit",
                          "uuid": uuid(),
                          "api_key": API_KEY,
                          "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String,
                          "lang": "ru",
                          "platform": String(format: "%d.%d.%d", osVersion.majorVersion, osVersion.minorVersion, osVersion.patchVersion)] as [String : Any]
        request.httpBody = toJSONData(dict: postObject)
        
        let task = URLSession.shared.dataTask(with: request) {data, response, error in guard let data = data, error == nil else {
                NSLog("HTTP error: \(error)")
                NSLog("UUID: \(self.uuid())")
                self.delegate?.appInitiated(app: nil)
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                NSLog("HTTP got status code: \(httpStatus.statusCode)")
                NSLog("UUID: \(self.uuid())")
                return
            }
            
            if let app = self.appFromAppInit(data: data) {
                self.delegate?.appInitiated(app: app)
            }
        }
        task.resume()
    }
    
    public func userLocation(location: CLLocation?) {
        request.httpMethod = "POST"
        
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
        request.httpBody = toJSONData(dict: postObject)
        
        let task = URLSession.shared.dataTask(with: request) {data, response, error in guard let data = data, error == nil else {
            self.delegate?.gotLocation(location: nil)
            NSLog("HTTP error: \(error)")
            NSLog("UUID: \(self.uuid())")
            return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                NSLog("HTTP got status code: \(httpStatus.statusCode)")
                NSLog("UUID: \(self.uuid())")
                NSLog("Data: \(data)")
                return
            }
            
            if let loc = self.locationFromUserLocation(data: data) {
                self.delegate?.gotLocation(location: loc)
            }
        }
        task.resume()
        
    }
    
    private func locationFromUserLocation(data: Data) -> CLLocation? {
        let json: JSONDict
        
        do {
            json = try JSONSerialization.jsonObject(with: data,
                                                    options: []) as! JSONDict
        } catch {
            NSLog("JSON parsing failed: \(error)")
            NSLog("UUID: \(uuid())")
            NSLog("Data: \(data)")
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
            NSLog("JSON parsing failed: \(error)")
            NSLog("UUID: \(uuid())")
            NSLog("Data: \(data)")
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
    
    public func sensorsNearby() {
        let postObject = ["cmd": "sensorsNearby",
                          "uuid": uuid(),
                          "pub": 1,
                          "limit": 3,
                          "api_key": API_KEY] as [String:Any]
        request.httpBody = toJSONData(dict: postObject)
        
        let task = URLSession.shared.dataTask(with: request) {data, response, error in guard let data = data, error == nil else {
            self.delegate?.gotSensorsList(sensors: nil)
            NSLog("HTTP error: \(error)")
            NSLog("UUID: \(self.uuid())")
            return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                NSLog("HTTP got status code: \(httpStatus.statusCode)")
                NSLog("UUID: \(self.uuid())")
                NSLog("Data: \(data)")
                return
            }
            
            if let sensors = self.sensorsFromSensorsNearby(data: data) {
                self.delegate?.gotSensorsList(sensors: sensors)
            }
        }
        task.resume()
    }
    
    private func valuesFromSensorsValues(data: Data) -> [Reading]? {
        typealias JSONDict = [String:Any]
        let json: JSONDict
        
        do {
            json = try JSONSerialization.jsonObject(with: data,
                                                    options: []) as! JSONDict
        } catch {
            NSLog("JSON parsing failed: \(error)")
            NSLog("UUID: \(uuid())")
            NSLog("Data: \(data)")
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
    
    public func sensorsValues(sensors: [Int]) {
        let postObject = ["cmd": "sensorsValues",
                          "uuid": uuid(),
                          "api_key": API_KEY,
                          "sensors": sensors] as [String : Any]
        request.httpBody = toJSONData(dict: postObject)
        
        let task = URLSession.shared.dataTask(with: request) {data, response, error in guard let data = data, error == nil else {
            self.delegate?.gotSensorsValues(rdgs: nil)
            NSLog("HTTP error: \(error)")
            NSLog("UUID: \(self.uuid())")
            return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                NSLog("HTTP got status code: \(httpStatus.statusCode)")
                NSLog("UUID: \(self.uuid())")
                NSLog("Data: \(data)")
                return
            }
            
            if let rdgs = self.valuesFromSensorsValues(data: data) {
                self.delegate?.gotSensorsValues(rdgs: rdgs)
            }
        }
        task.resume()
    }
    
}