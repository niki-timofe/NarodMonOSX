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
    let backgroundDispatchQueue = DispatchQueue(label: "ru.niki-timofe.narodmon.backgroundTasks", qos: DispatchQoS.background)
    
    let statusMenu: NSMenu = NSMenu()
    let updateTimeMenuItem: NSMenuItem = NSMenuItem()
    
    let updateAlert = NSAlert()
    let normalUpdateInterval: Double = 450
    
    var readingsMenuItems: [Type : NSMenuItem] = [:]
    
    var workItems: [String : DispatchWorkItem] = [:]
    
    var location: CLLocation?
    var fetchTimer: Timer?
    
    var wake: Date? = nil
    var latestAppInit: Date? = nil
    var latestNearby: Date? = nil
    var latestLocation: Date? = nil
    
    var lastSuccessUpdatesByTypes: [Type : Date] = [:]
    var nextUpdatesByTypes: [Type : Date] = [:]
    
    var nearbySensorsByTypes: [Type : [Sensor]] = [:]
    var readingsByTypes: [Type : Float] = [:]
    
    var retryCount: Int = 0
    
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
        
        narodMon = NarodMonAPI(withAPIKey: "4Pk1qAgMhSyPc")
        
        super.init()
        
        statusMenu.item(withTitle: "Обновить")!.target = self
        statusMenu.item(withTitle: "Выйти")!.target = self
        narodMon.delegate = self
        narodMon.appInit()
        
        updateAlert.messageText = "Доступна новая версия"
        updateAlert.informativeText = "Доступна новая версия приложения. Загрузить сейчас?"
        updateAlert.alertStyle = NSAlertStyle.warning
        updateAlert.showsSuppressionButton = true
        updateAlert.addButton(withTitle: "Загрузить")
        updateAlert.addButton(withTitle: "Отменить")
        
        setWorkItems()
    }
    
    func setWorkItems() {
        workItems = ["chain": DispatchWorkItem(block: {_ in
            if !self.requestAppInitUpdate(force: false) {
                if !self.requestLocationUpdate(force: false) {
                    _ = self.requestSensorsValuesUpdate(force: false)
                }
            }
        }), "appInit": DispatchWorkItem(block: {
            _ = self.requestAppInitUpdate()
        })]
    }
    
    func updateBtnPress(sender: NSMenuItem) {
        NSLog("Force update from \"updateBtn\"")
        if wake != nil {
            _ = requestAppInitUpdate()
        } else {
            _ = requestLocationUpdate()
        }
    }
    
    func quitBtnPress(sender: NSMenuItem) {
        NSApp.terminate(sender)
    }
    
    func updateLocation(location: CLLocation?) {
        narodMon.userLocation(location: location)
    }
    
    //Periodic tasks
    
    func requestAppInitUpdate(force: Bool = true) -> Bool {
        if !(force || Date().timeIntervalSince(latestAppInit ?? Date(timeIntervalSince1970: 0)) > 24 * 60 * 60) {return false}
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
        narodMon.sensorsNearby()
    }
    
    func requestSensorsValuesUpdate(force: Bool = true) {
        if force {
            narodMon.sensorsValues(sensors: nearbySensorsByTypes.values.flatMap({sensors in
                sensors.map {$0.id}
            }))
        } else {
            let thisUpdateSensors: [Int] = nearbySensorsByTypes.filter({type, _ in
                (nextUpdatesByTypes[type] ?? Date()).compare(Date()) == ComparisonResult.orderedAscending
            }).flatMap({_, sensors in
                sensors.map {$0.id}
            })
            if thisUpdateSensors.count > 0 {
                narodMon.sensorsValues(sensors: thisUpdateSensors)
            }
        }
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

            let retryInterval = TimeInterval(self.retryCount < 3 ? 10 : (10 * 60))
            NSLog("Will retry \"appInit\" #\(retryCount + 1) in \(retryInterval)s")
            
            backgroundDispatchQueue.asyncAfter(deadline: .now() + retryInterval, execute: workItems["appInit"]!)
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
            
            if (retryCount < 3) {
                userDefaults.set(newUpdateAfterWakeInterval, forKey: "UpdateAfterWake")
                userDefaults.synchronize()
            }
            
            NSLog("Sucessful \"appInit\" after wake in \(successUpdateAfterWake)s new UpdateAfterWake interval: \(newUpdateAfterWakeInterval)s")
            wake = nil;
            workItems["appInit"]!.cancel()
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
        
        _ = requestLocationUpdate()
    }
    
    func gotSensorsValues(rdgs: [Reading]?) {
        if rdgs == nil {
            NSLog("\"sensorsValues\" failed")
            goOffline()
            return
        }
        NSLog("\"sensorsValues\" success")
        
        var summs = [Int:Float]()
        var counters = [Int:Int]()
        
        var current: Float = 0
        var curent_counter: Int = 0
        var sensor: Sensor
        
        let sensorsList: [Sensor] = nearbySensorsByTypes.values.joined().flatMap{$0}
        
        for reading in rdgs! {
            sensor = sensorsList.first(where: {sensor in sensor.id == reading.sensor})!
            current = summs.keys.contains(sensor.type.id) ? summs[sensor.type.id]! : 0
            summs.updateValue(current + reading.value, forKey: sensor.type.id)
            
            curent_counter = counters.keys.contains(sensor.type.id) ? counters[sensor.type.id]! : 0
            counters.updateValue(curent_counter + 1, forKey: sensor.type.id)
        }
        
        var newReadings: [Type : Float] = [:];
        
        for (typeId, value) in summs {
            newReadings.updateValue(value / Float(counters[typeId]!), forKey: narodMon.types[typeId])
        }
        
        var nearestUpdate = Date.distantFuture
        
        for (type, reading) in newReadings {
            var newInterval = normalUpdateInterval
            if readingsByTypes.keys.contains(type) {
                let delta = Double(abs(reading - self.readingsByTypes[type]!))
                let currentInterval = -lastSuccessUpdatesByTypes[type]!.timeIntervalSinceNow
                newInterval = 0.1 / (delta / currentInterval)
                let prelog = "\"sensorsValues\": \(type.name), delta: \(delta), interval: \(currentInterval)s => "
                
                if delta == 0 {
                    newInterval = normalUpdateInterval
                }
                NSLog(prelog + "\(newInterval)s")
            }
            
            let nextUpdateDate = Date().addingTimeInterval(newInterval)
            
            nextUpdatesByTypes.updateValue(nextUpdateDate, forKey: type)
            lastSuccessUpdatesByTypes.updateValue(Date(), forKey: type)
        }
        
        let nextUpdates = nextUpdatesByTypes.values.sorted()
        
        let deadLineIn = nextUpdates[nextUpdates.count / 2].timeIntervalSinceNow
        NSLog("Next timer in \(deadLineIn / 60)m")
        
        backgroundDispatchQueue.asyncAfter(deadline: .now() + deadLineIn, execute: workItems["chain"]!)
        
        for (type, value) in newReadings {
            readingsByTypes.updateValue(value, forKey: type)
        }
        goOnline()
        
        for (type, item) in readingsMenuItems {
            if readingsByTypes.keys.contains(type) {
                statusMenu.removeItem(item)
            }
        }
        
        for (type, reading) in readingsByTypes {
            if type.id == 1 {continue}
            let item = NSMenuItem(title: String(format: "%@\t%.1f%@\t(%@)", type.name, reading, type.unit, formatter.string(from: lastSuccessUpdatesByTypes[type]!)), action: nil, keyEquivalent: "")
            readingsMenuItems.updateValue(item, forKey: type)
            statusMenu.insertItem(item, at: 3)
        }
        
        if summs.keys.contains(1) {
            updateTimeMenuItem.title = formatter.string(from: lastSuccessUpdatesByTypes[narodMon.types[1]]!)
            statusItem.title = String.init(format: "%.1f\u{00B0}", summs[1]! / Float(counters[1]!))
        }
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
        
        for sensor in sensors! {
            if !nearbySensorsByTypes.keys.contains(sensor.type) {
                nearbySensorsByTypes.updateValue([], forKey: sensor.type)
            }
            nearbySensorsByTypes[sensor.type]!.append(sensor)
        }
        
        _ = requestSensorsValuesUpdate()
    }
    
    func gotLocation(location: CLLocation?) {
        if location == nil {
            NSLog("Failed to get new location")
            return
        }
        
        NSLog("Got new location: \(location!.debugDescription)")
        latestLocation = Date()
        
        self.location = location
        requestSensorsNearbyUpdate()
    }
}
