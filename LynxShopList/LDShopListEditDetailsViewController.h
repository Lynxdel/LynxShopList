//
//  LDShopListEditDetailsViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 06/06/14.
//  Copyright (c) 2014 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ECSlidingViewController.h"
#import "LDShopListEditViewController.h"
#import "MessageUI/MessageUI.h"
#import "MessageUI/MFMailComposeViewController.h"

@interface LDShopListEditDetailsViewController : UIViewController<UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate,MFMailComposeViewControllerDelegate>
{
    id parentListViewController;    // ссылка на "родительский" вью
    
    NSString *_shopId;              // идентификатор выбранного магазина
}

@property (strong, readwrite) id parentListViewController;

@property (readwrite) NSString *shopId;

@property (weak, nonatomic) IBOutlet UITextField *txtListName;
@property (weak, nonatomic) IBOutlet UITextField *txtShopName;

- (IBAction)selectShopButton:(id)sender;
- (IBAction)sendByEMailButton:(id)sender;

@property (strong, nonatomic) UITableView *tvSearchReference;   // таблица с результатами поиска магазинов

- (IBAction)shopEditingChanged:(id)sender;
- (IBAction)shopEditingDidEnd:(id)sender;

- (BOOL)saveListByParentView;   // сохранение списка с помощью вызова метода родительского view

@end
