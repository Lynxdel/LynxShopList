//
//  LDShopsTableViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 16/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FMDatabase.h"
#import "LDAppDelegate.h"
#import "LDShopEditViewController.h"
#import "LDRefSelectValueDelegate.h"

@interface LDShopsTableViewController : UIViewController<UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
{
    id<LDRefSelectValueDelegate> parentViewDelegate;
}

@property (strong) id parentViewDelegate;   // ссылка на view, вызвавший табличную форму в режиме справочника

@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *addButton;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *editDoneButton;
@property (weak, nonatomic) IBOutlet UITableView *tvData;

- (void)loadData:(NSString *)namesLike; // извлечение данных из БД
- (void)setReferenceMode;               // перевод табличной формы в режим справочника
- (void)selectShop;                     // выбор магазина (в режиме справочника)

- (IBAction)editListButton:(id)sender;      // перевод таблицы в режим редактирования и обратно
- (BOOL)deleteElement:(NSString *)docId;    // удаление записи

@end
