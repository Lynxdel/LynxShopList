//
//  LDMeasuresTableViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 24/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FMDatabase.h"
#import "LDAppDelegate.h"
#import "LDRefSelectValueDelegate.h"
#import "LDMeasureEditViewController.h"

@interface LDMeasuresTableViewController : UIViewController<UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
{
    id <LDRefSelectValueDelegate> parentViewDelegate;
}

@property (strong) id parentViewDelegate;   // ссылка на view, вызвавший табличную форму в режиме справочника

@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *addButton;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *editDoneButton;
@property (weak, nonatomic) IBOutlet UITableView *tvData;

- (void)loadData:(NSString *)namesLike;     // извлечение данных из БД
- (void)setReferenceMode;                   // перевод табличной формы в режим справочника
- (void)selectMeasure;                      // выбор единицы (в режиме справочника)

- (IBAction)editListButton:(id)sender;
- (BOOL)deleteElement:(NSString *)docId;    // удаление записи

@end
