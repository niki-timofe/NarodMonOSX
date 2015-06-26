//
//  SetCoordinates.h
//  NarodMon
//
//  Created by Тимофеев Никита on 30.06.14.
//  Copyright (c) 2014 Тимофеев Никита. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NSUserDefaults *userDefaults;

@interface SetCoordinates : NSWindowController
- (IBAction)modeChanged:(NSButton *)sender;
- (IBAction)periodChanged:(NSSlider *)sender;
- (IBAction)helpBtnPress:(id)sender;
- (IBAction)corrdinatesChanged:(NSTextField *)sender;
@property (weak) IBOutlet NSTextFieldCell *coordinatesField;
@property (weak) IBOutlet NSTextField *coordinatesLngField;
@property (weak) IBOutlet NSTextField *sensorID;
@property (weak) IBOutlet NSButton *modeSwitcher;
@property (weak) IBOutlet NSTextField *radiusField;
@property (weak) IBOutlet NSSlider *periodSlider;
@property (weak) IBOutlet NSTextField *periodVisualiser;

@end
