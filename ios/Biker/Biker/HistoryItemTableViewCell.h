//
//  HistoryItemTableViewCell.h
//  Biker
//
//  Created by Dale Low on 11/3/14.
//  Copyright (c) 2014 gumbypp consulting. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HistoryItemTableViewCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel *nameLabel;
@property (nonatomic, weak) IBOutlet UILabel *descriptionLabel;
@property (nonatomic, weak) IBOutlet UILabel *dateLabel;

+ (NSString *)reuseIdentifier;

@end
