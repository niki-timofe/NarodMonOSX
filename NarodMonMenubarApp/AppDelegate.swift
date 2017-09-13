//
//  AppDelegate.swift
//  NarodMonMenubarApp
//
//  Created by Никита Тимофеев on 22.03.17.
//  Copyright © 2017 Nikita Timofeev. All rights reserved.
//

import Cocoa
import CoreLocation

class AppDelegate: NSObject, NSApplicationDelegate {
    var locationManager: CLLocationManager?
    var controller: StatusMenuController?
    var locationTimer: Timer?
    var userDefaults: UserDefaults = UserDefaults.standard
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        locationManager = CLLocationManager()
        locationManager!.delegate = self
        locationManager!.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager!.distanceFilter = 1000
        
        userDefaults.register(defaults: ["UpdateAfterWake": 15])
        
        controller = StatusMenuController()
        
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(AppDelegate.wakeListener(_:)), name: NSNotification.Name.NSWorkspaceDidWake, object: nil)
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(AppDelegate.sleepListener(_:)), name: NSNotification.Name.NSWorkspaceWillSleep, object: nil)
    }
    
    func sleepListener(_ aNotification: NSNotification) {
        self.controller!.workItems.values.forEach {item in item.cancel()}
        self.controller!.wake = nil
        locationManager!.stopUpdatingLocation()
        NSLog("Sleep!")
    }
    
    func wakeListener(_ aNotification: NSNotification) {
        self.controller!.goOffline()
        self.controller!.wake = Date()
        self.controller!.setWorkItems()
        NSLog("Wake!")
        let deadline = userDefaults.double(forKey: "UpdateAfterWake")
        NSLog("Will try appInit after \(deadline)s")
        self.controller!.backgroundDispatchQueue.asyncAfter(deadline: .now() + deadline, execute: self.controller!.workItems["appInit"]!)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        locationManager!.stopUpdatingLocation()
    }
    
}

extension AppDelegate: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateTo newLocation: CLLocation, from oldLocation: CLLocation) {
        locationManager!.stopUpdatingLocation()
        NSLog("Got location from \"locationManager\"")
        controller!.updateLocation(location: newLocation)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationManager!.stopUpdatingLocation()
        NSLog("\"locationManager\" error: \(error), calling controller's \"updateLocation\" with nil argument")
        controller!.updateLocation(location: nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if CLLocationManager.locationServicesEnabled() {
            if status == CLAuthorizationStatus.authorizedAlways {
                self.locationManager!.startUpdatingLocation()
            }
        }
    }
}
