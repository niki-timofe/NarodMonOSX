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
    let id: UInt8
    let type: Type
}

struct Reading {
    let value: Float
    let type: Type
    let time: UInt
}

struct Type {
    let id: UInt8
    let name: String
    let unit: String
}

protocol NarodMonAPIDelegate {
    func appInitiated(app: App)
    func gotSensorsValues(rdgs: [Reading])
}

class NarodMonAPI {
    let API_KEY = "40MHsctSKi4y6"
    
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
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
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
        for sensor in json["sensors"] as! [[String:Any]] {
            readings.append(Reading(value: sensor["value"] as! Float,
                                    type: Type(id: 0, name: "Число", unit: ""),
                                    time: sensor["time"] as! UInt))
        }
        
        return readings
    }
    
    func sensorsValues(sensors: [Int8]) {
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
