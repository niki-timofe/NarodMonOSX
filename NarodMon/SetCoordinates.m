//
//  SetCoordinates.m
//  NarodMon
//
//  Created by Тимофеев Никита on 30.06.14.
//  Copyright (c) 2014 Тимофеев Никита. All rights reserved.
//

#import "SetCoordinates.h"

@interface SetCoordinates ()

@end

@implementation SetCoordinates

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    userDefaults = [NSUserDefaults standardUserDefaults];
    [[self coordinatesField] setFloatValue:[userDefaults floatForKey:@"CoordinatesLat"]];
    [[self coordinatesLngField] setFloatValue:[userDefaults floatForKey:@"CoordinatesLng"]];
    [[self sensorID] setFloatValue:[userDefaults
        floatForKey:@"SensorID"]];
    [[self window] setLevel:NSFloatingWindowLevel];
    
}

- (IBAction)corrdinatesChanged:(NSTextField *)sender {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([sender integerValue] > 0) {
        switch (sender.tag) {
            case 0:
                [userDefaults setFloat:[sender floatValue]  forKey:@"CoordinatesLat"];
                break;
            case 1:
                [userDefaults setFloat:[sender floatValue]  forKey:@"CoordinatesLng"];
                break;
            case 2:
                [userDefaults setFloat:[sender floatValue]
                    forKey:@"SensorID"];
                break;
            default:
                break;
        }
    }
    
}
@end
