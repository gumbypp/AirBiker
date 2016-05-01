//
//  MainViewController.m
//  Biker
//
//  Created by Dale Low on 10/31/14.
//  Copyright (c) 2014 gumbypp consulting. All rights reserved.
//

#import "MainViewController.h"

#import "BLE.h"

@import CoreLocation;

#define kAirspeedPollInterval       1.0
#define kUpdateStatsInterval        1.0
#define kMinLocationDistance        5.0     // meters
#define kMinLocationSpeedDelta      (1.0/kConvertMeterPerSecToKMH)
#define kCmdGetAirspeed             0x01
#define kConvertMeterPerSecToKMH    3.6

typedef enum
{
    kBLEStateIdle,
    kBLEStateScanning,
    kBLEStateConnecting,
    kBLEStateConnected,
    kBLEStateDisconnecting
} BLEState;

typedef enum
{
    kRequestStateIdle,
    kRequestStateSending
} RequestState;

typedef enum
{
    kAppStateIdle,
    kAppStateRunning
} AppState;

@interface MainViewController () <BLEDelegate, CLLocationManagerDelegate>

@property (nonatomic, weak) IBOutlet UIButton *connectButton;
@property (nonatomic, weak) IBOutlet UIButton *startButton;
@property (nonatomic, weak) IBOutlet UIButton *resetButton;

@property (nonatomic, weak) IBOutlet UILabel *timeLabel;
@property (nonatomic, weak) IBOutlet UILabel *gpsPointsLabel;
@property (nonatomic, weak) IBOutlet UILabel *gpsPingLabel;
@property (nonatomic, weak) IBOutlet UILabel *gpsLocationLabel;
@property (nonatomic, weak) IBOutlet UILabel *gpsSpeedLabel;
@property (nonatomic, weak) IBOutlet UILabel *airspeedPointsLabel;
@property (nonatomic, weak) IBOutlet UILabel *airspeedPingLabel;
@property (nonatomic, weak) IBOutlet UILabel *airspeedLabel;
@property (nonatomic, weak) IBOutlet UILabel *effortSpeedLabel;
@property (nonatomic, weak) IBOutlet UILabel *gpsDistanceLabel;
@property (nonatomic, weak) IBOutlet UILabel *effortDistanceLabel;
@property (nonatomic, weak) IBOutlet UILabel *altitudeLabel;
@property (nonatomic, weak) IBOutlet UILabel *altitudeTotalLabel;

@property (nonatomic, assign) AppState appState;
@property (nonatomic, strong) NSTimer *updateBasicStatsTimer;
@property (nonatomic, strong) NSMutableArray *runDataPoints;

@property (nonatomic, assign) BLEState bleState;
@property (nonatomic, strong) BLE *ble;
@property (nonatomic, strong) CBPeripheral *discoveredPeripheral;
@property (nonatomic, assign) RequestState requestState;
@property (nonatomic, strong) NSTimer *airspeedPollTimer;
@property (nonatomic, assign) float lastAirspeed;
@property (nonatomic, assign) unsigned long airspeedCount;
@property (nonatomic, assign) int airspeedPingCount;

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *lastLocation;
@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, assign) unsigned long gpsCount;
@property (nonatomic, assign) int gpsPingCount;
@property (nonatomic, assign) CLLocationDistance gpsDistance;

@end

@implementation MainViewController

- (id)init
{
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    self.title = @"Biker";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [_connectButton setTitle:@"Starting" forState:UIControlStateNormal];
    _connectButton.enabled = NO;
    
    [_startButton setTitle:@"Start" forState:UIControlStateNormal];
    _startButton.enabled = NO;

    [_resetButton setTitle:@"Reset" forState:UIControlStateNormal];
    _resetButton.enabled = NO;
    
    self.ble = [[BLE alloc] init];
    [_ble controlSetup];
    _ble.delegate = self;
    
    _gpsSpeedLabel.text = @"N/A";
    _gpsPingLabel.text = @"←";
    _airspeedLabel.text = @"N/A";
    _airspeedPingLabel.text = @"←";
    
    _lastAirspeed = -1;
    self.lastLocation = nil;
    
    self.locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    
    [_locationManager requestAlwaysAuthorization];
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways) {
        [Common showSimpleInfoAlertWithOk:@"Location services are not enabled. This app will not work without them."];
    } else {
        [_locationManager startUpdatingLocation];
    }
}

