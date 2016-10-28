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

protocol NarodMonAPIDelegate {
    func appInitiated(app: App)
}

class NarodMonAPI {
    let API_KEY = "40MHsctSKi4y6"
    
    var delegate: NarodMonAPIDelegate?
    
    init(delegate: NarodMonAPIDelegate) {
        self.delegate = delegate
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
    
    func toJSONData(dict: [String:String]) -> Data? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            return jsonData
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }
    
    func locationFromAppInit(data: Data) -> App? {
        typealias JSONDict = [String:AnyObject]
        let json: JSONDict
        
        do {
            json = try JSONSerialization.jsonObject(with: data, options: []) as! JSONDict
        } catch {
            print("JSON parsing failed: \(error)")
            return nil
        }
        
        print(json)
        return App(lat: json["lat"] as! Float, lng: json["lng"] as! Float, latest: json["latest"] as! String, url: json["url"] as! String)
    }
    
    func appInit() -> Void {
        request.httpMethod = "POST"
        let osVersion = ProcessInfo().operatingSystemVersion
        let postObject = ["cmd": "appInit", "uuid": uuid(), "api_key": API_KEY, "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String, "lang": "ru", "platform": String(format: "%d.%d.%d", osVersion.majorVersion, osVersion.minorVersion, osVersion.patchVersion)]
        let postData = toJSONData(dict: postObject)
        request.httpBody = postData
        
        let task = URLSession.shared.dataTask(with: request) {data, response, error in guard let data = data, error == nil else {print("error=\(error)"); return}
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(response)")
                return
            }
            
            if let app = self.locationFromAppInit(data: data) {
                self.delegate?.appInitiated(app: app)
            }
        }
        task.resume()
    }
    
    
}
