//
//  LDLocalDB.m
//  LynxShopList
//
//  Created by Денис Ломанов on 17/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDLocalDB.h"

@implementation LDLocalDB

- (id)initWithFileName:(NSString *)dbFileName preset:(NSString *)dbFileName_preset
{
    if (self = [super init])
    {
        _dbFileName = dbFileName;
        _dbFileName_preset = dbFileName_preset;
    }
    
    return self;
}

+ (LDLocalDB *)localDBWithFileName:(NSString *)dbFileName preset:(NSString *)dbFileName_preset
{
    return [[LDLocalDB alloc] initWithFileName:dbFileName preset:dbFileName_preset];
}

// подключение к БД
- (BOOL)connect
{
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = [dirPaths objectAtIndex:0];
    
    // путь к файлу БД в Documents
    NSString *localDBPath = [[NSString alloc] initWithString:[docsDir stringByAppendingPathComponent: _dbFileName]];
    
    NSFileManager *filemgr = [NSFileManager defaultManager];
    
    // базы нет в Documents - копируем из ресурсов заготовленный файл БД по умолчанию
    if (![filemgr fileExistsAtPath:localDBPath])
    {
        // определяем путь к файлу БД по умолчанию в пакете приложения
        NSString *defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:_dbFileName_preset];
        
        NSError *error;
        // копируем файл из пакета приложения в Documents
        BOOL success = [filemgr copyItemAtPath:defaultDBPath toPath:localDBPath error:&error];
        
        // скопировали - открываем
        if (success)
        {
            _db = [FMDatabase databaseWithPath:localDBPath];
            
            return [_db open];
        }
        else return NO;
    }
    // база есть в Documents - открываем ее
    else
    {
        _db = [FMDatabase databaseWithPath:localDBPath];
    
        return [_db open];
    }
}

// доступ к объекту БД
- (FMDatabase *)db
{
    return _db;
}

// закрытие подключения
- (BOOL)close
{
    if (_db != nil)
    {
        BOOL result = [_db close];
        
        _db = nil;
        
        return result;
    }
    else return YES;
}

/////////////////////////////////////////////////
// Процедуры проверки версии и актуализации БД //
/////////////////////////////////////////////////

// получение данных из таблицы VersionInfo (DeveloperEMail, VersionNumber, VersionDate)
- (NSString *)getVersionInfo:(NSString *)data
{
    FMResultSet *qry = [self.db executeQuery:[NSString stringWithFormat:@"SELECT %@ FROM VersionInfo", data]];
    
    NSString *result = @"";
    
    if ([qry next])
    {
        result = [qry stringForColumn:data];
    }
    
    [qry close];
    
    return result;
}

// прописывание нового номера и даты версии
- (BOOL)setVersionInfo:(NSString *)versionNumber date:(NSString *)versionDate
{
    return [self.db executeUpdate:[NSString stringWithFormat:@"UPDATE VersionInfo \
                                                               SET   VersionNumber = %@ \
                                                                   , VersionDate = '%@'", versionNumber, versionDate]];
}

// обновление версии с 1.0 до 2.0
// возвращаемое значение - признак применения апдейта
- (BOOL)applyVersionUpdate_12
{
    BOOL result = NO;
    
    double versionNumber = [[self getVersionInfo:@"VersionNumber"] doubleValue];
    
    if (versionNumber == 1.0)
    {
        result = YES;   // обновление необходимо и в случае отсутствия исключений проведено
        
        // при переходе с 1.0 к 2.0 добавляем:
        // - поле примечаний к спискам
        // - дату отправки списка по e-mail
        // - признак принятия списка по e-mail
        
        // примечания
        if (![_db columnExists:@"Comments" inTableWithName:@"ShopLists"])
        {
            [_db executeUpdate:@"ALTER TABLE ShopLists ADD COLUMN Comments TEXT"];
        }
        
        // ...
        
        
        // прописываем версию
        [self setVersionInfo:@"2.0" date:@"01.09.2014"];
    }
    
    return result;
}

///////////////////////////////////////////////
// Процедуры взаимодействия со справочниками //
///////////////////////////////////////////////

// проверка возможности удаления различных объектов
- (BOOL)canDeleteShop:(NSString *)shopId
{
    BOOL result = NO;
    
    FMResultSet *qry = [self.db executeQuery:@"SELECT COUNT(*) as Cnt FROM ShopLists WHERE ShopId = ?", shopId, nil];
    
    if ([qry next])
    {
        int rowCount = [qry intForColumn:@"Cnt"];
        
        result = (rowCount == 0);
    }
    
    [qry close];
    
    return result;
}

- (BOOL)canDeleteGoodCategory:(NSString *)categoryId
{
    BOOL result = NO;
    
    FMResultSet *qry = [self.db executeQuery:@"SELECT COUNT(*) as Cnt FROM REF_Goods WHERE CategoryId = ?", categoryId, nil];
    
    if ([qry next])
    {
        int rowCount = [qry intForColumn:@"Cnt"];
        
        result = (rowCount == 0);
    }
    
    [qry close];
    
    return result;
}

- (BOOL)canDeleteMeasure:(NSString *)measureId
{
    BOOL result = NO;
    
    FMResultSet *qry = [self.db executeQuery:@"SELECT COUNT(*) as Cnt FROM REF_Goods WHERE MeasureId = ?", measureId, nil];
    
    if ([qry next])
    {
        int rowCount = [qry intForColumn:@"Cnt"];
        
        result = (rowCount == 0);
    }
    
    [qry close];
    
    return result;
}

- (BOOL)canDeleteGood:(NSString *)goodId
{
    BOOL result = NO;
    
    FMResultSet *qry = [self.db executeQuery:@"SELECT COUNT(*) as Cnt FROM ShopListGoods WHERE GoodId = ?", goodId, nil];
    
    if ([qry next])
    {
        int rowCount = [qry intForColumn:@"Cnt"];
        
        result = (rowCount == 0);
    }
    
    [qry close];
    
    return result;
}

// удаление записи из заданной таблицы по ключу
- (BOOL)deleteRecordByDocId:(NSString *)docId from:(NSString *)tableName
{
    return [self.db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE DocId = ?", tableName], docId, nil];
}

@end
