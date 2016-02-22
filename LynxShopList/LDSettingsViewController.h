//
//  LDSettingsViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 16/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LDSettingsViewController : UITableViewController

@property (weak, nonatomic) IBOutlet UISwitch *switchHideBought;
- (IBAction)switchHideBoughtValueChanged:(id)sender;

@property (strong, nonatomic) IBOutlet UISwitch *switchBoughtAtBottom;
- (IBAction)switchBoughtAtBottomValueChanged:(id)sender;

@property (strong, nonatomic) IBOutlet UISwitch *switchCategoriesInLists;
- (IBAction)switchCategoriesInListsValueChanged:(id)sender;

@property (strong, nonatomic) IBOutlet UISegmentedControl *scGoodCellView;
- (IBAction)scGoodCellViewValueChanged:(id)sender;

@end
