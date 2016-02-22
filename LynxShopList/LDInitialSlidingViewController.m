//
//  LDInitialSlidingViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 06/06/14.
//  Copyright (c) 2014 Денис Ломанов. All rights reserved.
//

#import "LDInitialSlidingViewController.h"

@implementation LDInitialSlidingViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        self.shouldAdjustChildViewHeightForStatusBar = YES;
        self.statusBarBackgroundView.backgroundColor = [UIColor blackColor];
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    self.topViewController = [storyboard instantiateViewControllerWithIdentifier:@"TabBarRootController"];
    
    self.shouldAddPanGestureRecognizerToTopViewSnapshot = YES;
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

///////////////////////////////
// вспомогательные процедуры //
///////////////////////////////

// открытие импортированного из файла списка
- (void)openImportedList:(NSString *)listId
{
    UITabBarController *tabBarController = (UITabBarController *)self.topViewController;
    
    // нам нужна таблица списков, этот контроллер первый
    int tabBarIndex = [tabBarController selectedIndex];
    
    if (tabBarIndex != 0)
    {
        [tabBarController setSelectedIndex:0];
        tabBarIndex = 0;
    }
    
    UINavigationController *navController = (UINavigationController *)[[tabBarController viewControllers] objectAtIndex:tabBarIndex];
    
    LDShopListsTableViewController *listsTableController = (LDShopListsTableViewController *)[[navController viewControllers] objectAtIndex:0];
    
    [listsTableController performSegueWithIdentifier:@"newListSegue" sender:listsTableController];
}

@end
