//
//  LDShopListXML.h
//  LynxShopList
//
//  Created by Денис Ломанов on 05.08.14.
//  Copyright (c) 2014 Денис Ломанов. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GDataXMLNode.h"
#import "FMDatabase.h"
#import "LDAppDelegate.h"

@interface LDShopListXML : NSObject

// формирование данных XML-файла списка
+ (NSData *)createXMLDataByList:(NSString *)shopListId;

// сохранение данных в файл
+ (BOOL)saveXMLDataToFile:(NSData *)shopListData withName:(NSString *)fileName;

// формирование списка на основе данных, считаных из XML-файла
+ (NSString *)createListByXMLData:(NSData *)XMLData;

@end
