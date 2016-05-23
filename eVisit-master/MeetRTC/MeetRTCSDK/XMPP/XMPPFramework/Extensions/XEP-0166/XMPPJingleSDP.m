//
//  XMPPJingleSDP.m
//  meet-webrtc-sdk
//
//  Created by Ganvir, Manish (Contractor) on 2/6/15.
//  Copyright 2014 Comcast Cable Communications Management, LLC.
//

#import <Foundation/Foundation.h>
#import "XMPPJingleSDP.h"
#import "JAHConvertSDP.h"
#define SDP_GROUP_XMLNS @"urn:xmpp:jingle:apps:grouping:0"

@implementation XMPPJingleSDPUtil

- (NSString *)parseGroups:(XMPPIQ *)iq
{
    NSMutableString *groupStr = [[NSMutableString alloc]init]; // TO be set once ready
    NSMutableArray *names = [[NSMutableArray alloc] init];
    // Get group content
    /* NSArray *groups = [[iq elementForName:@"jingle"] elementForName:@"group"];
     if (groups != nil)
     {
     NSLog(@"Error in retrieving groups");
     }
     
     NSMutableArray *names = [[NSMutableArray alloc] init];
     NSXMLElement *group;
     if ([groups count] > 0)
     {
     group = [[iq elementForName:@"jingle"] elementForName:@"group"];
     }
     else
     {
     group = (NSXMLElement *)[groups objectAtIndex:0];   // TBD: for multiple groups
     }*/
    NSXMLElement *jElement;
    NSXMLElement *group;
    
    jElement = [iq elementForName:@"jingle" xmlns:XEP_0166_XMLNS];
    if (jElement == nil)
    {
        NSLog(@"XMPP Parsing: No Jingle element");
        
        return NULL;
    }
    group = [[iq elementForName:@"jingle"] elementForName:@"group"];
    if (group == nil)
    {
        NSLog(@"XMPP Parsing: No group element");
        return NULL;
    }
    NSArray *contents = [group elementsForName:@"content"];
    if(contents != nil)
    {
        for (int i=0; i<[contents count]; i++){
            
            NSXMLElement *content = (NSXMLElement *)[contents objectAtIndex:i];
            
            if(content != nil)
            {
                [names addObject:[content attributeStringValueForName:@"name"]];
            }
        }
    }
    
    NSString *semantics = [group attributeStringValueForName:@"semantics"];
    
    [groupStr appendString:@"a=group:"];
    [groupStr appendString:semantics];
    
    for (int i=0; i<[names count]; i++)
    {
        [groupStr appendString:@" "];
        [groupStr appendString:(NSString *)[names objectAtIndex:i]];
    }
    
    [groupStr appendString:@"\r\n"];
    
    return groupStr;
}

