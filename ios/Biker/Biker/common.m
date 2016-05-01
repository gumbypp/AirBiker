//
//  common.m
//  Biker
//
//  Created by Dale Low on 10/31/14.
//  Copyright (c) 2014 gumbypp consulting. All rights reserved.
//

#import "common.h"

@implementation Logger

+ (Logger *)sharedLogger
{
    static dispatch_once_t pred;
    static Logger *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[self alloc] init];
    });
    
    return shared;
}

+ (void)logLevel:(NSInteger)level loc:(const char *)loc msg:(NSString *)format, ...
{
    if (!(level & [Logger sharedLogger].loggingLevel)) {
        return;
    }
    
    va_list arguments;
	
	va_start(arguments, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
	va_end(arguments);
    
    switch (level)
    {
        case kLogLevelDebug:
            NSLog(@"%s > %@", loc, message);
            break;
            
        case kLogLevelInfo:
            NSLog(@"%s %@", loc, message);
            break;
            
        case kLogLevelWarn:
            NSLog(@"%s [Warning] %@", loc, message);
            break;
            
        case kLogLevelError:
            NSLog(@"%s [Error] %@", loc, message);
            break;
    }
}

@end

@implementation Common

+ (uint32_t)dwordForLittleEndianData:(NSData *)value
{
    union long_hex lu;
    uint8_t *bytes = (uint8_t *)[value bytes];
    
    lu.lbytes.b0 = *bytes++;
    lu.lbytes.b1 = *bytes++;
    lu.lbytes.b2 = *bytes++;
    lu.lbytes.b3 = *bytes++;
    
    return lu.lunsign;
}

+ (NSString *)formatTimeDuration:(NSTimeInterval)duration
{
    return [NSString stringWithFormat:@"%ld:%02ld", (long)duration / kSecondsPerMinute, (long)duration % kSecondsPerMinute];
}

+ (void)showSimpleInfoAlertWithOk:(NSString *)message
{
    [UIAlertView showWithTitle:@"Info" message:message cancelButtonTitle:@"OK" otherButtonTitles:nil tapBlock:nil];
}

@end
