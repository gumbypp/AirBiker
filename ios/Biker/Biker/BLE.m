//
//  BLE.m
//  Biker
//
//  Created by Dale Low on 9/26/14.
//  Copyright (c) 2014 gumbypp consulting. All rights reserved.
//

/*
 Based on work by:
 
 Copyright (c) 2013 RedBearLab
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 */

#import "BLE.h"
#import "BLEDefines.h"

static const NSTimeInterval kDevicePresenceTimeout = 15.f;      // how long to wait before discarding previously-discovered devices
static const NSTimeInterval kDevicePresenceCheckInterval = 3.f;

@interface BLE ()

@property (nonatomic, strong) CBCentralManager *CM;
@property (nonatomic, strong) NSTimer *presenceTimer;
@property (nonatomic, strong) NSMutableDictionary *peripheralExpirationDateDictionary;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) int rssi;

@end

@implementation BLE

- (id)init
{
    self = [super init];
    if (self) {
        _peripheralExpirationDateDictionary = [NSMutableDictionary dictionary];
        _peripherals = [NSMutableArray array];
    }
    
    return self;
}

#pragma mark - internal methods

- (void)readRSSI
{
    [_activePeripheral readRSSI];
}

- (BOOL)read
{
    CBUUID *uuid_service = [CBUUID UUIDWithString:@RBL_SERVICE_UUID];
    CBUUID *uuid_char = [CBUUID UUIDWithString:@RBL_CHAR_TX_UUID];
    
    return [self readValue:uuid_service characteristicUUID:uuid_char p:_activePeripheral];
}

- (BOOL)enableTxCharacteristicReadNotificationForPeripheral:(CBPeripheral *)p
{
    CBUUID *uuid_service = [CBUUID UUIDWithString:@RBL_SERVICE_UUID];
    CBUUID *uuid_char = [CBUUID UUIDWithString:@RBL_CHAR_TX_UUID];
    
    return [self notification:uuid_service characteristicUUID:uuid_char p:p on:YES];
}

- (BOOL)notification:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID p:(CBPeripheral *)p on:(BOOL)on
{
    CBService *service = [self findServiceFromUUID:serviceUUID p:p];
    
    if (!service) {
        NSLogWarn(@"Could not find service with UUID %@ on peripheral with UUID %@",
                  serviceUUID,
                  p.identifier.UUIDString);
        
        return NO;
    }
    
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    
    if (!characteristic) {
        NSLogWarn(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
                  characteristicUUID,
                  serviceUUID,
                  p.identifier.UUIDString);
        
        return NO;
    }
    
    [p setNotifyValue:on forCharacteristic:characteristic];
    
    return YES;
}

- (BOOL)readValue:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID p:(CBPeripheral *)p
{
    CBService *service = [self findServiceFromUUID:serviceUUID p:p];
    
    if (!service) {
        NSLogWarn(@"Could not find service with UUID %@ on peripheral with UUID %@",
                  serviceUUID,
                  p.identifier.UUIDString);
        
        return NO;
    }
    
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    
    if (!characteristic) {
        NSLogWarn(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
                  characteristicUUID,
                  serviceUUID,
                  p.identifier.UUIDString);
        
        return NO;
    }
    
    [p readValueForCharacteristic:characteristic];
    
    return YES;
}