- (NSString *)parseMedia:(NSXMLElement *)content
{
    NSMutableString *contentString = [[NSMutableString alloc]init];
    
    // Media line is m=audio 1 RTP/SAVPF 111 103 ...
    // Or            m=video 1 RTP/SAVPF 100 116
    // Find out the media type
    // So we need codec list before we could create this line
    NSArray *codeclist = [[content elementForName:@"description"] elementsForName:@"payload-type"];
    
    //issue #7 - Enhancement
    //dynamically choose RTP / SCTP based on data or other contents
    NSString *contentname=(NSString *)[content attributeStringValueForName:@"name"];
    NSXMLElement * transportInfo = [content elementForName:@"transport"];
    NSXMLElement * sctpmapInfo = [transportInfo elementForName:@"sctpmap"];
    
    if ([contentname caseInsensitiveCompare:@"data"]==NSOrderedSame)
    {
        [contentString appendFormat:@"m=%@ 1 DTLS/SCTP %@",(NSString *)[content attributeStringValueForName:@"name"],(NSString *)[sctpmapInfo attributeStringValueForName:@"number"]];
    }
    else
    {
        [contentString appendFormat:@"m=%@ 1 RTP/SAVPF",(NSString *)[content attributeStringValueForName:@"name"]];
    }

    for (int i=0; i<[codeclist count]; i++)
    {
        [contentString appendFormat:@" %@", [[codeclist objectAtIndex:i] attributeStringValueForName:@"id"] ];
    }
    [contentString appendString:@"\r\n"];
    
    // Next line is c=IN IP4 0.0.0.0, a=rtcp...
    [contentString appendString:@"c=IN IP4 0.0.0.0\r\n"];
    [contentString appendString:@"a=rtcp:1 IN IP4 0.0.0.0\r\n"];
    
    // Next line is ice pwd etc
    if (transportInfo)
    {
        NSString *ufrag = [transportInfo attributeStringValueForName:@"ufrag"];
        if (ufrag) [contentString appendFormat:@"a=ice-ufrag:%@\r\n", ufrag];
        
        NSString *pwd = [transportInfo attributeStringValueForName:@"pwd"];
        if (pwd) [contentString appendFormat:@"a=ice-pwd:%@\r\n", pwd ];
        
        NSString *options = [transportInfo attributeStringValueForName:@"options"];
        if (options) [contentString appendFormat:@"a=ice-options:%@\r\n", options];
        
        // muc changes
        NSArray *candidates = [transportInfo elementsForName:@"candidate"];
        
        if (candidates)
        {
            for (int i=0; i < [candidates count]; i++)
            {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
                
                XMPPIQ *canElement = [candidates objectAtIndex:i];
                if (canElement)
                {
                    NSMutableArray* sdp = [NSMutableArray array];
                    [sdp addObject:[canElement attributeStringValueForName:@"foundation"]];
                    [sdp addObject:[canElement attributeStringValueForName:@"component"]];
                    [sdp addObject:[[canElement attributeStringValueForName:@"protocol"] uppercaseString]];
                    [sdp addObject:[canElement attributeStringValueForName:@"priority"]];
                    [sdp addObject:[canElement attributeStringValueForName:@"ip"]];
                    [sdp addObject:[canElement attributeStringValueForName:@"port"]];
                    
                    NSString* type = [canElement attributeStringValueForName:@"type"];
                    [sdp addObject:@"typ"];
                    [sdp addObject:type];
                    if ([type isEqualToString:@"srflx"] || [type isEqualToString:@"prflx"] || [type isEqualToString:@"relay"]) {
                        if ([canElement attributeStringValueForName:@"reladdr"] && [canElement attributeStringValueForName:@"relPort"]) {
                            [sdp addObject:@"raddr"];
                            [sdp addObject:[canElement attributeStringValueForName:@"relAddr"]];
                            [sdp addObject:@"rport"];
                            [sdp addObject:[canElement attributeStringValueForName:@"relPort"]];
                        }
                    }
                    
                    [sdp addObject:@"generation"];
                    [sdp addObject:[canElement attributeStringValueForName:@"generation"] ?: @"0"];
                    
                    [dict setObject:[@"a=candidate:" stringByAppendingString:[sdp componentsJoinedByString:@" "]] forKey:@"candidate"]; ;
                    
                    [contentString appendFormat:@"%@\r\n",[dict objectForKey:@"candidate"]];
                }
            }
        }
        
        NSXMLElement * fingerprint = [transportInfo elementForName:@"fingerprint"];
        if (fingerprint)
        {
            NSString *hash = [fingerprint attributeStringValueForName:@"hash"];
            if (hash) [contentString appendFormat:@"a=fingerprint:%@ %@\r\n", hash, [fingerprint stringValue]];
            
            NSString *setup = [fingerprint attributeStringValueForName:@"setup"];
            if (setup) [contentString appendFormat:@"a=setup:%@\r\n", setup];
        }
    }
    
    // Next is a=mid line
    [contentString appendFormat:@"a=mid:%@\r\n", (NSString *)[content attributeStringValueForName:@"name"  ] ];
    
    // Next are a=extmap lines
    NSArray *extmaps = [[content elementForName:@"description"] elementsForName:@"rtp-hdrext"];
    if (extmaps)
    {
        for (int i=0; i < [extmaps count]; i++)
        {
            [contentString appendFormat:@"a=extmap:%@ %@\r\n",
             (NSString *)[[extmaps objectAtIndex:i] attributeStringValueForName:@"id" ],
             (NSString *)[[extmaps objectAtIndex:i] attributeStringValueForName:@"uri" ]];
        }
    }
    
    // Next line possibilities are "sendonly", "recvonly", "sendrecv", "inactive"
    NSString *senders = (NSString *)[content attributeStringValueForName:@"senders"];
    if (senders)
    {
        if ([senders isEqualToString:@"both"])
        {
            [contentString appendString:@"a=sendrecv\r\n"];
        }
        else if([senders isEqualToString:@"initiator"])
        {
            [contentString appendString:@"a=sendonly\r\n"];
        }
        else if([senders isEqualToString:@"responder"])
        {
            [contentString appendString:@"a=recvonly\r\n"];
        }
        else if([senders isEqualToString:@"none"])
        {
            [contentString appendString:@"a=inactive\r\n"];
        }
    }
    
    // Next line is rtcp-mux
    if ([[content elementForName:@"description"] elementForName:@"rtcp-mux"] )
    {
        [contentString appendString:@"a=rtcp-mux\r\n"];
    }
    
    //issue #7 - Enhancement
    //create an sctpmap attribute for the webrtc-datachannel protocol
    NSString *tempContentName=(NSString *)[content attributeStringValueForName:@"name"];
    if ([tempContentName caseInsensitiveCompare:@"data"]==NSOrderedSame)
    {
        [contentString appendFormat:@"a=sctpmap:%@ %@ %@\r\n",(NSString *)[sctpmapInfo attributeStringValueForName:@"number"],(NSString *)[sctpmapInfo attributeStringValueForName:@"protocol"],(NSString *)[sctpmapInfo attributeStringValueForName:@"streams"]];
    }
    
    // Next line is crypto
    NSXMLElement *encryption = [[content elementForName:@"description"] elementForName:@"encryption"];
    if (encryption)
    {
        NSXMLElement *crypto = [encryption elementForName:@"crypto"];
        
        [contentString appendFormat:@"a=crypto:%@",
         (NSString *)[crypto attributeStringValueForName:@"tag" ]];
        NSString *cryptosuite = [crypto attributeStringValueForName:@"crypto-suite" ];
        if (cryptosuite) [contentString appendFormat:@" %@", cryptosuite];
        NSString *keyparams = [crypto attributeStringValueForName:@"key-params" ];
        if (keyparams) [contentString appendFormat:@" %@", keyparams];
        NSString *sessionparams = [crypto attributeStringValueForName:@"session-params" ];
        if (sessionparams) [contentString appendFormat:@" %@", sessionparams];
        [contentString appendString:@"\r\n"];
    }
    
    // Next line is codec list
    for (int i=0; i<[codeclist count]; i++)
    {
        NSXMLElement *codec = [codeclist objectAtIndex:i];
        
        // muc changes
        /*[contentString appendFormat:@"a=rtpmap:%@ %@/%@/%@\r\n",
         [codec attributeStringValueForName:@"id"],
         [codec attributeStringValueForName:@"name"],
         [codec attributeStringValueForName:@"clockrate"],
         [codec attributeStringValueForName:@"channels"]
         ];*/
        
        NSString* name = [codec attributeStringValueForName:@"name"];
        
        if ([name isEqual:@"opus"])
        {
            [contentString appendFormat:@"a=rtpmap:%@ %@/%@/%@\r\n",
             [codec attributeStringValueForName:@"id"],
             [codec attributeStringValueForName:@"name"],
             [codec attributeStringValueForName:@"clockrate"],
             [codec attributeStringValueForName:@"channels"]
             ];
        }
        else{
            [contentString appendFormat:@"a=rtpmap:%@ %@/%@\r\n",
             [codec attributeStringValueForName:@"id"],
             [codec attributeStringValueForName:@"name"],
             [codec attributeStringValueForName:@"clockrate"]
             ];
            
        }
        
        NSArray * parameters = [codec elementsForName:@"parameter"];
        if (parameters)
        {
            if ([parameters count] > 0)
            {
                [contentString appendFormat:@"a=fmtp:%@",
                 [codec attributeStringValueForName:@"id"]
                 ];
            }
            for (int i=0; i < [parameters count]; i++)
            {
                NSString *name = [[parameters objectAtIndex:i] attributeStringValueForName:@"name"];
                NSString *value = [[parameters objectAtIndex:i] attributeStringValueForName:@"value"];
                if (name && value)
                {
                    [contentString appendFormat:@" %@=%@",
                     name,
                     value
                     ];
                }
            }
            if ([parameters count] > 0)
            {
                [contentString appendString:@"\r\n"];
            }
        }
        
        NSArray * rtcplist = [codec elementsForName:@"rtcp-fb"];
        if (rtcplist)
        {
            for (int i=0; i < [rtcplist count]; i++)
            {
                [contentString appendFormat:@"a=rtcp-fb:%@ %@",
                 [codec attributeStringValueForName:@"id"],
                 [[rtcplist objectAtIndex:i] attributeStringValueForName:@"type"]];
                NSString *subtype = [[rtcplist objectAtIndex:i] attributeStringValueForName:@"subtype"];
                if (subtype) [contentString appendFormat:@" %@", subtype];
                [contentString appendString:@"\r\n"];
            }
        }
        
    }
    
    // muc changes
    // Next line is ssrc
    /*NSXMLElement *ssrc = [[content elementForName:@"description"] elementForName:@"ssrc"];
     if (ssrc)
     {
     NSString *cname = [ssrc attributeStringValueForName:@"cname"];
     if (cname) [contentString appendFormat:@"a=ssrc:%@ cname:%@\r\n", [ssrc attributeStringValueForName:@"ssrc"], cname];
     NSString *msid = [ssrc attributeStringValueForName:@"msid"];
     if (msid) [contentString appendFormat:@"a=ssrc:%@ msid:%@\r\n", [ssrc attributeStringValueForName:@"ssrc"], msid];
     NSString *mslabel = [ssrc attributeStringValueForName:@"mslabel"];
     if (mslabel) [contentString appendFormat:@"a=ssrc:%@ mslabel:%@\r\n", [ssrc attributeStringValueForName:@"ssrc"], mslabel];
     NSString *label = [ssrc attributeStringValueForName:@"label"];
     if (label) [contentString appendFormat:@"a=ssrc:%@ label:%@\r\n", [ssrc attributeStringValueForName:@"ssrc"], label];
     }*/
    
    NSArray *sources = [[content elementForName:@"description"] elementsForName:@"source"];
    if (sources)
    {
        // TODO : count <= 1
        if ([sources count] > 1)
        {
            for (int i=0; i < [sources count]; i++)
            {
                NSXMLElement *source = [sources objectAtIndex:i];
                
                NSString *ssrc = [source attributeStringValueForName:@"ssrc"];
                
                NSArray *parameters = [source elementsForName:@"parameter"];
                
                for (int k=0; k< [parameters count]; k++)
                {
                    NSString *name = [[parameters objectAtIndex:k] attributeStringValueForName:@"name"];
                    NSString *value = [[parameters objectAtIndex:k] attributeStringValueForName:@"value"];
                    if (name && value)
                    {
                        [contentString appendFormat:@"a=ssrc:%@ %@:%@\r\n",
                         ssrc,
                         name,
                         value
                         ];
                    }
                }
            }
        }
    }
    
    
    return contentString;
}

