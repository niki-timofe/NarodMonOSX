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
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    var narodMonAPI: NarodMonAPI!

    override func awakeFromNib() {
        narodMonAPI = NarodMonAPI(delegate: self)
        statusItem.title = "~º"
        statusItem.menu = statusMenu
    }
    
    func gotSensorsValues(rdgs: [Reading]) {
        var inTitle = ""
        for reading in rdgs {
            inTitle += String(format: "%f%@ ", reading.value, reading.type.unit)
        }
        inTitle = inTitle.substring(to: inTitle.index(before: inTitle.endIndex))
        statusItem.title = inTitle
    }
    
    func appInitiated(app: App) {
        if app.latest < Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String {
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
    }
    
    @IBAction func quitBtnAction(_ sender: NSMenuItem) {
        NSApplication.shared().terminate(self)
    }
}
