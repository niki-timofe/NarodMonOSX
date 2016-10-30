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
    @IBOutlet weak var weatherView: WeatherView!
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    var weatherMenuItem: NSMenuItem!
    var narodMonAPI: NarodMonAPI!
    var sensorsList: [Int:Type] = [:]

    override func awakeFromNib() {
        weatherMenuItem = statusMenu.item(withTitle: "Weather")
        weatherMenuItem.view = weatherView
        
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
        narodMonAPI.sensorsValues(sensors: sensList)
    }
    
    func gotSensorsValues(rdgs: [Reading]) {
        var inTitle = ""
        
        var results = [Int:Float]()
        var counters = [Int:Float]()
        
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
        
        for type in Array(results.keys).sorted() {
            inTitle += String(format: "%@: %.1f%@\n",
                              narodMonAPI.types[type].name,
                              results[type]! / counters[type]!,
                              narodMonAPI.types[type].unit)
        }
        inTitle = inTitle.substring(to: inTitle.index(before: inTitle.endIndex))
        weatherView.conditionsTextField.stringValue = inTitle
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
