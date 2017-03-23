//
//  main.swift
//  NarodMonMenubarApp
//
//  Created by Никита Тимофеев on 22.03.17.
//  Copyright © 2017 Nikita Timofeev. All rights reserved.
//

import Cocoa

let delegate = AppDelegate()

NSApplication.shared().delegate = delegate

let ret = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