- (BOOL)writeValue:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID p:(CBPeripheral *)p data:(NSData *)data
{
    CBService *service = [self findServiceFromUUID:serviceUUID p:p];
    
    if (!service) {
        NSLogWarn(@"Could not find service with UUID %@ on peripheral with UUID %@",
                  serviceUUID,
                  p.identifier.UUIDString);
        
        return NO;
    }
    
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    
    if (!characteristic) {
        NSLogWarn(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
                  characteristicUUID,
                  serviceUUID,
                  p.identifier.UUIDString);
        
        return NO;
    }
    
    [p writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
    
    return YES;
}

- (const char *)centralManagerStateToString:(int)state
{
    switch(state)
    {
        case CBCentralManagerStateUnknown:
            return "State unknown (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateResetting:
            return "State resetting (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateUnsupported:
            return "State BLE unsupported (CBCentralManagerStateResetting)";
        case CBCentralManagerStateUnauthorized:
            return "State unauthorized (CBCentralManagerStateUnauthorized)";
        case CBCentralManagerStatePoweredOff:
            return "State BLE powered off (CBCentralManagerStatePoweredOff)";
        case CBCentralManagerStatePoweredOn:
            return "State powered up and ready (CBCentralManagerStatePoweredOn)";
        default:
            return "State unknown";
    }
    
    return "Unknown state";
}

- (void)scanTimer:(NSTimer *)timer
{
    [_presenceTimer invalidate];
    self.presenceTimer = nil;
    
    [_CM stopScan];
    
    NSLogDebug(@"Stopped Scanning");
    NSLogDebug(@"Known peripherals: %lu", (unsigned long)[_peripherals count]);
    
    [self printKnownPeripherals];
}

- (void)printKnownPeripherals
{
    NSLogDebug(@"List of currently known peripherals :");
    
    for (int i = 0; i < _peripherals.count; i++) {
        CBPeripheral *p = [_peripherals objectAtIndex:i];
        
        if (p.identifier != NULL) {
            NSLogDebug(@"%d  |  %@", i, p.identifier.UUIDString);
        } else {
            NSLogDebug(@"%d  |  NULL", i);
        }
        
        [self printPeripheralInfo:p];
    }
}

- (void)printPeripheralInfo:(CBPeripheral*)peripheral
{
    NSLogDebug(@"------------------------------------");
    NSLogDebug(@"Peripheral Info :");
    
    if (peripheral.identifier != NULL) {
        NSLogDebug(@"UUID: %@", peripheral.identifier.UUIDString);
    } else {
        NSLogDebug(@"UUID: NULL");
    }
    
    NSLogDebug(@"Name: %@", peripheral.name);
    NSLogDebug(@"-------------------------------------");
}

- (BOOL)UUIDSAreEqual:(NSUUID *)UUID1 UUID2:(NSUUID *)UUID2
{
    if ([UUID1.UUIDString isEqualToString:UUID2.UUIDString]) {
        return YES;
    }
    
    return NO;
}

- (void)getTxRxCharacteristicsFromPeripheral:(CBPeripheral *)p
{
    for (int i=0; i < p.services.count; i++) {
        CBService *s = [p.services objectAtIndex:i];
        
        NSLogDebug(@"found service: %@", s.UUID);
        
        if ([s.UUID isEqual:[CBUUID UUIDWithString:@RBL_SERVICE_UUID]]) {
            NSLogDebug(@"Fetching tx/rx characteristics for service with UUID %@", s.UUID);
            
            [p discoverCharacteristics:@[[CBUUID UUIDWithString:@RBL_CHAR_TX_UUID], [CBUUID UUIDWithString:@RBL_CHAR_RX_UUID]]
                            forService:s];
        }
    }
}

- (int)compareCBUUID:(CBUUID *)UUID1 UUID2:(CBUUID *)UUID2
{
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1];
    [UUID2.data getBytes:b2];
    
    if (memcmp(b1, b2, UUID1.data.length) == 0) {
        return 1;
    } else {
        return 0;
    }
}

- (CBUUID *)IntToCBUUID:(UInt16)UUID
{
    char t[16];
    t[0] = ((UUID >> 8) & 0xff); t[1] = (UUID & 0xff);
    NSData *data = [[NSData alloc] initWithBytes:t length:16];
    return [CBUUID UUIDWithData:data];
}

- (CBService *)findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p
{
    for (int i = 0; i < p.services.count; i++) {
        CBService *s = [p.services objectAtIndex:i];
        if ([self compareCBUUID:s.UUID UUID2:UUID]) {
            return s;
        }
    }
    
    return nil; //Service not found on this peripheral
}

