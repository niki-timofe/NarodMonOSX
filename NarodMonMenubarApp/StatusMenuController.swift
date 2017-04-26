//
//  StatusMenuController.swift
//  NarodMonMenubarApp
//
//  Created by Никита Тимофеев on 22.03.17.
//  Copyright © 2017 Nikita Timofeev. All rights reserved.

import Cocoa
import Foundation
import CoreLocation

class StatusMenuController: NSObject {
    let statusItem: NSStatusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    let narodMon: NarodMonAPI
    let userDefaults: UserDefaults = UserDefaults.standard
    let formatter = DateFormatter()
    
    let statusMenu: NSMenu = NSMenu()
    let updateTimeMenuItem: NSMenuItem = NSMenuItem()
    
    var readingsMenuItems: [NSMenuItem] = []
    
    let updateAlert = NSAlert()
    
    var location: CLLocation?
    var fetchTimer: Timer?
    var retryCount: Int = 0
    var querySensors: [Int] = []
    
    var wake: Date? = nil
    var latestAppInit: Date? = nil
    var latestNearby: Date? = nil
    var latestValues: Date? = nil
    var latestLocation: Date? = nil
    
    var nearbySensors: [Sensor] = []
    var offline: Bool = true
    var supressUpdateDialog: Bool = false
    var app: App?
    
