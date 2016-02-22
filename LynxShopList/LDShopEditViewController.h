//
//  LDShopEditViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 17/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FMDatabase.h"
#import "LDAppDelegate.h"

@interface LDShopEditViewController : UIViewController<UITextFieldDelegate>

@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@property (weak, nonatomic) IBOutlet UITextField *txtShopName;

- (IBAction)saveShopButton:(id)sender;

// управление состоянием view
- (void)setNewShopMode;
- (void)setEditShopMode:(NSString *)docId withName:(NSString *)shopName;

- (void)saveShop;       // сохранение новой записи

@end
