//
//  LDMeasureEditViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 08/02/14.
//  Copyright (c) 2014 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FMDatabase.h"
#import "LDAppDelegate.h"

@interface LDMeasureEditViewController : UIViewController<UITextFieldDelegate>

@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@property (weak, nonatomic) IBOutlet UITextField *txtMeasureName;
@property (weak, nonatomic) IBOutlet UITextField *txtMeasureName234;
@property (weak, nonatomic) IBOutlet UITextField *txtMeasureName567890;
- (IBAction)measureNameChanged:(id)sender;

@property (weak, nonatomic) IBOutlet UITextField *txtIncQty;
- (IBAction)incQtyTextEditingEnded:(id)sender;

- (IBAction)saveMeasureButton:(id)sender;

// управление состоянием view
- (void)setNewMeasureMode;
- (void)setEditMeasureMode:(NSString *)docId;

- (void)loadData;       // загрузка данных
- (void)saveMeasure;    // сохранение новой записи

@end