    override init() {
        statusItem.title = "…"
        statusItem.menu = statusMenu
        
        formatter.dateFormat = "H:mm"
        
        statusMenu.addItem(withTitle: "Обновить", action: #selector(StatusMenuController.updateBtnPress(sender:)), keyEquivalent: "")
        statusMenu.addItem(updateTimeMenuItem)
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(withTitle: "Выйти", action: #selector(StatusMenuController.quitBtnPress(sender:)), keyEquivalent: "")
        
        narodMon = NarodMonAPI(withAPIKey: "40MHsctSKi4y6")
        
        super.init()
        
        statusMenu.item(withTitle: "Обновить")!.target = self
        statusMenu.item(withTitle: "Выйти")!.target = self
        narodMon.delegate = self
        NSLog("[API]: Trying \"appInit\"")
        narodMon.appInit()
        
        updateAlert.messageText = "Доступна новая версия"
        updateAlert.informativeText = "Доступна новая версия приложения. Загрузить сейчас?"
        updateAlert.alertStyle = NSAlertStyle.warning
        updateAlert.showsSuppressionButton = true
        updateAlert.addButton(withTitle: "Загрузить")
        updateAlert.addButton(withTitle: "Отменить")
    }
    
    func updateBtnPress(sender: NSMenuItem) {
        NSLog("Force update from \"updateBtn\"")
        _ = requestLocationUpdate(force: true)
    }
    
    func quitBtnPress(sender: NSMenuItem) {
        NSApp.terminate(sender)
    }
    
    func updateLocation(location: CLLocation?) {
        NSLog("[API]: Trying \"userLocation\" with \(String(describing: location))")
        narodMon.userLocation(location: location)
    }
    
    //Periodic tasks
    
    func requestAppInitUpdate(force: Bool = true) -> Bool {
        if !(force || Date().timeIntervalSince(latestAppInit ?? Date(timeIntervalSince1970: 0)) > 24 * 60 * 60) {return false}
        NSLog("[API]: Trying \"appInit\"")
        narodMon.appInit()
        return true
    }
    
    func requestLocationUpdate(force: Bool = true) -> Bool {
        if !(force || Date().timeIntervalSince(latestLocation ?? Date(timeIntervalSince1970: 0)) > 30 * 60) {return false}
        NSLog("Requesting location update from \"locationManager\"")
        delegate.locationManager!.startUpdatingLocation()
        return true
    }
    
    func requestSensorsNearbyUpdate(force: Bool = true) {
        NSLog("[API]: Trying \"sensorsNearby\"")
        narodMon.sensorsNearby()
    }
    
    func requestSensorsValuesUpdate(force: Bool = true) {
        if !(force || Date().timeIntervalSince(latestValues ?? Date(timeIntervalSince1970: 0)) > 7.5 * 60) {return}
        NSLog("[API]: Trying \"sensorsValues\"")
        narodMon.sensorsValues(sensors: self.querySensors)
    }
    
}
extension StatusMenuController: NarodMonAPIDelegate {
    func goOffline() {
        if (offline) {return}
        NSLog("Going offline")
        offline = true
        statusItem.title = statusItem.title! + "?"
    }
    
    func goOnline() {
        offline = false
    }
    
    func appInitiated(app: App?) {
        if (app == nil) {
            goOffline()

            NSLog("Will retry \"appInit\" #\(retryCount + 1)")
            DispatchQueue.main.async {
                Timer.scheduledTimer(withTimeInterval: self.retryCount < 3 ? 10 : (10 * 60), repeats: false, block: {_ in
                    _ = self.requestAppInitUpdate()
                })
            }
            retryCount += 1
            return
        }
        
        NSLog("\"appInit\" success")
        latestAppInit = Date()
        self.app = app
        retryCount = 0
        
        if wake != nil {
            let successUpdateAfterWake = Date().timeIntervalSince(wake!),
            newUpdateAfterWakeInterval = (userDefaults.double(forKey: "UpdateAfterWake") + successUpdateAfterWake) / 2 * 0.85
            
            userDefaults.set(newUpdateAfterWakeInterval, forKey: "UpdateAfterWake")
            userDefaults.synchronize()
            
            NSLog("Sucessful \"appInit\" after wake in \(successUpdateAfterWake)s new UpdateAfterWake interval: \(newUpdateAfterWakeInterval)s")
            

            wake = nil;
        }
        
        
        let latestVersion = self.app!.latest
        let currentVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        
        if (latestVersion.compare(currentVersion, options: NSString.CompareOptions.numeric) == ComparisonResult.orderedDescending) {
            DispatchQueue.main.async {
                if !self.supressUpdateDialog && self.updateAlert.runModal() == NSAlertFirstButtonReturn {
                    if let url = URL(string: "https://github.com/niki-timofe/NarodMonOSX/releases/latest"), NSWorkspace.shared().open(url) {
                        NSApp.terminate(self.updateAlert)
                    }
                } else {
                    self.supressUpdateDialog = self.updateAlert.suppressionButton?.state == NSOnState
                }
            }
        }
        
        if fetchTimer != nil {
            fetchTimer!.invalidate()
        }
        
        DispatchQueue.main.async {
            self.fetchTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(60), repeats: true, block: {_ in
                if !self.requestAppInitUpdate(force: false) {
                    if !self.requestLocationUpdate(force: false) {
                        _ = self.requestSensorsValuesUpdate(force: false)
                    }
                }
            })
            self.fetchTimer!.fire()
        }
    }
    
    func gotSensorsValues(rdgs: [Reading]?) {
        if rdgs == nil {
            NSLog("\"sensorsValues\" failed")
            goOffline()
            return
        } else {
            NSLog("\"sensorsValues\" success")
            latestValues = Date()
            goOnline()
        }
        
        
        var summs = [Int:Float]()
        var counters = [Int:Int]()
        
        var current: Float = 0
        var curent_counter: Int = 0
        var sensor: Sensor
        for reading in rdgs! {
            sensor = nearbySensors.first(where: {$0.id == reading.sensor})!
            current = summs.keys.contains(sensor.type.id) ? summs[sensor.type.id]! : 0
            summs.updateValue(current + reading.value, forKey: sensor.type.id)
            
            curent_counter = counters.keys.contains(sensor.type.id) ? counters[sensor.type.id]! : 0
            counters.updateValue(curent_counter + 1, forKey: sensor.type.id)
        }
        
        for item in readingsMenuItems {
            statusMenu.removeItem(item)
        }
        readingsMenuItems.removeAll()
        
        for summ in summs {
            if summ.key == 1 {continue}
            readingsMenuItems.append(NSMenuItem(title: String(format: "%@\t%.1f%@", narodMon.types[summ.key].name, summ.value / Float(counters[summ.key]!), narodMon.types[summ.key].unit), action: nil, keyEquivalent: ""))
            statusMenu.insertItem(readingsMenuItems.last!, at: 3)
        }
        
        updateTimeMenuItem.title = formatter.string(from: Date())
        statusItem.title = String.init(format: "%.1f\u{00B0}", summs[1]! / Float(counters[1]!))
    }
    
    /// Called when sensors is emitted
    ///
    /// - Parameter sensors: list of nearby sensors
    func gotSensorsList(sensors: [Sensor]?) {
        if (sensors == nil) {
            NSLog("\"sensorsNearby\" failed")
            goOffline()
            return
        } else {
            NSLog("\"sensorsNearby\" success")
            latestNearby = Date()
        }
        
        querySensors = []
        nearbySensors = sensors!
        
        for sensor in nearbySensors {
            querySensors.append(sensor.id)
        }
        
        _ = requestSensorsValuesUpdate()
    }
    
    func gotLocation(location: CLLocation?) {
        if location == nil {
            NSLog("Failed to get new location")
        }
        
        NSLog("Got new location: \(String(describing: location))")
        latestLocation = Date()
        
        self.location = location
        requestSensorsNearbyUpdate()
    }
}
