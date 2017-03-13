//
//  NarodMonAPI.swift
//  NarodMonWidget
//
//  Created by Никита Тимофеев on 27.10.16.
//  Copyright © 2016 Никита Тимофеев. All rights reserved.
//

import Foundation

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

protocol NarodMonAPIDelegate {
    func appInitiated(app: App)
    func gotSensorsValues(rdgs: [Reading])
    func gotSensorsList(sensors: [Sensor])
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

class NarodMonAPI {
    let API_KEY = "40MHsctSKi4y6"
    var types: [Type] = []
    
    var delegate: NarodMonAPIDelegate?
    
    init(delegate: NarodMonAPIDelegate) {
        self.delegate = delegate
        self.appInit()
    }
    
    var request = URLRequest(url: URL(string: "https://narodmon.ru/api")!)
    
    func MD5(string: String) -> String {
        guard let messageData = string.data(using:String.Encoding.utf8) else { return "" }
        var digestData = Data(count: Int(CC_MD5_DIGEST_LENGTH))
        
        _ = digestData.withUnsafeMutableBytes {digestBytes in
            messageData.withUnsafeBytes {messageBytes in
                CC_MD5(messageBytes, CC_LONG(messageData.count), digestBytes)
            }
        }
        
        return digestData.map { String(format: "%02hhx", $0) }.joined()
    }
    
    func uuid() -> String {
        let defaults = UserDefaults.standard
        var uuid = defaults.string(forKey: "UUID")
        
        if (uuid == nil) {
            uuid = UUID().uuidString
            defaults.setValue(uuid, forKey: "UUID")
        }
        
        return MD5(string: uuid!)
    }
    
    func toJSONData(dict: [String:Any]) -> Data? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict)
            return jsonData
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }
    
    func appFromAppInit(data: Data) -> App? {
        typealias JSONDict = [String:Any]
        let json: JSONDict
        
        do {
            json = try JSONSerialization.jsonObject(with: data, options: []) as! JSONDict
        } catch {
            print("JSON parsing failed: \(error)")
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
    
    func appInit() {
        request.httpMethod = "POST"
        let osVersion = ProcessInfo().operatingSystemVersion
        let postObject = ["cmd": "appInit",
                          "uuid": uuid(),
                          "api_key": API_KEY,
                          "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String,
                          "lang": "ru",
                          "platform": String(format: "%d.%d.%d", osVersion.majorVersion, osVersion.minorVersion, osVersion.patchVersion)] as [String : Any]
        request.httpBody = toJSONData(dict: postObject)
        
        let task = URLSession.shared.dataTask(with: request) {data, response, error in guard let data = data, error == nil else {print("error=\(error)"); return}
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(response)")
                return
            }
            
            if let app = self.appFromAppInit(data: data) {
                self.delegate?.appInitiated(app: app)
            }
        }
        task.resume()
    }
    
    func sensorsFromSensorsNearby(data: Data) -> [Sensor]? {
        typealias JSONDict = [String:Any]
        let json: JSONDict
        
        do {
            json = try JSONSerialization.jsonObject(with: data,
                                                    options: []) as! JSONDict
        } catch {
            print("JSON parsing failed: \(error)")
            return nil                                                  //TODO: Error notification
        }
        
        var senss: [Sensor] = []
        if !(json.keys.contains("devices")) {
            return nil                                              //TODO: Error notification
        }
        for device in json["devices"] as! [[String:Any]] {
            if !(device.keys.contains("sensors")) {
                return nil                                              //TODO: Error notification
            }
            for sensor in device["sensors"] as! [[String:Any]] {
                if !(sensor.keys.contains("id") && sensor.keys.contains("type")) {
                    return nil                                          //TODO: Error notification
                }
                senss.append(Sensor(id: sensor["id"] as! Int, type: self.types[sensor["type"] as! Int]))
            }
        }
        
        return senss
    }
    
    func sensorsNearby() {
        let postObject = ["cmd": "sensorsNearby",
                          "uuid": uuid(),
                          "pub": 1,
                          "limit": 3,
                          "api_key": API_KEY] as [String:Any]
        request.httpBody = toJSONData(dict: postObject)
        
        let task = URLSession.shared.dataTask(with: request) {data, response, error in guard let data = data, error == nil else {print("error=\(error)"); return}
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(response)")
                return
            }
            
            if let sensors = self.sensorsFromSensorsNearby(data: data) {
                self.delegate?.gotSensorsList(sensors: sensors)
            }
        }
        task.resume()
    }
    
    func valuesFromSensorsValues(data: Data) -> [Reading]? {
        typealias JSONDict = [String:Any]
        let json: JSONDict
        
        do {
            json = try JSONSerialization.jsonObject(with: data,
                                                    options: []) as! JSONDict
        } catch {
            print("JSON parsing failed: \(error)")
            return nil
        }
        
        var readings: [Reading] = []
        
        if !(json.keys.contains("sensors")) {
            return nil                                              //TODO: Error notification
        }
        for sensor in json["sensors"] as! [[String:Any]] {
            if !(sensor.keys.contains("value") && sensor.keys.contains("id") && sensor.keys.contains("time")) {
                return nil                                          //TODO: Error notification
            }
            readings.append(Reading(value: sensor["value"] as! Float,
                                    sensor: sensor["id"] as! Int,
                                    time: sensor["time"] as! Int))
        }
        
        return readings
    }
    
    func sensorsValues(sensors: [Int]) {
        let postObject = ["cmd": "sensorsValues",
                          "uuid": uuid(),
                          "api_key": API_KEY,
                          "sensors": sensors] as [String : Any]
        request.httpBody = toJSONData(dict: postObject)
        
        let task = URLSession.shared.dataTask(with: request) {data, response, error in guard let data = data, error == nil else {print("error=\(error)"); return}
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(response)")
                return
            }
            
            if let rdgs = self.valuesFromSensorsValues(data: data) {
                self.delegate?.gotSensorsValues(rdgs: rdgs)
            }
        }
        task.resume()
    }
    
}
