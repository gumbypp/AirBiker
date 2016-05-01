//
//  common.h
//  Biker
//
//  Created by Dale Low on 10/31/14.
//  Copyright (c) 2014 gumbypp consulting. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <UIAlertView+Blocks.h>

#define kSecondsPerMinute                   60
#define kSecondsPerHour                     (60 * kSecondsPerMinute)
#define kSecondsPerDay                      (24 * kSecondsPerHour)

#define kWorkoutFileExtension               @"biker"
#define kWorkoutFileKeyName                 @"name"
#define kWorkoutFileKeyDate                 @"date"
#define kWorkoutFileKeyDuration             @"duration"
#define kWorkoutFileKeyDistance             @"distance"
#define kWorkoutFileKeyPoints               @"points"

union long_hex {
    uint32_t lunsign;
    struct {
        uint8_t b0;
        uint8_t b1;
        uint8_t b2;
        uint8_t b3;
    } lbytes;
};

// logger
typedef NS_ENUM(NSInteger, LogLevel)
{
    kLogLevelDebug = (1 << 0),
    kLogLevelInfo  = (1 << 1),
    kLogLevelWarn  = (1 << 2),
    kLogLevelError = (1 << 3),
    kLogLevelAll   = kLogLevelDebug | kLogLevelInfo | kLogLevelWarn | kLogLevelError,
};

#define NSLogDebug(...)     [Logger logLevel:kLogLevelDebug loc:__PRETTY_FUNCTION__ msg:__VA_ARGS__]
#define NSLogInfo(...)      [Logger logLevel:kLogLevelInfo loc:__PRETTY_FUNCTION__ msg:__VA_ARGS__]
#define NSLogWarn(...)      [Logger logLevel:kLogLevelWarn loc:__PRETTY_FUNCTION__ msg:__VA_ARGS__]
#define NSLogError(...)     [Logger logLevel:kLogLevelError loc:__PRETTY_FUNCTION__ msg:__VA_ARGS__]

@interface Logger : NSObject

@property (nonatomic, assign) LogLevel loggingLevel;

+ (Logger *)sharedLogger;
+ (void)logLevel:(NSInteger)level loc:(const char *)loc msg:(NSString *)format, ...;

@end

@interface Common : NSObject

+ (uint32_t)dwordForLittleEndianData:(NSData *)value;
+ (NSString *)formatTimeDuration:(NSTimeInterval)duration;
+ (void)showSimpleInfoAlertWithOk:(NSString *)message;

@end