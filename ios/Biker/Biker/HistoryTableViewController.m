//
//  HistoryTableViewController.m
//  Biker
//
//  Created by Dale Low on 11/2/14.
//  Copyright (c) 2014 gumbypp consulting. All rights reserved.
//

#import "HistoryTableViewController.h"

#import "common.h"
#import "HistoryItemTableViewCell.h"
#import "RideViewController.h"

@interface HistoryTableViewController ()

@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSString *documentsFolder;
@property (nonatomic, strong) NSMutableArray *dataArray;
@property (nonatomic, strong) NSMutableDictionary *historyDictionary;

@end

@implementation HistoryTableViewController

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
    self.title = @"Rides";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.documentsFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    self.dataArray = [NSMutableArray array];
    self.historyDictionary = [NSMutableDictionary dictionary];

    self.dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    [_dateFormatter setDateStyle:NSDateFormatterMediumStyle];

    [self refreshFileList];
}

#pragma mark - internal methods

- (void)refreshFileList
{
    // dump previous list and cache
    [_dataArray removeAllObjects];
    [_historyDictionary removeAllObjects];

    NSString *file;
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:_documentsFolder];
    while (file = [enumerator nextObject]) {
        if ([[file pathExtension] isEqualToString:kWorkoutFileExtension]) {
            [_dataArray addObject:file];
        }
    }
    
    // newest first
    [_dataArray sortWithOptions:0 usingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSComparisonResult result = [obj1 compare:obj2];
        if (result == NSOrderedSame) {
            return result;
        }
        
        return (NSOrderedAscending == result) ? NSOrderedDescending : NSOrderedAscending;
    }];
    
    NSLogDebug(@"found files: %@ in %@", _dataArray, _documentsFolder);
    [self.tableView reloadData];
}

- (NSDictionary *)dataDictionaryForFile:(NSString *)filename
{
    // lazy-load and cache for next time
    NSDictionary *historyItem = _historyDictionary[filename];
    if (!historyItem) {
        historyItem = [NSDictionary dictionaryWithContentsOfFile:[_documentsFolder stringByAppendingPathComponent:filename]];
        _historyDictionary[filename] = historyItem;
    }
    
    return historyItem;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    HistoryItemTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[HistoryItemTableViewCell reuseIdentifier] forIndexPath:indexPath];
    
    NSString *file = _dataArray[indexPath.row];
    NSDictionary *dataDictionary = [self dataDictionaryForFile:file];
    
    cell.nameLabel.text = dataDictionary[kWorkoutFileKeyName];
    cell.descriptionLabel.text = [NSString stringWithFormat:@"%@ (%.2f km)",
                                  [Common formatTimeDuration:[dataDictionary[kWorkoutFileKeyDuration] doubleValue]],
                                  [dataDictionary[kWorkoutFileKeyDistance] doubleValue]/1000];
    cell.dateLabel.text = [_dateFormatter stringFromDate:dataDictionary[kWorkoutFileKeyDate]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    RideViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"RideViewController"];
    vc.dataDictionary = [self dataDictionaryForFile:_dataArray[indexPath.row]];
    vc.title = vc.dataDictionary[kWorkoutFileKeyName];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
