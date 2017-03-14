//
//  StatusMenuController.swift
//  NarodMonWidget
//
//  Created by Никита Тимофеев on 27.10.16.
//  Copyright © 2016 Никита Тимофеев. All rights reserved.
//

import Cocoa

class StatusMenuController: NSObject, NarodMonAPIDelegate {
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var updateMenuItem: NSMenuItem!
    @IBOutlet weak var readingsTable: NSTableView!
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    var narodMonAPI: NarodMonAPI!
    var sensorsList: [Int:Type] = [:]
    var updateTimer: Timer!
    
    var results = [Int:Float]()
    var counters = [Int:Float]()

    override func awakeFromNib() {        
        narodMonAPI = NarodMonAPI(delegate: self)
        statusItem.title = "~"
        statusItem.menu = statusMenu
    }
    
    @IBAction func updateBtnAction(_ sender: NSMenuItem) {
        narodMonAPI.sensorsNearby()
    }
    
    func gotSensorsList(sensors: [Sensor]) {
        var sensList: [Int] = []
        
        for sensor in sensors {
            sensorsList.updateValue(sensor.type, forKey: sensor.id)
            sensList.append(sensor.id)
        }
        //narodMonAPI.sensorsValues(sensors: sensList)
        
        if (updateTimer != nil) {
            updateTimer.invalidate()
        }
        updateTimer = Timer.init(timeInterval: 3 * 60, target: self, selector: #selector(StatusMenuController.performUpdateValues), userInfo:nil , repeats: true)
        RunLoop.main.add(updateTimer, forMode: RunLoopMode.commonModes)
        updateTimer.fire()
    }
    
    func gotSensorsValues(rdgs: [Reading]) {
        for reading in rdgs {
            if let result = results[sensorsList[reading.sensor]!.id] {
                results.updateValue(result + reading.value,
                                    forKey: sensorsList[reading.sensor]!.id)
                counters.updateValue(counters[sensorsList[reading.sensor]!.id]! + 1.0,
                                     forKey: sensorsList[reading.sensor]!.id)

            } else {
                results.updateValue(reading.value,
                                    forKey: sensorsList[reading.sensor]!.id)
                counters.updateValue(1.0,
                                     forKey: sensorsList[reading.sensor]!.id)
            }
        }
    
        statusItem.title = String(format: "%.1f%@ ",
                                 results[1]! / counters[1]!,
                                 narodMonAPI.types[1].unit)
        
        let updateTime = Calendar.current.dateComponents([.hour, .minute], from: Date())
        updateMenuItem.title = String(format: "Обновить (%d:%d)", updateTime.hour!, updateTime.minute!)
    }
    
    func performUpdateValues() -> Void {
        narodMonAPI.sensorsValues(sensors: Array(sensorsList.keys))
    }
    
    func appInitiated(app: App) {
        if app.latest > Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String {
            let alert = NSAlert()
            alert.addButton(withTitle: "Сейчас")
            alert.addButton(withTitle: "Потом")
            alert.messageText = "Доступна новая версия виджета."
            alert.informativeText = "Вы хотие обновить сейчас?"
            alert.alertStyle = NSInformationalAlertStyle
            
            DispatchQueue.main.sync {
                if alert.runModal() == NSAlertFirstButtonReturn {
                    
                }
            }
        }
        
        narodMonAPI.sensorsNearby()
    }
    
    @IBAction func quitBtnAction(_ sender: NSMenuItem) {
        NSApplication.shared().terminate(self)
    }
}

extension StatusMenuController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return (results.count)
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?{
        var result = ""
        
        let type = Array(results.keys).sorted()[row]
        
        let columnIdentifier = tableColumn?.identifier
        if columnIdentifier == "type" {
            result = narodMonAPI.types[type].unit
        }
        if columnIdentifier == "name" {
            result = narodMonAPI.types[type].name
        }
        if columnIdentifier == "value" {
            result = String(format:"%.1f", results[type]! / counters[type]!)
        }
        return result
    }
}
