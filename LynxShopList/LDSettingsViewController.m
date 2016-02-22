//
//  LDSettingsViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 16/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDSettingsViewController.h"

@interface LDSettingsViewController ()

@end

@implementation LDSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // загрузка настроек
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    [self.switchHideBought setOn:[defaults boolForKey:@"HideBought"]];
    
    [self.switchBoughtAtBottom setOn:[defaults boolForKey:@"BoughtAtBottom"]];
    
    [self.switchCategoriesInLists setOn:[defaults boolForKey:@"CategoriesInLists"]];
    
    NSString *goodCellView = [defaults stringForKey:@"GoodCellView"];
    
    if ([goodCellView isEqualToString:@"simple"])
    {
        [self.scGoodCellView setSelectedSegmentIndex:0];
    }
    else
        if ([goodCellView isEqualToString:@"full"])
        {
            [self.scGoodCellView setSelectedSegmentIndex:1];
        }
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    // показываем нижнюю панель
    [self.tabBarController.tabBar setHidden:NO];
    
    // скрываем верхнюю
    [self.navigationController.navigationBar setHidden:YES];
}

// скрывать по умолчанию купленные товары в списках покупок
- (IBAction)switchHideBoughtValueChanged:(id)sender
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setBool:self.switchHideBought.isOn forKey:@"HideBought"];
    
    if (![defaults synchronize])
    {
        UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Внимание"
                                                      message:@"При сохранении настроек возникла ошибка"
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
        [err show];
    }
}

// перемещать отмеченные товары в нижнюю часть списка
- (IBAction)switchBoughtAtBottomValueChanged:(id)sender
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setBool:self.switchBoughtAtBottom.isOn forKey:@"BoughtAtBottom"];
    
    if (![defaults synchronize])
    {
        UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Внимание"
                                                      message:@"При сохранении настроек возникла ошибка"
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
        [err show];
    }
}

// разделение товаров по категориям в списках
- (IBAction)switchCategoriesInListsValueChanged:(id)sender
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setBool:self.switchCategoriesInLists.isOn forKey:@"CategoriesInLists"];
    
    if (![defaults synchronize])
    {
        UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Внимание"
                                                      message:@"При сохранении настроек возникла ошибка"
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
        [err show];
    }
}

// изменение отображения строк списков
- (IBAction)scGoodCellViewValueChanged:(id)sender
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    switch (self.scGoodCellView.selectedSegmentIndex)
    {
        case 0: [defaults setValue:@"simple" forKey:@"GoodCellView"]; break;
        case 1: [defaults setValue:@"full" forKey:@"GoodCellView"]; break;
    }
    
    if (![defaults synchronize])
    {
        UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Внимание"
                                                      message:@"При сохранении настроек возникла ошибка"
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
        [err show];
    }
}

@end
