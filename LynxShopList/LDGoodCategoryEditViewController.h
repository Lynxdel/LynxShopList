//
//  LDGoodCategoryEditViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 20/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FMDatabase.h"
#import "LDAppDelegate.h"

@interface LDGoodCategoryEditViewController : UIViewController<UITextFieldDelegate>

@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@property (weak, nonatomic) IBOutlet UITextField *txtCatName;

@property (weak, nonatomic) IBOutlet UISlider *sldR;
@property (weak, nonatomic) IBOutlet UISlider *sldG;
@property (weak, nonatomic) IBOutlet UISlider *sldB;
@property (weak, nonatomic) IBOutlet UISlider *sldA;

- (IBAction)sldValueChaged:(id)sender;

@property (weak, nonatomic) IBOutlet UILabel *lblR;
@property (weak, nonatomic) IBOutlet UILabel *lblG;
@property (weak, nonatomic) IBOutlet UILabel *lblB;
@property (weak, nonatomic) IBOutlet UILabel *lblA;

@property (weak, nonatomic) IBOutlet UITextView *pnlCatColor;

- (IBAction)decRButton:(id)sender;
- (IBAction)incRButton:(id)sender;

- (IBAction)decGButton:(id)sender;
- (IBAction)incGButton:(id)sender;

- (IBAction)decBButton:(id)sender;
- (IBAction)incBButton:(id)sender;

- (IBAction)decAlphaButton:(id)sender;
- (IBAction)incAlphaButton:(id)sender;

- (IBAction)saveCatButton:(id)sender;

// управление состоянием view
- (void)setNewCatMode;
- (void)setEditCatMode:(NSString *)docId withName:(NSString *)catName;

- (void)loadColors;    // загрузка информации о цвете категории
- (void)saveCat;       // сохранение новой записи

@end