#pragma mark - internal methods

- (void)enableStartButtonIfNecessary
{
    if (kAppStateIdle == _appState) {
        _startButton.enabled = (_lastAirspeed >= 0) && _lastLocation;
    } else {
        NSAssert(kAppStateRunning == _appState, @"assert: unexpected app state (%d)", _appState);
        // app is tracking a workout so stop is always enabled
    }
}

- (void)addDataPointWithLocation:(CLLocation *)location distanceMoved:(CLLocationDistance)distanceMoved airspeed:(float)airspeed
{
    [_runDataPoints addObject:[NSString stringWithFormat:@"%.2f,%.5f,%.5f,%.1f,%.1f,%.1f,%.2f,%.2f,%.1f",
                               [location.timestamp timeIntervalSinceDate:_startDate],
                               location.coordinate.latitude,
                               location.coordinate.longitude,
                               location.horizontalAccuracy,
                               location.altitude,
                               location.verticalAccuracy,
                               location.speed * kConvertMeterPerSecToKMH,
                               airspeed,
                               distanceMoved]];
}

- (int)updatePingIndicatorForLabel:(UILabel *)pingLabel count:(int)count
{
    if (++count >= 4) {
        count = 0;
    }
    
    switch (count) {
        case 0: pingLabel.text = @"←"; break;
        case 1: pingLabel.text = @"↑"; break;
        case 2: pingLabel.text = @"→"; break;
        case 3: pingLabel.text = @"↓"; break;
    }
    
    return count;
}

#pragma mark - event handlers

- (void)updateBasicStatsTimeout:(NSTimer *)t
{
    if (t != _updateBasicStatsTimer) {
        return;
    }
    
    _timeLabel.text = [Common formatTimeDuration:[[NSDate date] timeIntervalSinceDate:_startDate]];
    _gpsPointsLabel.text = [@(_gpsCount) stringValue];
    _gpsDistanceLabel.text = [NSString stringWithFormat:@"%.2f km", _gpsDistance/1000];
    _airspeedPointsLabel.text = [@(_airspeedCount) stringValue];
}

- (void)airspeedPollTimeout:(NSTimer *)t
{
    if (t != _airspeedPollTimer) {
        return;
    }
    
    uint8_t cmd = kCmdGetAirspeed;
    NSData *data = [NSData dataWithBytes:&cmd length:1];
    if (![_ble write:data]) {
        // TODO
    } else {
        _requestState = kRequestStateSending;
    }
}

- (IBAction)connectPressed:(id)sender
{
    switch (_bleState) {
        case kBLEStateScanning:
            [_connectButton setTitle:@"Connecting" forState:UIControlStateNormal];
            _connectButton.enabled = NO;

            [_ble connectPeripheral:_discoveredPeripheral];
            _bleState = kBLEStateConnecting;
            break;

        case kBLEStateConnected:
            [_connectButton setTitle:@"Disconnecting" forState:UIControlStateNormal];
            _connectButton.enabled = NO;

            [_ble disconnectActivePeripheral];
            _bleState = kBLEStateDisconnecting;
            break;

        default:
            NSAssert(NO, @"assert: connectPressed invalid state (%d)", _bleState);
            break;
    }
}