- (NSDictionary *)XMPPToCandidate:(XMPPIQ *)iq
{
    NSXMLElement *mediaContents = [[iq elementForName:@"jingle"] elementForName:@"content"];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    
    if (mediaContents)
    {
        NSXMLElement *transportElement = [mediaContents elementForName:@"transport"];
        if (transportElement)
        {
            NSXMLElement *canElement = [transportElement elementForName:@"candidate"];
            if (canElement)
            {
                [dict setObject:[mediaContents attributeStringValueForName:@"name"] forKey:@"id"];
                [dict setObject:@"0" forKey:@"label"];
                [dict setObject:[canElement attributeStringValueForName:@"protocol"] forKey:@"protocol"];
                [dict setObject:[canElement attributeStringValueForName:@"ip"] forKey:@"ip"];
                [dict setObject:[canElement attributeStringValueForName:@"type"] forKey:@"type"];
                
                
                NSMutableArray* sdp = [NSMutableArray array];
                [sdp addObject:[canElement attributeStringValueForName:@"foundation"]];
                [sdp addObject:[canElement attributeStringValueForName:@"component"]];
                [sdp addObject:[[canElement attributeStringValueForName:@"protocol"] uppercaseString]];
                [sdp addObject:[canElement attributeStringValueForName:@"priority"]];
                [sdp addObject:[canElement attributeStringValueForName:@"ip"]];
                [sdp addObject:[canElement attributeStringValueForName:@"port"]];
                
                NSString* type = [canElement attributeStringValueForName:@"type"];
                [sdp addObject:@"typ"];
                [sdp addObject:type];
                if ([type isEqualToString:@"srflx"] || [type isEqualToString:@"prflx"] || [type isEqualToString:@"relay"]) {
                    if ([canElement attributeStringValueForName:@"reladdr"] && [canElement attributeStringValueForName:@"relPort"]) {
                        [sdp addObject:@"raddr"];
                        [sdp addObject:[canElement attributeStringValueForName:@"relAddr"]];
                        [sdp addObject:@"rport"];
                        [sdp addObject:[canElement attributeStringValueForName:@"relPort"]];
                    }
                }
                
                [sdp addObject:@"generation"];
                [sdp addObject:[canElement attributeStringValueForName:@"generation"] ?: @"0"];
                
                [dict setObject:[@"a=candidate:" stringByAppendingString:[sdp componentsJoinedByString:@" "]] forKey:@"candidate"]; ;
                
            }
            //attributeStringValueForName:@"key-params" ];
            
        }
        
    }
    
    return dict;
    
}

