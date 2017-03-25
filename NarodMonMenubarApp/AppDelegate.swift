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
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        locationManager = CLLocationManager()
        locationManager!.delegate = self
        locationManager!.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager!.distanceFilter = 1000
        controller = StatusMenuController()
        
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(AppDelegate.wakeUpListener(_:)), name: NSNotification.Name.NSWorkspaceDidWake, object: nil)
    }
    
    func wakeUpListener(_ aNotification : NSNotification) {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: false, block: {_ in
            if (self.locationTimer != nil) {
                self.controller!.narodMon.appInit()
                self.locationTimer!.fire()
            }
        })
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        locationManager!.stopUpdatingLocation()
    }
    
}

extension AppDelegate: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateTo newLocation: CLLocation, from oldLocation: CLLocation) {
        controller!.updateLocation(location: newLocation)
        locationManager!.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == CLAuthorizationStatus.authorizedAlways {
            if CLLocationManager.locationServicesEnabled() {
                if locationTimer != nil {locationTimer?.invalidate()}
                
                DispatchQueue.main.async {
                    self.locationTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true, block: {_ in
                        self.locationManager!.startUpdatingLocation()
                    })
                    self.locationTimer!.fire()
                }
            }
        } else {
            controller!.updateLocation(location: nil)
        }
    }
}