- (IBAction)startPressed:(id)sender
{
    if (kAppStateIdle == _appState) {
        [_startButton setTitle:@"Stop" forState:UIControlStateNormal];
        self.startDate = [NSDate date];
        self.runDataPoints = [NSMutableArray arrayWithCapacity:500];
        
        // legend
        [_runDataPoints addObject:@"time,lat,long,hacc(m),alt(m),vacc(m),speed(km/h),airspeed(km/h),distance(m)"];

        // first point
        [self addDataPointWithLocation:_lastLocation distanceMoved:0 airspeed:0];
        
        _gpsCount = 1;      // start with _lastLocation
        _gpsDistance = 0;
        _airspeedCount = 0; // wait for next reading
        [self updateBasicStatsTimeout:_updateBasicStatsTimer];
        self.updateBasicStatsTimer = [NSTimer scheduledTimerWithTimeInterval:kUpdateStatsInterval
                                                                 target:self selector:@selector(updateBasicStatsTimeout:)
                                                               userInfo:nil repeats:YES];
        
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        _appState = kAppStateRunning;
    } else {
        NSAssert(kAppStateRunning == _appState, @"assert: unexpected app state (%d)", _appState);

        [_updateBasicStatsTimer invalidate];
        self.updateBasicStatsTimer = nil;
        
        NSLogDebug(@"done with: %@", _runDataPoints);
        
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Complete ride?"
                                                     message:@"Enter name for ride:"
                                                    delegate:nil
                                           cancelButtonTitle:@"Cancel"
                                           otherButtonTitles:@"OK", nil];
        
        av.alertViewStyle = UIAlertViewStylePlainTextInput;
        av.tapBlock = ^(UIAlertView *alertView, NSInteger buttonIndex) {
            if (buttonIndex == 1) {
                NSLogDebug(@"workout name: %@", [[alertView textFieldAtIndex:0] text]);

                long long unixTime = [[NSDate date] timeIntervalSince1970];
                NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
                NSString *filePath = [[NSString alloc] initWithString:[docsDir stringByAppendingPathComponent:[[@(unixTime) stringValue] stringByAppendingPathExtension:kWorkoutFileExtension]]];
                
                NSDictionary *workoutData = @{
                                              kWorkoutFileKeyName: [[alertView textFieldAtIndex:0] text],
                                              kWorkoutFileKeyDate: _startDate,
                                              kWorkoutFileKeyDuration: @((long)[[NSDate date] timeIntervalSinceDate:_startDate]),
                                              kWorkoutFileKeyDistance: @(_gpsDistance),
                                              kWorkoutFileKeyPoints: _runDataPoints
                                              };
                
                if ([workoutData writeToFile:filePath atomically:YES]) {
                    [Common showSimpleInfoAlertWithOk:@"Ride saved"];
                } else {
                    [Common showSimpleInfoAlertWithOk:@"Error saving ride"];
                }
            }
        };
        [av show];
        
        [_startButton setTitle:@"Start" forState:UIControlStateNormal];
        [self enableStartButtonIfNecessary];

        [UIApplication sharedApplication].idleTimerDisabled = NO;
        _appState = kAppStateIdle;
    }
}

- (IBAction)resetPressed:(id)sender
{
    
}

#pragma mark - BLEDelegate methods

- (void)ble:(BLE *)ble didChangeStateToAvailable:(BOOL)available
{
    NSLogDebug(@"entered");
    
    _bleState = kBLEStateScanning;
    [_connectButton setTitle:@"Scanning" forState:UIControlStateNormal];

    [_ble findBLEPeripherals:0 clearExisting:YES];
}

