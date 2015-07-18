//
//  AppDelegate.m
//  NarodMon
//
//  Created by Тимофеев Никита on 30.06.14.
//  Copyright (c) 2014 Тимофеев Никита. All rights reserved.
//

#import "AppDelegate.h"

NSString *const apiKey = @"40MHsctSKi4y6";
NSMutableData *_responseData;
NSTimer *timer;
NSString *uuidStr;
NSTimeInterval latestFetch, latestInit;
NSTimeInterval const sensorInitInterval = 2 * 60;
BOOL isStandby = NO;

@implementation NSString (MD5_Hash)

+ (NSString *) md5:(NSString*)concat {
    const char *concat_str = [concat UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(concat_str, (CC_LONG)strlen(concat_str), result);
    NSMutableString *hash = [NSMutableString string];
    for (int i = 0; i < 16; i++)
        [hash appendFormat:@"%02X", result[i]];
    return [hash lowercaseString];
}

@end

@implementation AppDelegate

@synthesize statusBar = _statusBar;

- (NSString*)formatOutput:(float)value withSign:(Type)sign
{
    NSString *sig = @"";
    switch (sign) {
        case DEGREES:
            sig = @"º";
            break;
        default:
            sig = @"";
            break;
    }
    return [NSString stringWithFormat:@"%.1f%@", value, sig];
}

- (IBAction)updateBtnPress:(NSMenuItem *)sender {
    [self sensorInit];
}

- (void)openCoordsWindow {
    if (!coordsWindow) {
        coordsWindow = [[SetCoordinates alloc]
                        initWithWindowNibName:@"SetCoordinates"];
    }
    [coordsWindow showWindow:self];
}

- (IBAction)setCoordinatesBtnPress:(NSMenuItem *)sender {
    [self openCoordsWindow];
}

- (void)updateWithRadius:(NSInteger)radius
{
    NSMutableDictionary *dictionary;
    
    if (![userDefaults boolForKey:@"SensorMode"]) {
        float lat = [userDefaults floatForKey:@"CoordinatesLat"];
        float lng = [userDefaults floatForKey:@"CoordinatesLng"];
        
        dictionary = [[NSMutableDictionary alloc] initWithDictionary:
                     @{@"cmd": @"sensorNear",
                       @"lat":[NSNumber numberWithFloat:lat],
                       @"lng":[NSNumber numberWithFloat:lng],
                       @"uuid":uuidStr,
                       @"api_key":apiKey,
                       @"lang":@"ru",
                       @"types":[NSArray arrayWithObject:@1],
                       @"pub":@1}];
        
        if (radius > 0) {
            [dictionary setObject:[NSNumber numberWithInteger:radius] forKey:@"radius"];
        } else {
            [dictionary setObject:[NSNumber numberWithInteger:1] forKey:@"limit"];
        }
        
    } else {
        dictionary = [[NSMutableDictionary alloc] initWithDictionary:
                     @{@"cmd": @"sensorInfo",
                       @"sensors":[NSArray arrayWithObject:
                                   [NSNumber numberWithInteger:
                                    [userDefaults integerForKey:@"SensorID"]]],
                       @"uuid":uuidStr,
                       @"api_key":apiKey,
                       @"lang":@"ru"}];
    }
    
    [self apiRequest:dictionary];
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)respoapinse {
    _responseData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_responseData appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    return nil;
}

- (void)makeUpdate
{
    latestFetch = [[NSDate date] timeIntervalSince1970];
    [self updateWithRadius:[userDefaults integerForKey:@"Radius"]];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSError *error;
    NSMutableDictionary *json = [NSJSONSerialization
                                 JSONObjectWithData:_responseData
                                 options: NSJSONReadingMutableContainers
                                 error: &error];
    
    if (!json[@"latest"]) {
        if (![userDefaults boolForKey:@"SensorMode"]) {
            float min = FLT_MAX;
            float sum = 0;
            float count = 0;
            float tmp = 0;
            
            if ([userDefaults integerForKey:@"SensorID"] == 0) {
                [userDefaults setInteger:[json[@"devices"][0][@"sensors"][0][@"id"] longValue] forKey:@"SensorID"];
            }
            
            for (int i = 0; i < [json[@"devices"] count]; i++) {
                for (int ii = 0; ii < [json[@"devices"][i][@"sensors"] count]; ii++) {
                    
                    if ([json[@"devices"][i][@"sensors"][ii][@"type"] floatValue] == 1) {
                        tmp = [json[@"devices"][i][@"sensors"][ii][@"value"] floatValue];
                        
                        sum += tmp;
                        count++;
                        
                        if (min > tmp) {
                            min = tmp;
                        }
                    }
                }
            }
            
            if  (count == 0) {
                [self updateWithRadius:0];
            }
            
            self.statusBar.title = [self
                                    formatOutput:((min + (min + sum / count) / 2) / 2)
                                    withSign:1];
        } else {
            self.statusBar.title = [self formatOutput:[json[@"sensors"][0][@"value"]
                                                       floatValue] withSign:1];
        }
        
        isStandby = NO;
        [self.statusBar.button setAppearsDisabled:NO];
        
        NSDateFormatter *formatter;
        NSString        *dateString;
        
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm"];
        
        dateString = [formatter stringFromDate:[NSDate date]];
        [[self latestUpdateTime] setTitle:dateString];
        
    } else {
        
        NSComparisonResult comparsion = [[NSString stringWithFormat:@"%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]] compare:json[@"latest"] options:NSNumericSearch];
        
        if (comparsion == NSOrderedAscending)
            {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"Сейчас"];
                [alert addButtonWithTitle:@"Потом"];
                [alert setMessageText:@"Доступна новая версия виджета народного мониторинга."];
                [alert setInformativeText:@"Вы можете загрузить новую версию сейчас, или потом."];
                [alert setAlertStyle:NSInformationalAlertStyle];
            
                if ([alert runModal] == NSAlertFirstButtonReturn) {
                    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:json[@"url"]]];
                    [NSApp terminate:self];
                }
            }  
        
        
        if (![userDefaults objectForKey:@"Radius"]) {
            [userDefaults setInteger:1 forKey:@"Radius"];
        }
        if (![userDefaults objectForKey:@"CoordinatesLat"]) {
            [userDefaults setFloat:[json[@"lat"] floatValue]  forKey:@"CoordinatesLat"];
            [userDefaults setFloat:[json[@"lng"] floatValue]  forKey:@"CoordinatesLng"];
            [self openCoordsWindow];
        }
        
        if ([timer isValid]) {
            [timer invalidate];
            timer = nil;
        }
        
        timer = [NSTimer scheduledTimerWithTimeInterval: 5
                                                 target:self
                                               selector:@selector(timerEvent)
                                               userInfo:nil
                                                repeats:YES];
        
        [self makeUpdate];
    }
}

