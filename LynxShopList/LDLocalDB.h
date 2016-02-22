//
//  LDLocalDB.h
//  LynxShopList
//
//  Created by Денис Ломанов on 17/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB/FMDatabase.h"
#import "FMDB/FMDatabaseAdditions.h"

@interface LDLocalDB : NSObject
{
    NSString *_dbFileName;  // имя файла локальной sqlite-базы
                            // предполагается, что база лежит в стандартном каталоге документов приложения
    
    NSString *_dbFileName_preset;   // имя файла БД по умолчанию, хранящейся в пакете приложения
                                    // этот файл будет скопирован в Documents, если там будет отсутствовать файл БД
    
    FMDatabase *_db;    // объект БД
}

- (id)initWithFileName:(NSString *)dbFileName preset:(NSString *)dbFileName_preset;
+ (LDLocalDB *)localDBWithFileName:(NSString *)dbFileName preset:(NSString *)dbFileName_preset;

- (BOOL)connect;     // подключение к БД
- (FMDatabase *)db;  // доступ к объекту БД
- (BOOL)close;       // закрытие подключения

// получение данных из таблицы VersionInfo (DeveloperEMail, VersionNumber, VersionDate)
- (NSString *)getVersionInfo:(NSString *)data;
// прописывание нового номера и даты версии
- (BOOL)setVersionInfo:(NSString *)versionNumber date:(NSString *)versionDate;

// проверка возможности удаления различных объектов
- (BOOL)canDeleteShop:(NSString *)shopId;
- (BOOL)canDeleteGoodCategory:(NSString *)categoryId;
- (BOOL)canDeleteMeasure:(NSString *)measureId;
- (BOOL)canDeleteGood:(NSString *)goodId;

// удаление записи из заданной таблицы по ключу
- (BOOL)deleteRecordByDocId:(NSString *)docId from:(NSString *)tableName;

@end
