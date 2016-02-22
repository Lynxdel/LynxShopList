//
//  LDShopListGoodEditViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 28/12/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FMDatabase.h"
#import "LDAppDelegate.h"

@interface LDShopListGoodEditViewController : UIViewController<UITextFieldDelegate>

@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@property (weak, nonatomic) IBOutlet UITextField *txtGoodName;
@property (weak, nonatomic) IBOutlet UITextField *txtMeasureName;
@property (weak, nonatomic) IBOutlet UITextField *txtQty;
@property (weak, nonatomic) IBOutlet UITextField *txtPrice;
@property (weak, nonatomic) IBOutlet UITextField *txtAmount;
@property (weak, nonatomic) IBOutlet UITextView *txtComment;
@property (weak, nonatomic) IBOutlet UIStepper *stepperQty;

- (IBAction)stepperQtyValueChanged:(id)sender;
- (IBAction)qtyTextEditingEnded:(id)sender;

- (IBAction)priceTextEditingEnded:(id)sender;
- (IBAction)amountTextEditingEnded:(id)sender;

- (IBAction)saveShopListGood:(id)sender;

- (void)setEditMode:(NSString *)docId;

- (void)loadData;   // загрузка записи из БД
- (void)saveData;   // обновление записи

@end
