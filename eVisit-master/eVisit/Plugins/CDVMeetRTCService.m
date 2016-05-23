//
//  CDVMeetRTCService.m
//  eVisit
//
//  Created by Sonnaris on 5/23/16.
//
//

#import "CDVMeetRTCService.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <UIKit/UIKit.h>


@implementation CDVMeetRTCService

/* log a message */
- (void)logLevel:(CDVInvokedUrlCommand*)command
{
    id level = [command argumentAtIndex:0];
    id message = [command argumentAtIndex:1];
    
    if ([level isEqualToString:@"LOG"]) {
        NSLog(@"%@", message);
    } else {
        NSLog(@"%@: %@", level, message);
    }
}

- (void)initSettingForMeetRTC:(CDVInvokedUrlCommand *)command {
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"config"])
    {
        //display name and socket configuration -arunkavi
        NSString *deviceName =[[UIDevice currentDevice]name];
        if (deviceName.length==0)
        {
            deviceName=@"iPhone";
        }
        NSDictionary *urls=[[NSDictionary alloc]initWithObjectsAndKeys:deviceName,@"displayName",@"meet.jit.si",@"socket",@"YES",@"secured", nil];
        [[NSUserDefaults standardUserDefaults] setObject:urls forKey:@"config"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    }
}

#pragma mark - Util method

- (void)startAllService {
    
}

@end