- (void)ble:(BLE *)ble didDiscoverPeripheral:(CBPeripheral *)peripheral isDuplicate:(BOOL)duplicate
{
    NSLogDebug(@"entered");

    if (kBLEStateScanning == _bleState) {
        [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
        _connectButton.enabled = YES;

        // TODO - need to disble this button when we haven't heard from it for a while
        
        self.discoveredPeripheral = peripheral;
    }
}

- (void)bleDidConnect:(BLE *)ble
{
    NSLogDebug(@"entered");

    [_connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
    _connectButton.enabled = YES;

    _bleState = kBLEStateConnected;
    
    self.airspeedPollTimer = [NSTimer scheduledTimerWithTimeInterval:kAirspeedPollInterval
                                                              target:self selector:@selector(airspeedPollTimeout:)
                                                            userInfo:nil repeats:NO];
}

- (void)bleDidDisconnect:(BLE *)ble
{
    NSLogDebug(@"entered");
    
    [_airspeedPollTimer invalidate];
    self.airspeedPollTimer = nil;
    
    // TODO - check if kRequestStateSending == _requestState, then handle error
    // TODO - check if kAppStateRunning == _appState, then handle error

    _lastAirspeed = -1;
    _airspeedLabel.text = @"N/A";

    [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
    _connectButton.enabled = YES;
    
    [self enableStartButtonIfNecessary];
    
    _bleState = kBLEStateScanning;
    
    if (kAppStateRunning == _appState) {
        NSLogDebug(@"trying to automatically reconnect");
        
        [self connectPressed:nil];
    }
}

- (void)ble:(BLE *)ble didUpdateRSSI:(NSNumber *)rssi
{
}

- (void)ble:(BLE *)ble didReceiveData:(unsigned char *)bytes length:(int)length
{
    NSLogDebug(@"entered");
    
    NSAssert(kRequestStateSending == _requestState, @"assert: unexpected message state");
    
    NSMutableString *result = [NSMutableString stringWithCapacity:length*3];
    
    for (int i=0; i<length; i++) {
        [result appendFormat:@"%02X ", bytes[i]];
    }
    
    NSLogDebug(@"received (%d bytes, state %d) <--- %@", length, _requestState, result);

    if (length == 4) {
        _airspeedPingCount = [self updatePingIndicatorForLabel:_airspeedPingLabel count:_airspeedPingCount];

        if (kAppStateRunning == _appState) {
            ++_airspeedCount;
            [self updateBasicStatsTimeout:_updateBasicStatsTimer];
        }
        
        uint32_t dw = [Common dwordForLittleEndianData:[NSData dataWithBytes:bytes length:length]];
        
        // interpret as IEEE 754 (I think)
        _lastAirspeed = *((float *)&dw);
        _airspeedLabel.text = [NSString stringWithFormat:@"%.2f", _lastAirspeed];
        
        [self enableStartButtonIfNecessary];
        
        self.airspeedPollTimer = [NSTimer scheduledTimerWithTimeInterval:kAirspeedPollInterval
                                                                  target:self selector:@selector(airspeedPollTimeout:)
                                                                userInfo:nil repeats:NO];
    } else {
        // TODO - handle error
        _lastAirspeed = -1;
    }
}

#pragma mark - CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *location = [locations lastObject];
    NSLogDebug(@"location: %@", location);
    
    _gpsPingCount = [self updatePingIndicatorForLabel:_gpsPingLabel count:_gpsPingCount];
    
    if ((kAppStateRunning == _appState) && ([location.timestamp compare:_startDate] == NSOrderedAscending)) {
        NSLogDebug(@"location timestamp (%@) is before we started capturing data (%@)", location.timestamp, _startDate);
        return;
    }

    CLLocationDistance distanceMoved = 0;
    CLLocationSpeed speedDelta = 0;
    if (_lastLocation &&
        ((distanceMoved = [location distanceFromLocation:_lastLocation]) < kMinLocationDistance) &&
        ((speedDelta = fabs(_lastLocation.speed - location.speed)) < kMinLocationSpeedDelta)) {
        NSLogDebug(@"didn't move far enough (%.2f m) or change speed enough (%.2f m/s)", distanceMoved, speedDelta);
        return;
    }
    
    self.lastLocation = location;
    _gpsLocationLabel.text = [NSString stringWithFormat:@"%.3f, %.3f", location.coordinate.latitude, location.coordinate.longitude];
    _gpsSpeedLabel.text = (location.speed > 0) ? [NSString stringWithFormat:@"%.2f", location.speed * kConvertMeterPerSecToKMH] : @"N/A";
    _altitudeLabel.text = [NSString stringWithFormat:@"%.f m", location.altitude];

    [self enableStartButtonIfNecessary];
    
    if (kAppStateRunning == _appState) {
        ++_gpsCount;
        _gpsDistance += distanceMoved;
        [self updateBasicStatsTimeout:_updateBasicStatsTimer];
        [self addDataPointWithLocation:_lastLocation distanceMoved:distanceMoved airspeed:_lastAirspeed];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLogError(@"error: %@", error);
    
    self.lastLocation = nil;
    _gpsLocationLabel.text = @"Error";
}

- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager
{
    NSLogDebug(@"entered");
}

- (void)locationManagerDidResumeLocationUpdates:(CLLocationManager *)manager
{
    NSLogDebug(@"entered");
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    NSLogDebug(@"status: %d", status);
    
    if (kCLAuthorizationStatusAuthorizedAlways == status) {
        [_locationManager startUpdatingLocation];
    }
}

@end
