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
    
    var shownType = 1
    
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
        if wake == nil {
            _ = requestLocationUpdate()
        } else {
            _ = requestAppInitUpdate()
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
                (nextUpdatesByTypes[type] ?? Date()) >= Date()
            }).flatMap({_, sensors in
                sensors.map {$0.id}
            })
            if thisUpdateSensors.count > 0 {
                narodMon.sensorsValues(sensors: thisUpdateSensors)
            }
        }
    }
    
    func readingsMenuItemClick(sender: NSMenuItem) {
        if let shownItem = self.statusMenu.item(withTag: self.shownType) {
            shownItem.state = NSOffState
        }
        
        if let typeForStatusItem = narodMon.types[self.shownType] {
            if let readingForShowing = readingsByTypes[typeForStatusItem] {
                shownType = sender.tag
                sender.state = NSOnState
                NSLog("Set shown reading to \(shownType)")
                statusItem.title = String.init(format: "%.1f%@", readingForShowing, typeForStatusItem.unit)
            }
        }
        
    }
    
    func outdatedModal() {
        DispatchQueue.main.async {
            let errorAlert = NSAlert()
            errorAlert.alertStyle = NSAlertStyle.warning
            errorAlert.messageText = "Произошла ошибка при получении данных от API"
            errorAlert.addButton(withTitle: "Проверить")
            errorAlert.addButton(withTitle: "Не проверять")
            errorAlert.informativeText = "Вероятно Вы используете устаревшую версию приложения (v\(Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String)). Стоит проверить, нет ли новой версии на GitHub"
            if errorAlert.runModal() == NSAlertSecondButtonReturn {
                if let url = URL(string: "https://github.com/niki-timofe/NarodMonOSX/releases/latest"), NSWorkspace.shared().open(url) {
                    NSApp.terminate(self.updateAlert)
                }
            }
        }
    }
}

extension StatusMenuController: NarodMonAPIDelegate {
    func goOffline() {
        if (offline) {return}
        NSLog("Going offline")
        offline = true
        statusItem.title = (statusItem.title ?? "") + "?"
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
        
        if let thisWake = wake {
            let successUpdateAfterWake = Date().timeIntervalSince(thisWake),
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
                if self.supressUpdateDialog && self.updateAlert.runModal() == NSAlertFirstButtonReturn {
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
        guard let thisReadings = rdgs else {
            NSLog("\"sensorsValues\" failed")
            goOffline()
            return
        }
        
        NSLog("\"sensorsValues\" success")
        workItems["chain"]!.cancel()
        
        var summs = [Int : Float]()
        var counters = [Int : Int]()
        
        let sensorsList: [Sensor] = nearbySensorsByTypes.values.joined().flatMap{$0}
        
        for reading in thisReadings {
            if let sensor = sensorsList.first(where: {sensor in sensor.id == reading.sensor}) {
                let current = summs[sensor.type.id] ?? 0
                summs.updateValue(current + reading.value, forKey: sensor.type.id)
                
                let curent_counter = counters[sensor.type.id] ?? 0
                counters.updateValue(curent_counter + 1, forKey: sensor.type.id)
            }
        }
        
        var newReadings: [Type : Float] = [:];
        
        for (typeId, value) in summs {
            if let counter = counters[typeId] {
                newReadings.updateValue(value / Float(counter), forKey: narodMon.types[typeId]!)
            }
        }
        
        for (type, reading) in newReadings {
            NSLog(type.name + " " + String(reading))
            guard let thisReading = readingsByTypes[type] else {
                lastSuccessUpdatesByTypes.updateValue(Date(), forKey: type)
                nextUpdatesByTypes.updateValue(Date().addingTimeInterval(normalUpdateInterval), forKey: type)
                readingsByTypes.updateValue(reading, forKey: type)
                NSLog("\"sensorsValues\": \(type.name) => \(normalUpdateInterval)s")
                continue
            }
            readingsByTypes.updateValue(reading, forKey: type)
            
            NSLog(String(reading) + " " + type.name)
            
            let delta = Double(abs(reading - thisReading))
            guard let thisReadingUpdatedAt = lastSuccessUpdatesByTypes[type] else {
                lastSuccessUpdatesByTypes.updateValue(Date(), forKey: type)
                continue
            }
            lastSuccessUpdatesByTypes.updateValue(Date(), forKey: type)
            
            let currentInterval = -thisReadingUpdatedAt.timeIntervalSinceNow
            var newInterval = 0.1 / (delta / currentInterval)
            
            if delta == 0 {
                newInterval = normalUpdateInterval
            }
            
            nextUpdatesByTypes.updateValue(Date().addingTimeInterval(newInterval), forKey: type)
            NSLog("\"sensorsValues\": \(type.name), delta: \(delta), \(currentInterval) => \(newInterval)s")
        }
        
        let nextUpdates = nextUpdatesByTypes.values.drop(while: {$0 < Date()}).sorted()
        
        let deadLineIn = nextUpdates.reduce(0, {prev, cur in
            return prev + cur.timeIntervalSinceNow
        }) / Double(nextUpdates.count)
        
        setWorkItems()
        NSLog("Next timer in \(deadLineIn / 60)m")
        backgroundDispatchQueue.asyncAfter(deadline: .now() + deadLineIn, execute: workItems["chain"]!)
        
        goOnline()
        
        for (type, item) in readingsMenuItems {
            if readingsByTypes.keys.contains(type) {
                statusMenu.removeItem(item)
            }
        }
        
        var readingsStrings = [Type : String]()
        var maxStringLength = 0
        
        for (type, reading) in readingsByTypes {
            let readingString = String(format: "%.1f%@", reading, type.unit)
            let length = readingString.characters.count + type.name.characters.count
            if length > maxStringLength {
                maxStringLength = length
            }
            readingsStrings.updateValue(readingString, forKey: type)
        }
        
        for (type, string) in readingsStrings {
            let item = NSMenuItem(title: "\(type.name)\t\(String(repeating: "\t", count: (maxStringLength - (string.characters.count + type.name.characters.count)) / 7))\(string)", action: #selector(StatusMenuController.readingsMenuItemClick(sender:)), keyEquivalent: "")
            item.tag = type.id
            item.target = self
            item.state = type.id == shownType ? NSOnState : NSOffState
            
            readingsMenuItems.updateValue(item, forKey: type)
            statusMenu.insertItem(item, at: 3)
        }
        
        updateTimeMenuItem.title = formatter.string(from: Date())
        if let typeForStatusItem = narodMon.types[self.shownType] {
            if let readingForShow = readingsByTypes[typeForStatusItem] {
                self.statusItem.title = String.init(format: "%.1f%@", readingForShow, typeForStatusItem.unit)
            }
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
        
        nearbySensorsByTypes.removeAll()
        
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
    
    func gotError(error: URLError) {
        let errorCode = error.errorCode
        if errorCode == NSURLErrorTimedOut || errorCode == NSURLErrorNotConnectedToInternet  {
            return
        }
        NSLog("[API][HTTP]: error: ", error.localizedDescription)
        outdatedModal()
    }
    
    func gotError(error: Error) {
        outdatedModal()
    }
}
