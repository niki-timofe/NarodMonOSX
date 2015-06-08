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
- (IBAction)corrdinatesChanged:(NSTextField *)sender;
@property (weak) IBOutlet NSTextFieldCell *coordinatesField;
@property (weak) IBOutlet NSTextField *coordinatesLngField;
@property (weak) IBOutlet NSTextField *sensorID;

@end
