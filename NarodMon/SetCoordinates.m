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
    [[self coordinatesField] setFloatValue:[userDefaults
                                            floatForKey:@"CoordinatesLat"]];
    [[self coordinatesLngField] setFloatValue:[userDefaults
                                            floatForKey:@"CoordinatesLng"]];
    [[self sensorID] setIntegerValue:[userDefaults integerForKey:@"SensorID"]];
    [[self radiusField] setIntegerValue:[userDefaults integerForKey:@"Radius"]];
    
    [[self modeSwitcher] setState:[userDefaults boolForKey:@"SensorMode"]];
    [[self periodVisualiser] setStringValue:[userDefaults stringForKey:@"UpdateInterval"]];
    [[self periodSlider] setIntegerValue:[userDefaults integerForKey:@"UpdateInterval"]];
    [self modeChanged:[self modeSwitcher]];
    
    [[self window] setLevel:NSFloatingWindowLevel];
    
}

- (IBAction)modeChanged:(NSButton *)sender {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    if ([sender state] == NSOnState) {
        [userDefaults setBool:YES forKey:@"SensorMode"];
        [[self coordinatesField] setEnabled:NO];
        [[self coordinatesLngField] setEnabled:NO];
        [[self sensorID] setEnabled:YES];
    } else {
        [userDefaults setBool:NO forKey:@"SensorMode"];
        [[self coordinatesField] setEnabled:YES];
        [[self coordinatesLngField] setEnabled:YES];
        [[self sensorID] setEnabled:NO];
    }
}

- (IBAction)periodChanged:(NSSlider *)sender {
    [userDefaults setInteger:[sender integerValue] forKey:@"UpdateInterval"];
    [[self periodVisualiser] setIntegerValue:[sender integerValue]];
}

- (IBAction)helpBtnPress:(id)sender {
    [NSApp orderFrontStandardAboutPanel:self];
}

- (IBAction)corrdinatesChanged:(NSTextField *)sender {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([sender integerValue] > 0) {
        switch (sender.tag) {
            case 0:
                [userDefaults setFloat:[sender floatValue]
                                forKey:@"CoordinatesLat"];
                break;
            case 1:
                [userDefaults setFloat:[sender floatValue]
                                forKey:@"CoordinatesLng"];
                break;
            case 2:
                [userDefaults setInteger:[sender integerValue]
                                forKey:@"SensorID"];
                break;
            case 3:
                [userDefaults setInteger:[sender integerValue]
                                forKey:@"Radius"];
                break;
            default:
                break;
        }
    }
    
}
@end
