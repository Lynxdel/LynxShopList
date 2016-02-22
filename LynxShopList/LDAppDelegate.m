//
//  LDAppDelegate.m
//  LynxShopList
//
//  Created by Денис Ломанов on 16/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDAppDelegate.h"

@implementation LDAppDelegate

// https://sites.google.com/site/lynxdelcheckbuy/
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _importedListId = @"0";
    
    // регистрируем настройки по умолчанию
    NSMutableDictionary *defaultValues = [[NSMutableDictionary alloc] init];
    
    // высота строк
    [defaultValues setObject:[NSNumber numberWithDouble:44.0] forKey:@"GridRowHeight"];
    // высота секций 
    [defaultValues setObject:[NSNumber numberWithDouble:44.0] forKey:@"GridSectionHeight"];
    // базовый размер шрифта
    [defaultValues setObject:[NSNumber numberWithDouble:13.0] forKey:@"GridFontSize"];
    // скрывать купленные товары в списках покупок
    [defaultValues setObject:[NSNumber numberWithBool:NO] forKey:@"HideBought"];
    // перемещать купленные товары в нижнюю часть списка
    [defaultValues setObject:[NSNumber numberWithBool:NO] forKey:@"BoughtAtBottom"];
    // разделение товаров по категориям в списках
    [defaultValues setObject:[NSNumber numberWithBool:YES] forKey:@"CategoriesInLists"];
    // отображение строк списков
    [defaultValues setObject:@"full" forKey:@"GoodCellView"];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
    
    // обработка открытия lsl-файла со списком
//    NSURL *url = (NSURL *)[launchOptions valueForKey:UIApplicationLaunchOptionsURLKey];
//    
//    if ((url != nil) && [url isFileURL])
//    {
//        if ([self connectLocalDB])
//        {
//            // формируем список из файла
//            _importedListId = [self importListFromXML:url];
//        
//            if (![_importedListId isEqualToString:@"0"])
//            {
//                LDInitialSlidingViewController *rootController = (LDInitialSlidingViewController *)self.window.rootViewController;
//         
//                [rootController openImportedList:_importedListId];
//            }
//        }
//    }
    
    return YES;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    if ((url != nil) && [url isFileURL])
    {
        //if ([_importedListId isEqualToString:@"0"])
        //{
            if ([self connectLocalDB])
            {
                // формируем список из файла
                _importedListId = [self importListFromXML:url];
        
                if (![_importedListId isEqualToString:@"0"])
                {
                    LDInitialSlidingViewController *rootController = (LDInitialSlidingViewController *)self.window.rootViewController;

                    [rootController openImportedList:_importedListId];
                }
            }
        //}
    }
    
    return YES;
}

// приложение перешло в неактивное состояние - закрываем подключение к локальной БД
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    // закрываем подключение к локальной БД
    if (self.localDB != nil)
    {
        [self.localDB close];
    }
}

// переход приложения в активное состояние - восстанавливаем подключение к локальной БД
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    if (![self connectLocalDB])
    {
        UIAlertView *err = [[UIAlertView alloc] initWithTitle:nil
                                                      message:@"Не удалось подключиться к БД"
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
        [err show];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

///////////////////////////////
// вспомогательные процедуры //
///////////////////////////////

// подключение к SQLite-базе
- (BOOL)connectLocalDB
{
    BOOL result = NO;
    
    if (self.localDB == nil)
    {
        self.localDB = [LDLocalDB localDBWithFileName:@"LynxShopDB.sqlite" preset:@"LynxShopDB_preset.sqlite"];
    }
    
    if (self.localDB.db == nil)
    {
        result = [self.localDB connect];
    }
    else result = YES;
    
    return result;
}

// импорт списка из файла по ссылке
- (NSString *)importListFromXML:(NSURL *)importURL
{
    NSData *xmlData = [NSData dataWithContentsOfURL:importURL];
    
    return [LDShopListXML createListByXMLData:xmlData];
}

@end