- (CBCharacteristic *)findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service
{
    for (int i=0; i < service.characteristics.count; i++) {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([self compareCBUUID:c.UUID UUID2:UUID]) {
            return c;
        }
    }
    
    return nil; //Characteristic not found on this service
}

#if TARGET_OS_IPHONE
//-- no need for iOS
#else
- (BOOL)isLECapableHardware
{
    NSString * state = nil;
    
    switch ([CM state]) {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
            
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
            
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
            
        case CBCentralManagerStatePoweredOn:
            return YES;
            
        case CBCentralManagerStateUnknown:
        default:
            return NO;
            
    }
    
    NSLogDebug(@"Central manager state: %@", state);
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:state];
    [alert addButtonWithTitle:@"OK"];
    [alert setIcon:[[NSImage alloc] initWithContentsOfFile:@"AppIcon"]];
    [alert beginSheetModalForWindow:nil modalDelegate:self didEndSelector:nil contextInfo:nil];
    
    return NO;
}
#endif

#pragma mark - event handlers

- (void)presenceCheckTimeout:(NSTimer *)timer
{
    if (timer != _presenceTimer) {
        return;
    }
    
    NSDate *now = [NSDate date];
    
    NSLogDebug(@"comparing now (%@) to %@", now, _peripheralExpirationDateDictionary);
    
    for (NSString *identifierUUIDString in _peripheralExpirationDateDictionary) {
        if ([((NSDate *)_peripheralExpirationDateDictionary[identifierUUIDString]) compare:now] == NSOrderedAscending) {
            for (int i = 0; i < _peripherals.count; i++) {
                CBPeripheral *p = [_peripherals objectAtIndex:i];
                if (p.identifier && [p.identifier.UUIDString isEqualToString:identifierUUIDString]) {
                    // this guy's time has come
                    NSLogDebug(@"removing expired peripheral: %@", p);
                    [_peripherals removeObjectAtIndex:i];
                    [_peripheralExpirationDateDictionary removeObjectForKey:identifierUUIDString];
                    
                    // tell our delegate
                    [_delegate ble:self didDiscoverPeripheral:nil isDuplicate:NO];
                    return;
                }
            }
            
            NSLogWarn(@"where did %@ go?  He's not in %@", identifierUUIDString, _peripherals);
        }
    }
}

#pragma mark - public methods

- (void)controlSetup
{
    self.CM = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

- (int)findBLEPeripherals:(int)timeout clearExisting:(BOOL)clearExisting
{
    if (_CM.state != CBCentralManagerStatePoweredOn) {
        NSLogWarn(@"CoreBluetooth not correctly initialized !");
        NSLogWarn(@"State = %d (%s)", _CM.state, [self centralManagerStateToString:_CM.state]);
        return -1;
    }
    
    // start with an empty list?
    if (clearExisting) {
        [_peripherals removeAllObjects];
        [_peripheralExpirationDateDictionary removeAllObjects];
    }
    
    if (timeout > 0) {
        [NSTimer scheduledTimerWithTimeInterval:(float)timeout target:self selector:@selector(scanTimer:) userInfo:nil repeats:NO];
    }
    
#if TARGET_OS_IPHONE
    [_CM scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:@RBL_SERVICE_UUID]]
                                options:@{ CBCentralManagerScanOptionAllowDuplicatesKey: @YES }];
#else
    [_CM scanForPeripheralsWithServices:nil options:nil]; // Start scanning
#endif
    
    NSLogDebug(@"scanForPeripheralsWithServices");
    
    [_presenceTimer invalidate];
    self.presenceTimer = [NSTimer scheduledTimerWithTimeInterval:kDevicePresenceCheckInterval
                                                          target:self selector:@selector(presenceCheckTimeout:)
                                                        userInfo:nil repeats:YES];
    
    return 0; // Started scanning OK !
}

- (void)stopFindingBLEPeripherals
{
    [_presenceTimer invalidate];
    self.presenceTimer = nil;
    
    [_CM stopScan];
}

