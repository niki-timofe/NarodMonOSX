//
//  StatusMenuController.swift
//  NarodMonMenubarApp
//
//  Created by Никита Тимофеев on 22.03.17.
//  Copyright © 2017 Nikita Timofeev. All rights reserved.
//

import Cocoa
import Foundation
import CoreLocation

class StatusMenuController: NSObject {
    let statusItem: NSStatusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    let narodMon: NarodMonAPI
    
    let formatter = DateFormatter()
    
    var statusMenu: NSMenu = NSMenu()
    let updateTimeMenuItem: NSMenuItem = NSMenuItem()
    
    var readingsMenuItems: [NSMenuItem] = []
    
    var updateAlert = NSAlert()
    
    var location: CLLocation?
    var fetchTimer: Timer?
    var querySensors: [Int] = []
    
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
        updateTimeMenuItem.title = " :  "
        narodMon.delegate = self
        narodMon.appInit()
        
        updateAlert.messageText = "Доступна новая версия"
        updateAlert.informativeText = "Доступна новая версия приложения. Загрузить сейчас?"
        updateAlert.alertStyle = NSAlertStyle.warning
        updateAlert.showsSuppressionButton = true
        updateAlert.addButton(withTitle: "Загрузить")
        updateAlert.addButton(withTitle: "Отменить")
    }
    
    func updateBtnPress(sender: NSMenuItem) {
        if app == nil {narodMon.appInit()}
        narodMon.sensorsNearby()
    }
    
    func quitBtnPress(sender: NSMenuItem) {
        NSApp.terminate(sender)
    }
    
    func updateLocation(location: CLLocation?) {
        self.location = location
        narodMon.userLocation(location: location)
    }
    
}
extension StatusMenuController: NarodMonAPIDelegate {
    func goOffline() {
        if (offline) {return}
        offline = true
        statusItem.title = statusItem.title! + "?"
    }
    
    func goOnline() {
        offline = false
    }
    
    
    func appInitiated(app: App?) {
        if (app == nil) {
            goOffline()
            return
        } else {
            goOnline()
        }
        self.app = app
        
        if (UInt16(app!.latest) ?? UInt16.max <= UInt16(Bundle.main.infoDictionary?["CFBundleVersion"] as! String)!) {return;}
        

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
    func gotSensorsValues(rdgs: [Reading]?) {
        if rdgs == nil {
            goOffline()
            return
        } else {
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
            goOffline()
            return
        } else {
            goOnline()
        }
        
        querySensors = []
        nearbySensors = sensors!
        
        for sensor in sensors! {
            querySensors.append(sensor.id)
        }
        
        if (fetchTimer != nil) {fetchTimer?.invalidate()}
        
        DispatchQueue.main.async {
            self.fetchTimer = Timer.scheduledTimer(withTimeInterval: 7.5 * 60, repeats: true, block: {_ in
                self.narodMon.sensorsValues(sensors: self.querySensors)
            })
            self.fetchTimer!.fire()
        }
    }
    func gotLocation(location: CLLocation?) {
        self.location = location
        if app == nil {narodMon.appInit()}
        narodMon.sensorsNearby()
    }
}
