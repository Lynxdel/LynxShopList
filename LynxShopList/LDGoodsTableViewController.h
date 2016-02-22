//
//  LDGoodsTableViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 20/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Math.h>
#import "FMDatabase.h"
#import "LDAppDelegate.h"
#import "LDGoodEditViewController.h"
#import "LDRefSelectValueDelegate.h"
#import "LDRefCreateValueDelegate.h"

@interface LDGoodsTableViewController : UIViewController<UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIGestureRecognizerDelegate, LDRefCreateValueDelegate>
{
    id <LDRefSelectValueDelegate> parentViewDelegate;
}

@property (strong) id parentViewDelegate;   // ссылка на view, вызвавший табличную форму в режиме справочника

@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *addButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *btnFilter;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *editDoneButton;
@property (weak, nonatomic) IBOutlet UITableView *tvData;

- (void)loadData:(NSString *)namesLike showSectionsExpanded:(BOOL)expanded;     // извлечение данных из БД
- (void)setReferenceMode:(NSString *)shopListId;                                // перевод табличной формы в режим справочника

// closeTableView - флаг, определяющий, нужно ли закрыть табличную форму товаров после выбора товара
- (void)addGoodToShopList:(BOOL)closeTableView;     // выбор товара (в режиме справочника)

- (IBAction)editListButton:(id)sender;      // перевод таблицы в режим редактирования и обратно
- (BOOL)deleteElement:(NSString *)docId;    // удаление записи

- (void)expandCollapseSection:(long)section;         // процедура сворачивания/развертывания секции
- (void)reloadListDataAt:(NSIndexPath *)indexPath;  // загрузка из БД и перерисовка элемента в заданной строке

// функции управления фильтрацией по категориям
- (void)addFilterCategory:(NSString *)categoryId;
- (void)removeFilterCategory:(NSString *)categoryId;
- (void)clearFilterCategories;

- (IBAction)filterButton:(id)sender;

@end
