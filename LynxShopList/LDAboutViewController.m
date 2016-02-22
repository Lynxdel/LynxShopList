//
//  LDAboutViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 04/04/14.
//  Copyright (c) 2014 Денис Ломанов. All rights reserved.
//

#import "LDAboutViewController.h"

@interface LDAboutViewController ()
{
    NSString *_versionNumber;
    NSString *_versionDate;
    NSString *_developerEMail;
}

@end

@implementation LDAboutViewController

// загрузка данных из БД
- (void)loadData
{
    @try
    {
        // доступ к глобальному объекту приложения
        LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        // необходимо подключение к локальной БД
        //FMDatabase *db = appDelegate.localDB.db;
        
        _versionNumber = [appDelegate.localDB getVersionInfo:@"VersionNumber"];
        _versionDate = [appDelegate.localDB getVersionInfo:@"VersionDate"];
        _developerEMail = [appDelegate.localDB getVersionInfo:@"DeveloperEMail"];
    }
    @catch (NSException *exc)
    {

    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _versionNumber = @"1.0";
    _versionDate = @"04.04.2014";
    _developerEMail = @"lynxdel@icloud.com";
    
    [self loadData];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    // прячем нижнюю панель
    [self.tabBarController.tabBar setHidden:YES];
    
    // показываем верхнюю
    [self.navigationController.navigationBar setHidden:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    self.txtVersion.text = [NSString stringWithFormat:@"Версия %@ от %@", _versionNumber, _versionDate];
}

// письмо разработчику
- (IBAction)MailToDeveloperButton:(id)sender
{
    MFMailComposeViewController *composer = [[MFMailComposeViewController alloc] init];
    [composer setMailComposeDelegate:self];
    
    if ([MFMailComposeViewController canSendMail])
    {
        [composer setToRecipients:[NSArray arrayWithObjects:_developerEMail, nil]];
        [composer setSubject:@"Список покупок (LynxShopList)"];
        
        [composer setMessageBody:@"" isHTML:NO];
        [composer setModalTransitionStyle:UIModalTransitionStyleCrossDissolve];
        
        [self presentViewController:composer animated:YES completion:nil];
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    if (result == MFMailComposeResultSent)
    {
        UIAlertView *info = [[UIAlertView alloc] initWithTitle:@""
                                                       message:@"Письмо успешно отправлено"
                                                      delegate:self
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil, nil];
        [info show];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
