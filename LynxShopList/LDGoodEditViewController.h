//
//  LDGoodEditViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 20/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FMDatabase.h"
#import "LDAppDelegate.h"
#import "LDGoodCategoriesTableViewController.h"
#import "LDMeasuresTableViewController.h"
#import "LDRefCreateValueDelegate.h"

@interface LDGoodEditViewController : UIViewController<LDRefSelectValueDelegate, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
{
    id <LDRefCreateValueDelegate> parentCreateViewDelegate;
}

@property (strong) id parentCreateViewDelegate;   // ссылка на view, вызвавший форму редактирования

@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@property (weak, nonatomic) IBOutlet UITextField *txtGoodName;
@property (weak, nonatomic) IBOutlet UITextField *txtCategoryName;
@property (weak, nonatomic) IBOutlet UITextField *txtMeasureName;
@property (weak, nonatomic) IBOutlet UITextField *txtPrice;

@property (strong, nonatomic) UITableView *tvSearchReference;   // таблица с результатами поиска категорий и единиц измерения

// управление состоянием view
- (void)setNewGoodMode;
- (void)setEditGoodMode:(NSString *)docId;
- (void)setCategoryForNewGood:(NSString *)categoryId with:(NSString *)categoryName;

- (void)loadData;                                                           // загрузка данных
- (void)loadFilteredData:(NSString *)fromTable with:(NSString *)namesLike;  // извлечение данных заданного справочника из БД

- (void)saveGood;                       // сохранение новой записи
- (IBAction)saveGoodButton:(id)sender;

// обработчики для подбора значений справочников
- (IBAction)categoryEditingChanged:(id)sender;
- (IBAction)categoryEditingDidEnd:(id)sender;

- (IBAction)measureEditingChanged:(id)sender;
- (IBAction)measureEditingDidEnd:(id)sender;

@end
