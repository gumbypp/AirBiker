//
//  RideViewController.m
//  Biker
//
//  Created by Dale Low on 11/3/14.
//  Copyright (c) 2014 gumbypp consulting. All rights reserved.
//

#import "RideViewController.h"

#import <MapKit/MapKit.h>
#import "common.h"

typedef enum
{
    kAirspeedZoneLow,
    kAirspeedZoneMedium,
    kAirspeedZoneHigh
} AirspeedZone;

@interface RideViewController ()

@property (nonatomic, weak) IBOutlet MKMapView *mapView;

@property (nonatomic, assign) AirspeedZone currentZone;

@end

@implementation RideViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // time,lat,long,hacc(m),alt(m),vacc(m),speed(km/h),airspeed(km/h),distance(m)
    NSArray *points = _dataDictionary[kWorkoutFileKeyPoints];

    CLLocationDegrees minLat = 90, maxLat = -90;
    CLLocationDegrees minLong = 180, maxLong = -180;
    CLLocationCoordinate2D coordinates[points.count-1];
    
    _currentZone = kAirspeedZoneLow;
    
    int j = 0;
    for (int i=0; i<(points.count-1) /* skip legend */; i++) {
        NSString *point = points[i+1];
        NSArray *pointItems = [point componentsSeparatedByString:@","];

        coordinates[j].latitude = [pointItems[1] doubleValue];
        coordinates[j].longitude = [pointItems[2] doubleValue];

        minLat = MIN(minLat, coordinates[j].latitude);
        maxLat = MAX(maxLat, coordinates[j].latitude);
        minLong = MIN(minLong, coordinates[j].longitude);
        maxLong = MAX(maxLong, coordinates[j].longitude);

        j++;
        
        AirspeedZone zone = [self zoneForAirspeed:[pointItems[7] floatValue]];
        if ((zone != _currentZone) || (i == (points.count-2))) {
            // close current zone
            MKPolyline *polyline = [MKPolyline polylineWithCoordinates:coordinates count:j];
            [self.mapView addOverlay:polyline];
            
            // start new zone
            _currentZone = zone;
            j = 0;
        }
    }
    
    MKCoordinateRegion region;
    region.center.latitude = (minLat + maxLat)/2;
    region.center.longitude = (minLong + maxLong)/2;
    region.span.latitudeDelta = maxLat - minLat + 0.005;
    region.span.longitudeDelta = maxLong - minLong + 0.005;
    
    [self.mapView setRegion:region animated:YES];
}

#pragma mark - internal methods

- (AirspeedZone)zoneForAirspeed:(float)airspeed
{
    // TODO: this should depend on the current speed
    if (airspeed < 3.5) return kAirspeedZoneLow;
    if (airspeed < 6.5) return kAirspeedZoneMedium;
    return kAirspeedZoneHigh;
}

#pragma mark - MKMapViewDelegate methods

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        MKPolyline *route = overlay;
        MKPolylineRenderer *routeRenderer = [[MKPolylineRenderer alloc] initWithPolyline:route];
        
        switch (_currentZone) {
            default:
            case kAirspeedZoneLow:
                routeRenderer.strokeColor = [UIColor greenColor];
                break;

            case kAirspeedZoneMedium:
                routeRenderer.strokeColor = [UIColor yellowColor];
                break;

            case kAirspeedZoneHigh:
                routeRenderer.strokeColor = [UIColor redColor];
                break;
        }
        
        routeRenderer.lineWidth = 5;

        return routeRenderer;
    }
    
    return nil;
}

@end
