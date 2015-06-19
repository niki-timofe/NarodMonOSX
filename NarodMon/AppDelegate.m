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
    [self update];
}

- (IBAction)setCoordinatesBtnPress:(NSMenuItem *)sender {
    if (!coordsWindow) {
        coordsWindow = [[SetCoordinates alloc]
                        initWithWindowNibName:@"SetCoordinates"];
    }
    [coordsWindow showWindow:self];
}

- (void)update
{
    NSDictionary *dictionary;
    
    if (![userDefaults boolForKey:@"SensorMode"]) {
        float lat = [userDefaults floatForKey:@"CoordinatesLat"];
        float lng = [userDefaults floatForKey:@"CoordinatesLng"];
        
        dictionary = @{@"cmd": @"sensorNear",
                       @"lat":[NSNumber numberWithFloat:lat],
                       @"lng":[NSNumber numberWithFloat:lng],
                       @"radius":@3,
                       @"uuid":uuidStr,
                       @"api_key":apiKey,
                       @"lang":@"ru",
                       @"types":[NSArray arrayWithObject:@1],
                       @"pub":@1};
    } else {
        dictionary = @{@"cmd": @"sensorInfo",
                       @"sensors":[NSArray arrayWithObject:[userDefaults stringForKey:@"SensorID"]],
                       @"uuid":uuidStr,
                       @"api_key":apiKey,
                       @"lang":@"ru"};
    }
    
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:0
                                                         error:&error];
    
    if (jsonData) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://narodmon.ru/client.php"]];
        [request setHTTPMethod:@"POST"];
        
        [request setHTTPBody:jsonData];
        (void)[[NSURLConnection alloc] initWithRequest:request delegate:self];
    } else {
        NSLog(@"Unable to serialize the data %@: %@", dictionary, error);
    }
    
    
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    // A response has been received, this is where we initialize the instance var you created
    // so that we can append data to it in the didReceiveData method
    // Furthermore, this method is called each time there is a redirect so reinitializing it
    // also serves to clear it
    _responseData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    // Append the new data to the instance variable you declared
    [_responseData appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    // Return nil to indicate not necessary to store a cached response for this connection
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    // The request is complete and data has been received
    // You can parse the stuff in your instance variable now
    
    NSError *error;
    NSMutableDictionary *json = [NSJSONSerialization
                                 JSONObjectWithData:_responseData
                                 options: NSJSONReadingMutableContainers
                                 error: &error];
    
    NSLog(@"%@", json[@"latest"]);
    
    if (!json[@"latest"]) {
        if (![userDefaults boolForKey:@"SensorMode"]) {
            float min = FLT_MAX;
            float sum = 0;
            float count = 0;
            float tmp = 0;
            
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
            
            self.statusBar.title = [self
                                    formatOutput:((min + (min + sum / count) / 2) / 2)
                                    withSign:1];
        } else {
            self.statusBar.title = [self formatOutput:[json[@"sensors"][0][@"value"]
                                                       floatValue] withSign:1];
        }
        
        NSDateFormatter *formatter;
        NSString        *dateString;
        
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm"];
        
        dateString = [formatter stringFromDate:[NSDate date]];
        [[self latestUpdateTime] setTitle:dateString];
        
    } else {
        
        if (![userDefaults objectForKey:@"CoordinatesLat"]) {
            [userDefaults setFloat:[json[@"lat"] floatValue]  forKey:@"CoordinatesLat"];
            [userDefaults setFloat:[json[@"lng"] floatValue]  forKey:@"CoordinatesLng"];
        }
        
        [self update];
        timer = [NSTimer scheduledTimerWithTimeInterval:5*60
                                                 target:self
                                               selector:@selector(update)
                                               userInfo:nil
                                                repeats:YES];
        
        NSLog(@"%@", json);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    // The request has failed for some reason!
    // Check the error var
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
        NSLog(@"Unable to serialize the data %@: %@", dictionary, error);
    }
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
    
    if (![userDefaults objectForKey:@"uuid"]) {
        CFUUIDRef uuid = CFUUIDCreate(NULL);
        uuidStr = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
        [userDefaults setValue:uuidStr  forKey:@"uuid"];
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
    
    //self.statusBar.image =
    
    self.statusBar.menu = self.statusMenu;
    self.statusBar.highlightMode = YES;
}
@end