// Utility to parser SDP from XMPP messages
- (NSString *)XMPPToSDP:(XMPPIQ *)iq
{
    NSMutableString *SDP = [[NSMutableString alloc]init]; // TO be set once ready
    oldAVDContent=[[NSMutableDictionary alloc]init]; // initiate initially
    [oldAVDContent removeAllObjects];
    // TBD : To find a way to parse the XMPP data and convert the same to SDP
    // Parse SDP
    [SDP appendString:@"v=0\r\n"];
    [SDP appendString:@"o=- "];
    [SDP appendString:@"1923518516"];
    [SDP appendString:@" 2 IN IP4 0.0.0.0\r\n"];
    [SDP appendString:@"s=-\r\n"];
    [SDP appendString:@"t=0 0\r\n"];
    
    // Add groups if it exists
    NSString * groupStr = [self parseGroups:iq];
    if (groupStr)
    {
        [SDP appendString:groupStr];
    }
    
    // To check if a=msid-semantic line is needed
    // Add media content
    NSArray *mediaContents = [[iq elementForName:@"jingle"] elementsForName:@"content"];
    for (int i=0; i<[mediaContents count]; i++)
    {
        NSString *contentname=(NSString *)[[mediaContents objectAtIndex:i] attributeStringValueForName:@"name"];
        NSString * mediaStr = [self parseMedia:[mediaContents objectAtIndex:i]];
        NSDictionary *format=[[NSDictionary alloc]initWithObjectsAndKeys:mediaStr,@"header", nil];
        [oldAVDContent setObject:format forKey:contentname];
        if (mediaStr)
        {
            [SDP appendString:mediaStr];
        }
    }
    return SDP;
}
- (NSArray *)XMPPToMsid:(XMPPIQ *)iq
{
     NSMutableArray *msids = [[NSMutableArray alloc]init];
    
    // Add media content
    NSArray *mediaContents = [[iq elementForName:@"jingle"] elementsForName:@"content"];
    
    for (int i=0; i<[mediaContents count]; i++)
    {
        NSString *contentname=(NSString *)[[mediaContents objectAtIndex:i] attributeStringValueForName:@"name"];
        if ([contentname caseInsensitiveCompare:@"video"]==NSOrderedSame)
        {
            NSArray *sources = [[[mediaContents objectAtIndex:i] elementForName:@"description"] elementsForName:@"source"];
            if (sources.count>0)
            {
                for (int j=0; j<sources.count; j++)
                {
                    NSXMLElement *source = [sources objectAtIndex:0];
                    NSArray *parameters = [source elementsForName:@"parameter"];
                    
                    for (int k=0; k< [parameters count]; k++)
                    {
                        NSString *name = [[parameters objectAtIndex:k] attributeStringValueForName:@"name"];
                        NSString *value = [[parameters objectAtIndex:k] attributeStringValueForName:@"value"];
                        if ([name caseInsensitiveCompare:@"msid"]==NSOrderedSame)
                        {
                            NSArray *newMsids=[value componentsSeparatedByString:@" "];
                            if (newMsids.count>0)
                            {
                                [msids addObject:[newMsids objectAtIndex:0]];
                            }
                        }
                    }
                    
                }
            }

        }
    }
    
    return msids;
}
- (NSString *)XMPPToSDPNew:(XMPPIQ *)iq
{
    NSMutableString *SDP = [[NSMutableString alloc]init]; // TO be set once ready
    
    // TBD : To find a way to parse the XMPP data and convert the same to SDP
    // Parse SDP
    [SDP appendString:@"v=0\r\n"];
    [SDP appendString:@"o=- "];
    [SDP appendString:@"1923518516"];
    [SDP appendString:@" 2 IN IP4 0.0.0.0\r\n"];
    [SDP appendString:@"s=-\r\n"];
    [SDP appendString:@"t=0 0\r\n"];
    
    //issue #7 - Enhancement
    if ([oldAVDContent allKeys].count==3)
    {
        [SDP appendString:@"a=group:BUNDLE audio video data\r\n"];
    }
    else
    {
        [SDP appendString:@"a=group:BUNDLE audio video\r\n"];
    }
    
    // To check if a=msid-semantic line is needed
    // Add media content
    NSArray *mediaContents = [[iq elementForName:@"jingle"] elementsForName:@"content"];
    
    for (int i=0; i<[mediaContents count]; i++)
    {
        NSMutableString *contentString = [[NSMutableString alloc]init];
        NSString *contentname = [[mediaContents objectAtIndex:i] attributeStringValueForName:@"name"];
        NSMutableDictionary *tempObjects=[[oldAVDContent objectForKey:contentname] mutableCopy];
        [contentString appendFormat:@"%@",[tempObjects objectForKey:@"header"]];
        for(id key in tempObjects) {
            if ([key caseInsensitiveCompare:@"header"]!=NSOrderedSame)
            {
                [contentString appendFormat:@"%@",[tempObjects objectForKey:key]];
            }
        }
        NSArray *sources = [[[mediaContents objectAtIndex:i] elementForName:@"description"] elementsForName:@"source"];
        NSString *ssrcValue=@"NA";
        NSMutableString *tempContentString = [[NSMutableString alloc]init];
        if (sources.count>0)
        {
        
            for (int i=0; i < [sources count]; i++)
            {
                NSXMLElement *source = [sources objectAtIndex:i];
                ssrcValue = [source attributeStringValueForName:@"ssrc"];
                
                NSArray *parameters = [source elementsForName:@"parameter"];
                
                for (int k=0; k< [parameters count]; k++)
                {
                    NSString *name = [[parameters objectAtIndex:k] attributeStringValueForName:@"name"];
                    NSString *value = [[parameters objectAtIndex:k] attributeStringValueForName:@"value"];
                    if (name && value)
                    {
                        [contentString appendFormat:@"a=ssrc:%@ %@:%@\r\n",
                         ssrcValue,
                         name,
                         value
                         ];
                        [tempContentString appendFormat:@"a=ssrc:%@ %@:%@\r\n",
                         ssrcValue,
                         name,
                         value
                         ];
                    }
                }
                [tempObjects setObject:tempContentString forKey:ssrcValue];
            }
            [oldAVDContent setObject:tempObjects forKey:contentname];
        }

        [SDP appendString:contentString];

    }
    return SDP;
}
- (NSString *)XMPPToSDPRemove:(XMPPIQ *)iq
{
    NSMutableString *SDP = [[NSMutableString alloc]init];
    // Parse SDP
    
    [SDP appendString:@"v=0\r\n"];
    [SDP appendString:@"o=- "];
    [SDP appendString:@"1923518516"];
    [SDP appendString:@" 2 IN IP4 0.0.0.0\r\n"];
    [SDP appendString:@"s=-\r\n"];
    [SDP appendString:@"t=0 0\r\n"];
    
    //issue #7 - Enhancement
    if ([oldAVDContent allKeys].count==3)
    {
        [SDP appendString:@"a=group:BUNDLE audio video data\r\n"];
    }
    else
    {
        [SDP appendString:@"a=group:BUNDLE audio video\r\n"];
    }
    
    // Remove media content
    NSArray *mediaContents = [[iq elementForName:@"jingle"] elementsForName:@"content"];
    NSMutableString *contentString = [[NSMutableString alloc]init];
    for (int i=0; i<[mediaContents count]; i++)
    {
        NSArray *sources = [[[mediaContents objectAtIndex:i] elementForName:@"description"] elementsForName:@"source"];
        NSString *ssrcValue=@"NA";
        NSString *contentname = [[mediaContents objectAtIndex:i] attributeStringValueForName:@"name"];
        NSMutableDictionary *tempObjects=[[oldAVDContent objectForKey:contentname] mutableCopy];
        if (sources.count>0)
        {
        for (int i=0; i < [sources count]; i++)
        {
            NSXMLElement *source = [sources objectAtIndex:i];
            ssrcValue = [source attributeStringValueForName:@"ssrc"];
            if ([tempObjects objectForKey:ssrcValue])
            {
                [tempObjects removeObjectForKey:ssrcValue];
                break;
            }
  
        }
        }
        [contentString appendFormat:@"%@",[tempObjects objectForKey:@"header"]];
        for(id key in tempObjects) {
            if ([key caseInsensitiveCompare:@"header"]!=NSOrderedSame)
            {
                [contentString appendFormat:@"%@",[tempObjects objectForKey:key]];
            }
        }
        [oldAVDContent setObject:tempObjects forKey:contentname];
    
    }
    [SDP appendString:contentString];
    return SDP;

}
// Utility to parser XMPP from SDP messages
- (XMPPIQ *)SDPToXMPP:(NSString *)sdp action:(NSString *)action initiator:(XMPPJID *)initiator target:(XMPPJID *)target UID:(NSString *)UID SID:(NSString *)SID
{
    XMPPIQ *xmpp;
    
    // TBD : To find a way to parse the SDP data and convert the same to XMPP
    // Parse xmpp
    
    NSDictionary* dict = [JAHConvertSDP dictionaryForSDP:sdp withCreatorRole:@"initiator"]; // or @"responder"
    NSXMLElement *jingleElement = [NSXMLElement elementWithName:@"jingle"];
    [jingleElement addAttributeWithName:@"xmlns" stringValue:@"urn:xmpp:jingle:1"];
    [jingleElement addAttributeWithName:@"sid" stringValue:SID];
    [jingleElement addAttributeWithName:@"action" stringValue:action];
    //fix for Issue #2 - teamxrtc
    [jingleElement addAttributeWithName:@"initiator" stringValue:[target full]];
    [jingleElement addAttributeWithName:@"responder" stringValue:[initiator full]];
    
    // Add group
    NSArray *groups = [dict objectForKey:@"groups"];
    
    for (int i=0; i < [groups count]; i++)
    {
        NSDictionary *group = [groups objectAtIndex:i];
        NSString* semantics = [group objectForKey:@"semantics"];
        NSArray *contents = [group objectForKey:@"contents"];
        
        NSXMLElement *groupElement = [NSXMLElement elementWithName:@"group"];
        [groupElement addAttributeWithName:@"xmlns" stringValue:@"urn:xmpp:jingle:apps:grouping:0"];
        [groupElement addAttributeWithName:@"semantics" stringValue:semantics];
        
        for (int j=0; j<[contents count]; j++)
        {
            NSXMLElement *groupContent = [NSXMLElement elementWithName:@"content"];
            [groupContent addAttributeWithName:@"name" stringValue:[contents objectAtIndex:j]];
            [groupElement addChild:groupContent];
        }
        
        [jingleElement addChild:groupElement];
    }
    
    // Add content
    
    NSArray *contents = [dict objectForKey:@"contents"];
    
    for (int i=0; i < [contents count]; i++)
    {
        NSDictionary *content = [contents objectAtIndex:i];
        
        //fix for Issue #2 - teamxrtc
        NSString *creator=[content objectForKey:@"creator"];
        NSString *sender=[content objectForKey:@"senders"];
        
        if ([[content objectForKey:@"creator"] isEqualToString:@"initiator"])
        {
            creator = @"responder";
        }
        
        NSString* media_name = [content objectForKey:@"name"];
        
        NSDictionary* description = [content objectForKey:@"description"];
        NSString *ssrc = [description objectForKey:@"ssrc"];
        
        //Content
        NSXMLElement *contentElement = [NSXMLElement elementWithName:@"content"];
        [contentElement addAttributeWithName:@"creator" stringValue:creator];
         //fix for Issue #2 - teamxrtc
        [contentElement addAttributeWithName:@"senders" stringValue:sender];
        [contentElement addAttributeWithName:@"name" stringValue:media_name];
        
        //Bundle
        NSXMLElement *bundleElement = [NSXMLElement elementWithName:@"bundle"];
        [bundleElement addAttributeWithName:@"xmlns" stringValue:@"http://estos.de/ns/bundle"];
        [contentElement addChild:bundleElement];
        
        //Description
        NSXMLElement *descElement = [NSXMLElement elementWithName:@"description"];
        [descElement addAttributeWithName:@"xmlns" stringValue:@"urn:xmpp:jingle:apps:rtp:1"];
        [descElement addAttributeWithName:@"media" stringValue:media_name];
        if(ssrc)
            [descElement addAttributeWithName:@"ssrc" stringValue:ssrc];
        
        //Payloads
        NSArray* payloads = [description objectForKey:@"payloads"];
        
        for (int j=0; j < [payloads count]; j++)
        {
            NSDictionary *payload = [payloads objectAtIndex:j];
            NSString *name = [payload objectForKey:@"name"];
            NSString *clockrate = [payload objectForKey:@"clockrate"];
            NSString *strID = [payload objectForKey:@"id"];
            NSString *channels = [payload objectForKey:@"channels"];
            
            NSXMLElement *payloadTypeElement = [NSXMLElement elementWithName:@"payload-type"];
            [payloadTypeElement addAttributeWithName:@"name" stringValue:name];
            [payloadTypeElement addAttributeWithName:@"clockrate" stringValue:clockrate];
            [payloadTypeElement addAttributeWithName:@"id" stringValue:strID];
            [payloadTypeElement addAttributeWithName:@"channels" stringValue:channels];
            
            // Add rtcp-fb if it exists
            NSArray *rtcpfblist = [payload objectForKey:@"feedback"];
            if ((rtcpfblist != nil) && ([rtcpfblist count] > 1))
            {
                for (int k=0; k< [rtcpfblist count]; k++)
                {
                    NSDictionary *parameter = [rtcpfblist objectAtIndex:k];
                    NSString *type = [parameter objectForKey:@"type"];
                    NSString *subtype = [parameter objectForKey:@"subtype"];
                    
                    NSXMLElement *parameterElement = [NSXMLElement elementWithName:@"rtcp-fb"];
                    [parameterElement addAttributeWithName:@"xmlns" stringValue:@"urn:xmpp:jingle:apps:rtp:rtcp-fb:0"];
                    [parameterElement addAttributeWithName:@"type" stringValue:type];
                    if ((subtype) && ([subtype length] > 0))
                        [parameterElement addAttributeWithName:@"subtype" stringValue:subtype];
                    [payloadTypeElement addChild:parameterElement];
                    
                }
            }
            
            NSArray *parameters = [payload  objectForKey:@"parameters"];
            for (int k=0; k< [parameters count]; k++)
            {
                NSDictionary *parameter = [parameters objectAtIndex:k];
                NSString *key = [parameter objectForKey:@"key"];
                NSString *value = [parameter objectForKey:@"value"];
                
                NSXMLElement *parameterElement = [NSXMLElement elementWithName:@"parameters"];
                [parameterElement addAttributeWithName:@"value" stringValue:value];
                [parameterElement addAttributeWithName:@"name" stringValue:key];
                
                [payloadTypeElement addChild:parameterElement];
                
            }
            
            [descElement addChild:payloadTypeElement];
        }
        
        //Encryption
        
        NSArray* encryptions = [description objectForKey:@"encryption"];
        
        for(int l=0; l< [encryptions count]; l++)
        {
            NSDictionary *encryption = [encryptions objectAtIndex:l];
            
            NSXMLElement *encryptElement = [NSXMLElement elementWithName:@"encryption"];
            [encryptElement addAttributeWithName:@"required" stringValue:@"1"];
            
            NSString *cipherSuite = [encryption objectForKey:@"cipherSuite"];
            NSString *keyParams = [encryption objectForKey:@"keyParams"];
            NSString *sessionParams = [encryption objectForKey:@"sessionParams"];
            NSString *tag = [encryption objectForKey:@"tag"];
            
            NSXMLElement *cryptoElement = [NSXMLElement elementWithName:@"crypto"];
            [cryptoElement addAttributeWithName:@"cipherSuite" stringValue:cipherSuite];
            [cryptoElement addAttributeWithName:@"keyParams" stringValue:keyParams];
            [cryptoElement addAttributeWithName:@"sessionParams" stringValue:sessionParams];
            [cryptoElement addAttributeWithName:@"tag" stringValue:tag];
            
            [encryptElement addChild:cryptoElement];
            
            [descElement addChild:encryptElement];
        }
        
        
        //Source
        
        if (ssrc)
        {
            NSArray* sources = [description objectForKey:@"sources"];
            
            NSMutableDictionary *sourceData = [[NSMutableDictionary alloc]init];
            
            for (int s=0; s< [sources count]; s++)
            {
                NSDictionary *source = [sources objectAtIndex:s];
                NSString *ssrc = [source objectForKey:@"ssrc"];
                
                NSXMLElement *sourceElement = [NSXMLElement elementWithName:@"source"];
                [sourceElement addAttributeWithName:@"ssrc" stringValue:ssrc];
                [sourceElement addAttributeWithName:@"xmlns" stringValue:@"urn:xmpp:jingle:apps:rtp:ssma:0"];
                
                NSArray *parameters = [source objectForKey:@"parameters"];
                
                for (int p=0; p< [parameters count]; p++)
                {
                    NSDictionary *parameter = [parameters objectAtIndex:p];
                    
                    NSString *key = [parameter objectForKey:@"key"];
                    NSString *value = [parameter objectForKey:@"value"];
                    
                    [sourceData setObject:value forKey:key];
                    
                    NSXMLElement *paraElement = [NSXMLElement elementWithName:@"parameter"];
                    [paraElement addAttributeWithName:@"value" stringValue:value];
                    [paraElement addAttributeWithName:@"name" stringValue:key];
                    
                    [sourceElement addChild:paraElement];
                    
                }
                
                [descElement addChild:sourceElement];
            }
            
            NSXMLElement *ssrcElement = [NSXMLElement elementWithName:@"ssrc"];
            [ssrcElement addAttributeWithName:@"xmlns" stringValue:@"http://estos.de/ns/ssrc"];
            
            NSArray *keys = [sourceData allKeys];
            for (int a=0; a< [keys count]; a++)
            {
                NSString *key = [keys objectAtIndex: a];
                NSString *value = [sourceData objectForKey: key];
                
                [ssrcElement addAttributeWithName:key stringValue:value];
            }
            [descElement addChild:ssrcElement];
            
        }
        
        //Mux
        if ([description objectForKey:@"mux"] != nil)
        {
            [descElement addChild:[NSXMLElement elementWithName:@"rtcp-mux"]];
        }
        
        
        // XEP-0294  Header Extensions
        NSArray* hdrexts = [description objectForKey:@"headerExtensions"];
        for (int z=0; z<[hdrexts count]; z++)
        {
            NSDictionary *hdrext = [hdrexts objectAtIndex:z];
            NSString *uri = [hdrext objectForKey:@"uri"];
            NSString *strId = [hdrext objectForKey:@"id"];
            NSString *senders = [hdrext objectForKey:@"senders"];
            
            NSXMLElement *hdrextElement = [NSXMLElement elementWithName:@"rtp-hdrext"];
            [hdrextElement addAttributeWithName:@"xmlns" stringValue:@"urn:xmpp:jingle:apps:rtp:rtp-hdrext:0"];
            [hdrextElement addAttributeWithName:@"uri" stringValue:uri];
            [hdrextElement addAttributeWithName:@"id" stringValue:strId];
            [hdrextElement addAttributeWithName:@"senders" stringValue:senders];
            
            [descElement addChild:hdrextElement];
        }
        
        // Add description to content
        [contentElement addChild:descElement];
        
        //Transport
        NSDictionary* transport = [content objectForKey:@"transport"];
        NSXMLElement *transElement = [NSXMLElement elementWithName:@"transport"];
        
        if ([transport objectForKey:@"fingerprints"] != nil)
        {
            NSArray* fingerPrint = [transport objectForKey:@"fingerprints"];
            
            for (int i=0; i <[fingerPrint count]; i++)
            {
                if ([fingerPrint[i] objectForKey:@"setup"] != nil)
                {
                    NSXMLElement *fprElement = [NSXMLElement elementWithName:@"fingerprint"];
                    [fprElement addAttributeWithName:@"xmlns" stringValue:@"urn:xmpp:tmp:jingle:apps:dtls:0"];
                    [fprElement addAttributeWithName:@"hash" stringValue:[fingerPrint[i] objectForKey:@"hash"]];
                    
                    NSString *setup = [fingerPrint[i] objectForKey:@"setup"];
                    [fprElement setStringValue:[fingerPrint[i] objectForKey:@"value"]];
                    [fprElement addAttributeWithName:@"setup" stringValue:setup];
                    
                    [transElement addChild:fprElement];
                    
                    // muc changes
                    sdpFprElement = fprElement;
                }
            }
        }
        
        if (([transport objectForKey:@"ufrag"] != nil) &&
            ([transport objectForKey:@"pwd"] != nil))
        {
            NSString *ufrag = [transport objectForKey:@"ufrag"];
            NSString *pwd = [transport objectForKey:@"pwd"];
            
            [transElement addAttributeWithName:@"xmlns" stringValue:@"urn:xmpp:jingle:transports:ice-udp:1"];
            [transElement addAttributeWithName:@"ufrag" stringValue:ufrag];
            [transElement addAttributeWithName:@"pwd" stringValue:pwd];
            
            // muc changes
            gUfrag = ufrag;
            gPwd = pwd;
        }
        
        // muc changes
        NSArray *candidates = [transport objectForKey:@"candidate"];
        
        if([candidates count] == 0)
            candidates = [transport objectForKey:@"candidates"];
        
        for (int y=0; y< [candidates count]; y++)
        {
            NSDictionary *candidate = [candidates objectAtIndex:y];
            
            NSString *foundation = [candidate objectForKey:@"foundation"];
            NSString *component = [candidate objectForKey:@"component"];
            NSString *protocol = [candidate objectForKey:@"protocol"];
            NSString *priority = [candidate objectForKey:@"priority"];
            NSString *ip = [candidate objectForKey:@"ip"];
            NSString *port = [candidate objectForKey:@"port"];
            NSString *type = [candidate objectForKey:@"type"];
            NSString *generation = [candidate objectForKey:@"generation"];
            NSString *network = [candidate objectForKey:@"network"];
            NSString *did = [candidate objectForKey:@"id"];
            
            
            
            NSXMLElement *canElement = [NSXMLElement elementWithName:@"candidate"];
            [canElement addAttributeWithName:@"foundation" stringValue:foundation];
            [canElement addAttributeWithName:@"component" stringValue:component];
            [canElement addAttributeWithName:@"protocol" stringValue:protocol];
            [canElement addAttributeWithName:@"priority" stringValue:priority];
            [canElement addAttributeWithName:@"ip" stringValue:ip];
            [canElement addAttributeWithName:@"port" stringValue:port];
            [canElement addAttributeWithName:@"type" stringValue:type];
            [canElement addAttributeWithName:@"generation" stringValue:generation];
            [canElement addAttributeWithName:@"network" stringValue:network];
            [canElement addAttributeWithName:@"id" stringValue:did];
            
            [transElement addChild:canElement];
        }
        
        
        // Add transport to content
        [contentElement addChild:transElement];
        
        [jingleElement addChild:contentElement];
        
        // xmpp = jingleElement;
        
        xmpp  = [[XMPPIQ alloc]initWithType:@"set" to:target elementID:UID child:[jingleElement copy]];
        
    }
    
    return xmpp;
}