- (void)connectPeripheral:(CBPeripheral *)peripheral
{
    NSLogDebug(@"Connecting to peripheral with identifier: %@", peripheral.identifier.UUIDString);
    
    [_CM connectPeripheral:peripheral
                   options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
}

- (void)abortPeripheralConnection:(CBPeripheral *)peripheral
{
    [_CM cancelPeripheralConnection:peripheral];
}

- (BOOL)write:(NSData *)d
{
    CBUUID *uuid_service = [CBUUID UUIDWithString:@RBL_SERVICE_UUID];
    CBUUID *uuid_char = [CBUUID UUIDWithString:@RBL_CHAR_RX_UUID];
    
    return [self writeValue:uuid_service characteristicUUID:uuid_char p:_activePeripheral data:d];
}

- (BOOL)disconnectActivePeripheral
{
    if (_activePeripheral.state == CBPeripheralStateConnected) {
        [_CM cancelPeripheralConnection:_activePeripheral];
        return YES;
    }
    
    return NO;
}

#pragma mark - CBCentralManagerDelegate methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
#if TARGET_OS_IPHONE
    NSLogDebug(@"Status of CoreBluetooth central manager changed %d (%s)", central.state, [self centralManagerStateToString:central.state]);
    
    BOOL available = (CBCentralManagerStatePoweredOn == central.state);
    if (!available) {
        [_peripherals removeAllObjects];
        [_peripheralExpirationDateDictionary removeAllObjects];
    }

    [_delegate ble:self didChangeStateToAvailable:available];
#else
    [self isLECapableHardware];
#endif
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    for (int i = 0; i < _peripherals.count; i++) {
        CBPeripheral *p = [_peripherals objectAtIndex:i];
        
        if ((p.identifier == NULL) || (peripheral.identifier == NULL)) {
            continue;
        }
        
        if ([self UUIDSAreEqual:p.identifier UUID2:peripheral.identifier]) {
            if ([p isEqual:peripheral]) {
                // nothing new here - just reset this guy's expiration timer
                _peripheralExpirationDateDictionary[peripheral.identifier.UUIDString] = [NSDate dateWithTimeIntervalSinceNow:kDevicePresenceTimeout];
                return;
            }
            
            [_peripherals replaceObjectAtIndex:i withObject:peripheral];
            NSLogDebug(@"Duplicate peripheral found updating...");
            
            [_delegate ble:self didDiscoverPeripheral:peripheral isDuplicate:YES];
            return;
        }
    }
    
    [_peripherals addObject:peripheral];
    
    NSLogDebug(@"New peripheral, adding");
    [_delegate ble:self didDiscoverPeripheral:peripheral isDuplicate:NO];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if (peripheral.identifier != NULL) {
        NSLogDebug(@"Connected to %@ successful", peripheral.identifier.UUIDString);
    } else {
        NSLogDebug(@"Connected to NULL successful");
    }
    
    self.activePeripheral = peripheral;
    _activePeripheral.delegate = self;
    [_activePeripheral discoverServices:@[[CBUUID UUIDWithString:@RBL_SERVICE_UUID]]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;
{
    NSLogDebug(@"error: %@", error);
    
    self.activePeripheral = nil;
    [_delegate bleDidDisconnect:self];
    
    _isConnected = NO;
}

#pragma mark - CBPeripheralDelegate methods

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (!error) {
        NSLogDebug(@"Characteristics of service with UUID %@ found", service.UUID);
        
        for (int i=0; i < service.characteristics.count; i++) {
            CBCharacteristic *c = [service.characteristics objectAtIndex:i];
            
            /*
             typedef enum {
             CBCharacteristicPropertyBroadcast  = 0x01 ,
             CBCharacteristicPropertyRead  = 0x02 ,
             CBCharacteristicPropertyWriteWithoutResponse  = 0x04 ,
             CBCharacteristicPropertyWrite  = 0x08 ,
             CBCharacteristicPropertyNotify  = 0x10 ,
             CBCharacteristicPropertyIndicate  = 0x20 ,
             CBCharacteristicPropertyAuthenticatedSignedWrites  = 0x40 ,
             CBCharacteristicPropertyExtendedProperties  = 0x80 ,
             CBCharacteristicPropertyNotifyEncryptionRequired  = 0x100 ,
             CBCharacteristicPropertyIndicateEncryptionRequired  = 0x200 ,
             } CBCharacteristicProperties;
             */
            
            NSMutableString *properties = [[NSMutableString alloc] init];
            if (c.properties & CBCharacteristicPropertyBroadcast) [properties appendString:@"Broadcast "];
            if (c.properties & CBCharacteristicPropertyRead) [properties appendString:@"Read "];
            if (c.properties & CBCharacteristicPropertyWriteWithoutResponse) [properties appendString:@"WriteWithoutResponse "];
            if (c.properties & CBCharacteristicPropertyWrite) [properties appendString:@"Write "];
            if (c.properties & CBCharacteristicPropertyNotify) [properties appendString:@"Notify "];
            if (c.properties & CBCharacteristicPropertyIndicate) [properties appendString:@"Indicate "];
            if (c.properties & CBCharacteristicPropertyAuthenticatedSignedWrites) [properties appendString:@"AuthenticatedSignedWrites "];
            if (c.properties & CBCharacteristicPropertyExtendedProperties) [properties appendString:@"ExtendedProperties "];
            if (c.properties & CBCharacteristicPropertyNotifyEncryptionRequired) [properties appendString:@"NotifyEncryptionRequired "];
            if (c.properties & CBCharacteristicPropertyIndicateEncryptionRequired) [properties appendString:@"IndicateEncryptionRequired "];
            
            NSLogDebug(@"Found characteristic %@", c.UUID);
            NSLogDebug(@"properties: %@", properties);
            
        }
        
        // we're only discovering one service, so we're done
        [self enableTxCharacteristicReadNotificationForPeripheral:_activePeripheral];
    } else {
        NSLogDebug(@"Characteristic discorvery unsuccessful!");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (!error) {
        NSLogDebug(@"Services of %@ found", peripheral.identifier.UUIDString);
        [self getTxRxCharacteristicsFromPeripheral:peripheral];
    } else {
        NSLogWarn(@"Service discovery was unsuccessful!");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (!error) {
        NSLogDebug(@"Updated notification state for characteristic with UUID %@ on service with  UUID %@ on peripheral with UUID %@",
                   characteristic.UUID, characteristic.service.UUID, peripheral.identifier.UUIDString);
        
        _isConnected = YES;
        [_delegate bleDidConnect:self];
    } else {
        NSLogWarn(@"Error in setting notification state for characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
                  characteristic.UUID,
                  characteristic.service.UUID,
                  peripheral.identifier.UUIDString);
        
        NSLogDebug(@"Error code was %s", [[error description] cStringUsingEncoding:NSStringEncodingConversionAllowLossy]);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    unsigned char data[20];
    
    static unsigned char buf[512];
    static int len = 0;
    NSInteger data_len;
    
    if (!error) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@RBL_CHAR_TX_UUID]]) {
            data_len = characteristic.value.length;
            [characteristic.value getBytes:data length:data_len];
            
            if (data_len == 20) {
                memcpy(&buf[len], data, 20);
                len += data_len;
                
                if (len >= 64) {
                    [_delegate ble:self didReceiveData:buf length:len];
                    len = 0;
                }
            } else if (data_len < 20) {
                memcpy(&buf[len], data, data_len);
                len += data_len;
                
                [_delegate ble:self didReceiveData:buf length:len];
                len = 0;
            }
        }
    } else {
        NSLogWarn(@"updateValueForCharacteristic failed!");
    }
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
    if (_rssi != peripheral.RSSI.intValue) {
        _rssi = peripheral.RSSI.intValue;
        [_delegate ble:self didUpdateRSSI:_activePeripheral.RSSI];
    }
}

@end
