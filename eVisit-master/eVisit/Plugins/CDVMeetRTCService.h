//
//  CDVMeetRTCService.h
//  eVisit
//
//  Created by Sonnaris on 5/23/16.
//
//

#import <Cordova/CDVPlugin.h>

@interface CDVMeetRTCService : CDVPlugin

- (void)logLevel:(CDVInvokedUrlCommand*)command;
- (void)initSettingForMeetRTC:(CDVInvokedUrlCommand *)command;

@end
