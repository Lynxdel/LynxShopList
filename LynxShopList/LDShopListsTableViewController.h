//
//  LDShopListsTableViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 24/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LDShopListEditViewController.h"
#import "LDCellMenuItem.h"
#import "MessageUI/MessageUI.h"
#import "MessageUI/MFMailComposeViewController.h"

@interface LDShopListsTableViewController : UIViewController<UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate, MFMailComposeViewControllerDelegate>

@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@property (weak, nonatomic) IBOutlet UITableView *tvData;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (strong, nonatomic) IBOutlet UISegmentedControl *scListsFilter;
- (IBAction)scListsFilterValueChanged:(id)sender;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *editDoneButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *addButton;

- (void)loadData;                         // извлечение данных из БД

- (void)saveSectionsState;      // сохранение состояний секций (категорий)
- (void)restoreSectionsState;   // восстановление состояний секций

- (IBAction)editListButton:(id)sender;    // перевод таблицы в режим редактирования и обратно
- (BOOL)deleteList:(NSString *)docId;     // удаление списка

@end
