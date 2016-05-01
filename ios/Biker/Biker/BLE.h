//
//  BLE.h
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

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
    #import <CoreBluetooth/CoreBluetooth.h>
#else
    #import <IOBluetooth/IOBluetooth.h>
#endif

#import "common.h"

@class BLE;

@protocol BLEDelegate
@optional
- (void)ble:(BLE *)ble didChangeStateToAvailable:(BOOL)available;
- (void)ble:(BLE *)ble didDiscoverPeripheral:(CBPeripheral *)peripheral isDuplicate:(BOOL)duplicate;
- (void)bleDidConnect:(BLE *)ble;
- (void)bleDidDisconnect:(BLE *)ble;
- (void)ble:(BLE *)ble didUpdateRSSI:(NSNumber *)rssi;
- (void)ble:(BLE *)ble didReceiveData:(unsigned char *)data length:(int)length;
@required
@end

@interface BLE : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate> {
    
}

@property (nonatomic, weak) id <BLEDelegate> delegate;
@property (nonatomic, strong) NSMutableArray *peripherals;
@property (nonatomic, strong) CBPeripheral *activePeripheral;
@property (nonatomic, readonly) BOOL isConnected;

- (void)controlSetup;
- (void)stopFindingBLEPeripherals;
- (int)findBLEPeripherals:(int)timeout clearExisting:(BOOL)clearExisting;
- (void)connectPeripheral:(CBPeripheral *)peripheral;
- (void)abortPeripheralConnection:(CBPeripheral *)peripheral;
- (BOOL)write:(NSData *)d;
- (BOOL)disconnectActivePeripheral;

@end