- (void)timerEvent {
    if ((latestInit + sensorInitInterval * 60  < [[NSDate date] timeIntervalSince1970]) || isStandby) {
        [self sensorInit];
    } else if (latestFetch + [userDefaults integerForKey:@"UpdateInterval"] * 60  < [[NSDate date] timeIntervalSince1970]) {
        [self makeUpdate];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    isStandby = YES;
    [self.statusBar.button setAppearsDisabled:YES];
}


- (void)apiRequest:(NSDictionary *)dictionary
{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:0
                                                         error:&error];
    
    if (jsonData) {
        NSMutableURLRequest *request = [NSMutableURLRequest
                                        requestWithURL:[NSURL
                                                        URLWithString:@"http://narodmon.ru/client.php"]];
        
        [request setHTTPMethod:@"POST"];
        
        [request setHTTPBody:jsonData];
        (void)[[NSURLConnection alloc] initWithRequest:request delegate:self];
    } else {
    }
}

- (NSString *)serialNumber
{
    io_service_t    platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                                 
                                                                 IOServiceMatching("IOPlatformExpertDevice"));
    CFStringRef serialNumberAsCFString = NULL;
    
    if (platformExpert) {
        serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert,
                                                                 CFSTR(kIOPlatformSerialNumberKey),
                                                                 kCFAllocatorDefault, 0);
        IOObjectRelease(platformExpert);
    }
    
    NSString *serialNumberAsNSString = nil;
    if (serialNumberAsCFString) {
        serialNumberAsNSString = [NSString stringWithString:(__bridge NSString *)serialNumberAsCFString];
        CFRelease(serialNumberAsCFString);
    }
    
    return serialNumberAsNSString;
}

- (void)sensorInit
{
    latestInit = [[NSDate date] timeIntervalSince1970];
    
    if ([userDefaults stringForKey:@"uuid"] != [self serialNumber]) {
        uuidStr = [self serialNumber];
        
        [userDefaults setValue:uuidStr forKey:@"uuid"];
    } else {
        uuidStr = [userDefaults stringForKey:@"uuid"];
    }
    
    uuidStr = [NSString md5:uuidStr];
    
    [self apiRequest:@{@"cmd":@"sensorInit",
                       @"version":[NSString stringWithFormat:@"%@",
                                   [[NSBundle mainBundle]
                                    objectForInfoDictionaryKey:@"CFBundleShortVersionString"]],
                       @"platform":[NSString stringWithFormat:@"%ld.%ld.%ld", (long)[[NSProcessInfo processInfo] operatingSystemVersion].majorVersion, (long)[[NSProcessInfo processInfo] operatingSystemVersion].minorVersion, (long)[[NSProcessInfo processInfo] operatingSystemVersion].patchVersion],
                       @"lang":@"ru",
                       @"uuid":uuidStr,
                       @"api_key":apiKey,}];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.statusBar = [[NSStatusBar systemStatusBar]
                      statusItemWithLength:NSVariableStatusItemLength];
    
    self.statusBar.title = [self formatOutput:0 withSign:DEGREES];
    
    userDefaults = [NSUserDefaults standardUserDefaults];
    
    if (![userDefaults objectForKey:@"SensorID"]) {
        [userDefaults setInteger:0 forKey:@"SensorID"];
        [userDefaults setBool:NO forKey:@"SensorMode"];
    }
    
    if (![userDefaults objectForKey:@"UpdateInterval"]) {
        [userDefaults setObject:@3 forKey:@"UpdateInterval"];
    }
    
    [self sensorInit];
    
    timer = [NSTimer scheduledTimerWithTimeInterval: 5
                                             target:self
                                           selector:@selector(timerEvent)
                                           userInfo:nil
                                            repeats:YES];
    
    //self.statusBar.image =
    
    self.statusBar.menu = self.statusMenu;
    self.statusBar.highlightMode = YES;
}
@end
