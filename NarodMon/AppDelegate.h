//
//  AppDelegate.h
//  NarodMon
//
//  Created by Тимофеев Никита on 30.06.14.
//  Copyright (c) 2014 Тимофеев Никита. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CommonCrypto/CommonDigest.h>
#import "SetCoordinates.h"

extern NSString* const apiKey;

NSUserDefaults *userDefaults;

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    SetCoordinates *coordsWindow;
}

typedef NS_ENUM(NSUInteger, Type) {
    DEGREES = 1
};

@property (strong) IBOutlet NSStatusItem *statusBar;
@property (weak) IBOutlet NSMenu *statusMenu;
@property (weak) IBOutlet NSMenuItem *latestUpdateTime;

- (NSString*)formatOutput:(float)value withSign:(Type)sign;
- (IBAction)updateBtnPress:(NSMenuItem *)sender;
- (IBAction)setCoordinatesBtnPress:(NSMenuItem *)sender;

-(void)apiRequest:(NSDictionary*)dictionary;

@end

@interface NSString (MD5_Hash)
+ (NSString *) md5:(NSString*)concat;
@end