- (XMPPIQ *)CandidateToXMPP:(NSDictionary *)dict action:(NSString *)action initiator:(XMPPJID *)initiator target:(XMPPJID *)target UID:(NSString *)UID SID:(NSString *)SID
{
    
    XMPPIQ *xmpp=nil;
    
    // TBD : To find a way to parse the SDP data and convert the same to XMPP
    // Parse xmpp
    
    NSDictionary* candidate = [JAHConvertSDP candidateForLine:[dict objectForKey:@"candidate"]]; // or @"responder"
    NSXMLElement *jingleElement = [NSXMLElement elementWithName:@"jingle"];
    [jingleElement addAttributeWithName:@"xmlns" stringValue:@"urn:xmpp:jingle:1"];
    [jingleElement addAttributeWithName:@"sid" stringValue:SID];
    [jingleElement addAttributeWithName:@"action" stringValue:action];
    
    //fix for Issue #2 - teamxrtc
    [jingleElement addAttributeWithName:@"initiator" stringValue:[target full]];
    
    // id
    NSString *id = [dict objectForKey:@"id"];
    if ( (id != nil) && ([id length] > 0))
    {
        NSXMLElement *contentElement = [NSXMLElement elementWithName:@"content"];
        [contentElement addAttributeWithName:@"creator" stringValue:@"responder"];
        [contentElement addAttributeWithName:@"name" stringValue:id];
        
        NSXMLElement *transElement = [NSXMLElement elementWithName:@"transport"];
        
        // muc changes
        [transElement addAttributeWithName:@"xmlns" stringValue:@"urn:xmpp:jingle:transports:ice-udp:1"];
        [transElement addAttributeWithName:@"ufrag" stringValue:gUfrag];
        [transElement addAttributeWithName:@"pwd" stringValue:gPwd];
        
        
        NSXMLElement *canElement = [NSXMLElement elementWithName:@"candidate"];
        
        
        NSString *foundation = [candidate objectForKey:@"foundation"];
        NSString *component = [candidate objectForKey:@"component"];
        NSString *protocol = [candidate objectForKey:@"protocol"];
        NSString *priority = [candidate objectForKey:@"priority"];
        NSString *ip = [candidate objectForKey:@"ip"];
        NSString *port = [candidate objectForKey:@"port"];
        NSString *type = [candidate objectForKey:@"type"];
        NSString *generation = [candidate objectForKey:@"generation"];
        NSString *network = [candidate objectForKey:@"network"];
        NSString *did = [candidate objectForKey:@"id"];
        
        [canElement addAttributeWithName:@"foundation" stringValue:foundation];
        [canElement addAttributeWithName:@"component" stringValue:component];
        [canElement addAttributeWithName:@"protocol" stringValue:protocol];
        [canElement addAttributeWithName:@"priority" stringValue:priority];
        [canElement addAttributeWithName:@"ip" stringValue:ip];
        [canElement addAttributeWithName:@"port" stringValue:port];
        [canElement addAttributeWithName:@"type" stringValue:type];
        [canElement addAttributeWithName:@"generation" stringValue:generation];
        [canElement addAttributeWithName:@"network" stringValue:network];
        [canElement addAttributeWithName:@"id" stringValue:did];
        
        [transElement addChild:canElement];
        
        // muc changes
        if(sdpFprElement)
            [transElement addChild:[sdpFprElement copy]];
        
        [contentElement addChild:transElement];
        [jingleElement addChild:contentElement];
        
    }
    xmpp  = [[XMPPIQ alloc]initWithType:@"set" to:target elementID:UID child:[jingleElement copy]];
    
    return xmpp;
    
}
- (NSString*)find_line:(NSString*)haystack  needle:(NSString*)needle
{
    NSArray* lines = [haystack componentsSeparatedByString: @"\r\n"];
    
    for (int i=0; i < [lines count]; i++)
    {
        NSString *tmpString = [lines objectAtIndex:i];
        NSString *subStr = nil;
        
        if (tmpString.length >= needle.length)
        {
            subStr = [tmpString substringToIndex:needle.length];
            
            if([subStr isEqual:needle])
            {
                return [lines objectAtIndex:i];
            }
        }
        
    }
    
    return false;
}

