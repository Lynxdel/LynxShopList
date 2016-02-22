//
//  LDShopListEditViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 24/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Math.h>
#import "FMDatabase.h"
#import "LDAppDelegate.h"
#import "ECSlidingViewController.h"
#import "LDShopListXML.h"
#import "LDShopsTableViewController.h"
#import "LDGoodsTableViewController.h"
#import "LDShopListGoodEditViewController.h"
#import "LDShopListEditDetailsViewController.h"

@interface LDShopListEditViewController : UIViewController<UITableViewDataSource, UITableViewDelegate, LDRefSelectValueDelegate, UIGestureRecognizerDelegate>
{
    NSString *_docId;
    NSString *_listName;
    
    NSString *_shopId;
    NSString *_shopName;
    
    BOOL _active;
}

@property (readonly) NSString *docId;
@property (readwrite) NSString *listName;

@property (readwrite) NSString *shopId;
@property (readwrite) NSString *shopName;

@property (readwrite) BOOL active;

@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@property (strong, nonatomic) IBOutlet UIToolbar *toolbar;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *btnAddGood;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *btnEditDone;
// перевод таблицы в режим редактирования и обратно
- (IBAction)editDoneButton:(id)sender;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *btnSort;
// смена режима сортировки
- (IBAction)sortGoodsButton:(id)sender;

@property (weak, nonatomic) IBOutlet UITableView *tvList;

@property (weak, nonatomic) IBOutlet UIView *viewFooter;
@property (weak, nonatomic) IBOutlet UILabel *lblGoodsCountBought;
@property (weak, nonatomic) IBOutlet UILabel *lblGoodsCountAll;
@property (weak, nonatomic) IBOutlet UILabel *lblListSum;

- (IBAction)saveListButton:(id)sender;

// управление состоянием view
- (void)setNewListMode;
- (void)setEditListMode:(NSString *)docId;

- (void)loadData;                                 // загрузка данных загловка
- (void)loadListData;                             // загрузка данных списка из БД
- (BOOL)checkAllGoodsBought;                      // процедура проверки, все ли товары отмечены
- (void)setListActive:(BOOL)activeFlag;           // отметка флага активности в БД
- (void)setListFooter;                            // вывод информации о списке в нижней части формы
- (void)deleteGoodsWithZeroQty;                   // удаление товаров с нулевыми количествами
- (BOOL)deleteGood:(NSString *)docId;             // удаление записи из списка

- (void)saveSectionsState;      // сохранение состояний секций (категорий)
- (void)restoreSectionsState;   // восстановление состояний секций

- (BOOL)saveList:(BOOL)shouldCloseView;     // сохранение записи

- (void)performSelectShopSegue;     // открытие таблицы магазинов для выбора из справочника

@end
