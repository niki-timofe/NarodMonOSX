//
//  StatusMenuController.swift
//  NarodMonMenubarApp
//
//  Created by Никита Тимофеев on 22.03.17.
//  Copyright © 2017 Nikita Timofeev. All rights reserved.
//

import Cocoa
import CoreLocation

class StatusMenuController: NSObject {
    let statusItem: NSStatusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    var location: CLLocation?
    var offline: Bool = true
    
    init(withLocation loc: CLLocation?) {
        statusItem.title = "…"
        location = loc
        super.init()
    }
}
