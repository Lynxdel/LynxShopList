//
//  LDAppDelegate.h
//  LynxShopList
//
//  Created by Денис Ломанов on 16/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LDLocalDB.h"
#import "LDShopListXML.h"
#import "LDInitialSlidingViewController.h"

@interface LDAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) LDLocalDB *localDB;  // "глобальный" объект подключения к локальной БД

@property (strong, nonatomic) NSString *importedListId; // ключ нового списка, импортированного из файла


- (BOOL)connectLocalDB; // подключение к SQLite-базе

- (NSString *)importListFromXML:(NSURL *)importURL;     // импорт списка из файла по ссылке

@end