- (NSArray*)find_lines:(NSString*)haystack  needle:(NSString*)needle
{
    NSArray* lines = [haystack componentsSeparatedByString: @"\r\n"];
    NSMutableArray* needles = [[NSMutableArray alloc] init];
    
    for (int i=0; i < [lines count]; i++)
    {
        NSString *tmpString = [lines objectAtIndex:i];
        NSString *subStr = nil;
        
        if (tmpString.length >= needle.length)
        {
            subStr = [tmpString substringToIndex:needle.length];
            
            if([subStr isEqual:needle])
            {
                [needles addObject:[lines objectAtIndex:i]];
            }
        }
        
    }
    
    return needles;
}

- (void) splitSDP:(NSString*)sdp
{
    NSMutableString *mediaStr = [[NSMutableString alloc] init];
    NSMutableString *mediaTmp = [[NSMutableString alloc] init];
    
    media = [[NSMutableArray alloc] init];
    session = [[NSMutableArray alloc] init];
    
    media = [sdp componentsSeparatedByString: @"\r\nm="].mutableCopy;
    
    for (int i = 1; i < [media count]; i++) {
        
        mediaTmp = [media objectAtIndex:i];
        [mediaStr setString:@"m="];
        [mediaStr appendString:mediaTmp];
        
        [media replaceObjectAtIndex:i withObject:mediaStr];
        
        if (i != [media count] - 1) {
            [[media objectAtIndex:i] appendString:@"\r\n"];
        }
    }
    
    session = [media objectAtIndex:0];
    
    [media removeObject:[media objectAtIndex:0]];
    
}

