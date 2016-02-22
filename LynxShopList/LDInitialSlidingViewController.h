//
//  LDInitialSlidingViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 06/06/14.
//  Copyright (c) 2014 Денис Ломанов. All rights reserved.
//

#import "ECSlidingViewController.h"
#import "LDShopListsTableViewController.h"
#import "LDShopListEditViewController.h"

@interface LDInitialSlidingViewController : ECSlidingViewController

// открытие импортированного из файла списка
- (void)openImportedList:(NSString *)listId;

@end
