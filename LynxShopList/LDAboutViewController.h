//
//  LDAboutViewController.h
//  LynxShopList
//
//  Created by Денис Ломанов on 04/04/14.
//  Copyright (c) 2014 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FMDatabase.h"
#import "LDAppDelegate.h"
#import "MessageUI/MessageUI.h"
#import "MessageUI/MFMailComposeViewController.h"

@interface LDAboutViewController : UIViewController<MFMailComposeViewControllerDelegate>

@property (strong, nonatomic) IBOutlet UILabel *txtVersion;

- (void)loadData;   // загрузка данных из БД

- (IBAction)MailToDeveloperButton:(id)sender;   // отправка почты разработчику


@end