- (NSArray*) parse_mline:(NSString*)line
{
    NSArray *parts;
    
    parts = [[line substringFromIndex:2]componentsSeparatedByString:@" "];
    
    return parts;
}

- (NSXMLElement *)MediaToXMPP:(NSString *)type  data:(NSDictionary *)data target:(XMPPJID *)target UID:(NSString *)UID SID:(NSString *)SID
{
    NSXMLElement *mediaElement = [NSXMLElement elementWithName:@"media" xmlns:@"http://estos.de/ns/mjs"];
    
    XMPPIQ *sdp = [self SDPToXMPP:[data objectForKey:@"sdp"] action:type initiator:nil target:target UID:UID SID:SID];
    
    if (sdp != nil)
    {
        
        NSArray *mediaContents = [[sdp elementForName:@"jingle"] elementsForName:@"content"];
        for (int i=0; i<[mediaContents count]; i++)
        {
            NSXMLElement * mediaStr = [mediaContents objectAtIndex:i];
            if (mediaStr)
            {
                
                NSString *senders = (NSString *)[mediaStr attributeStringValueForName:@"senders"];
                if (senders)
                {
                    if ([senders isEqualToString:@"both"])
                    {
                        senders = @"a=sendrecv\r\n";
                    }
                    else if([senders isEqualToString:@"initiator"])
                    {
                        senders = @"a=sendonly\r\n";
                    }
                    else if([senders isEqualToString:@"responder"])
                    {
                        senders = @"a=recvonly\r\n";
                    }
                    else if([senders isEqualToString:@"none"])
                    {
                        senders = @"a=inactive\r\n";
                    }
                }
                
                NSString *type = (NSString *)[[mediaStr elementForName:@"description"] attributeStringValueForName:@"media"];
                
                
                NSString *ssrc = (NSString *)[[mediaStr elementForName:@"description"] attributeStringValueForName:@"ssrc"];
                
                
                NSXMLElement *elem = [NSXMLElement elementWithName:@"source"];
                [elem addAttributeWithName:@"type" stringValue:type];
                [elem addAttributeWithName:@"ssrc" stringValue:ssrc];
                [elem addAttributeWithName:@"direction" stringValue:@"sendrecv"];
                [mediaElement addChild:elem];
            }
        }
    }
    return mediaElement;
    
}

@end
