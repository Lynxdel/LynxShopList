//
//  LDShopListXML.m
//  LynxShopList
//
//  Created by Денис Ломанов on 05.08.14.
//  Copyright (c) 2014 Денис Ломанов. All rights reserved.
//

#import "LDShopListXML.h"

@implementation LDShopListXML

// формирование данных XML-файла списка
+ (NSData *)createXMLDataByList:(NSString *)shopListId
{
    // доступ к глобальному объекту приложения
    LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // необходимо подключение к локальной БД
    FMDatabase *db = appDelegate.localDB.db;
    
    if (db != nil)
    {
        GDataXMLElement *rootElement = [GDataXMLNode elementWithName:@"ShopList"];
        
        // заголовок
        NSString *selectList = [NSString stringWithFormat:@"SELECT   IFNULL(sl.Name, '') as ListName \
                                                                   , IFNULL(s.Name, '') as ShopName \
                                                            FROM ShopLists sl \
                                                                    LEFT JOIN REF_Shops s \
                                                                        ON s.DocId = sl.ShopId \
                                                            WHERE sl.DocId = 0%@", shopListId];

        FMResultSet *qryList = [db executeQuery:selectList];
        
        if ([qryList next])
        {
            GDataXMLElement *attName = [GDataXMLElement elementWithName:@"Name" stringValue:[qryList stringForColumn:@"ListName"]];
            GDataXMLElement *attShopName = [GDataXMLElement elementWithName:@"ShopName" stringValue:[qryList stringForColumn:@"ShopName"]];
            
            [rootElement addAttribute:attName];
            [rootElement addAttribute:attShopName];
        }
        
        [qryList close];
        
        // используемые категории
        NSString *selectGoodCategories = [NSString stringWithFormat:@"SELECT DISTINCT   cats.Name \
                                                                                      , IFNULL(cats.ColorR * 255.0, 0.0) as R \
                                                                                      , IFNULL(cats.ColorG * 255.0, 0.0) as G \
                                                                                      , IFNULL(cats.ColorB * 255.0, 0.0) as B \
                                                                                      , IFNULL(cats.ColorAlpha * 255.0, 0.0) as A \
                                                                      FROM ShopListGoods slg \
                                                                             INNER JOIN REF_Goods g \
                                                                                ON slg.GoodId = g.DocId \
                                                                             INNER JOIN REF_GoodCategories cats \
                                                                                ON cats.DocId = g.CategoryId \
                                                                      WHERE slg.ShopListId = 0%@", shopListId];

        FMResultSet *qryCategories = [db executeQuery:selectGoodCategories];
        
        GDataXMLElement *categoriesElement = [GDataXMLNode elementWithName:@"Categories"];
        
        while([qryCategories next])
        {
            GDataXMLElement *categoryElement = [GDataXMLElement elementWithName:@"Category"];
            
            GDataXMLElement *attName = [GDataXMLElement elementWithName:@"Name" stringValue:[qryCategories stringForColumn:@"Name"]];
            GDataXMLElement *attR = [GDataXMLElement elementWithName:@"R" stringValue:[qryCategories stringForColumn:@"R"]];
            GDataXMLElement *attG = [GDataXMLElement elementWithName:@"G" stringValue:[qryCategories stringForColumn:@"G"]];
            GDataXMLElement *attB = [GDataXMLElement elementWithName:@"B" stringValue:[qryCategories stringForColumn:@"B"]];
            GDataXMLElement *attA = [GDataXMLElement elementWithName:@"A" stringValue:[qryCategories stringForColumn:@"A"]];
            
            [categoryElement addAttribute:attName];
            [categoryElement addAttribute:attR];
            [categoryElement addAttribute:attG];
            [categoryElement addAttribute:attB];
            [categoryElement addAttribute:attA];
            
            [categoriesElement addChild:categoryElement];
        }
        
        [rootElement addChild:categoriesElement];
        
        [qryCategories close];
        
        // используемые единицы измерения
        NSString *selectGoodMeasures = [NSString stringWithFormat:@"SELECT DISTINCT   m.Name \
                                                                                    , IFNULL(m.Name234, '') as Name234 \
                                                                                    , IFNULL(m.Name567890, '') as Name567890 \
                                                                                    , IFNULL(m.IncQty, 0.0) as IncQty \
                                                                    FROM ShopListGoods slg \
                                                                            INNER JOIN REF_Goods g \
                                                                                ON slg.GoodId = g.DocId \
                                                                            INNER JOIN REF_Measures m \
                                                                                ON m.DocId = g.MeasureId \
                                                                    WHERE slg.ShopListId = 0%@", shopListId];

        FMResultSet *qryMeasures = [db executeQuery:selectGoodMeasures];
        
        GDataXMLElement *measuresElement = [GDataXMLNode elementWithName:@"Measures"];
        
        while([qryMeasures next])
        {
            GDataXMLElement *measureElement = [GDataXMLElement elementWithName:@"Measure"];
            
            GDataXMLElement *attName = [GDataXMLElement elementWithName:@"Name" stringValue:[qryMeasures stringForColumn:@"Name"]];
            GDataXMLElement *attName234 = [GDataXMLElement elementWithName:@"Name234" stringValue:[qryMeasures stringForColumn:@"Name234"]];
            GDataXMLElement *attName567890 = [GDataXMLElement elementWithName:@"Name567890" stringValue:[qryMeasures stringForColumn:@"Name567890"]];
            GDataXMLElement *attIncQty = [GDataXMLElement elementWithName:@"IncQty" stringValue:[qryMeasures stringForColumn:@"IncQty"]];
            
            [measureElement addAttribute:attName];
            [measureElement addAttribute:attName234];
            [measureElement addAttribute:attName567890];
            [measureElement addAttribute:attIncQty];

            [measuresElement addChild:measureElement];
        }

        [rootElement addChild:measuresElement];
        
        [qryMeasures close];

        // список товаров
        NSString *selectGoods = [NSString stringWithFormat:@"SELECT   g.Name as Name \
                                                                    , IFNULL(m.Name, '') as MeasureName \
                                                                    , IFNULL(cats.Name, '') as CategoryName \
                                                                    , IFNULL(slg.Comments, '') as Comments \
                                                                    , IFNULL(slg.Price, 0.0) as Price \
                                                                    , IFNULL(slg.Qty, 0.0) as Qty \
                                                                    , IFNULL(slg.Amount, 0.0) as Amount \
                                                             FROM ShopListGoods slg \
                                                                    INNER JOIN REF_Goods g \
                                                                        ON slg.GoodId = g.DocId \
                                                                    LEFT JOIN REF_Measures m \
                                                                        ON g.MeasureId = m.DocId \
                                                                    LEFT JOIN REF_GoodCategories cats \
                                                                        ON g.CategoryId = cats.DocId \
                                                             WHERE slg.ShopListId = 0%@ \
                                                             ORDER BY slg.DocId ", shopListId];
        
        FMResultSet *qryGoods = [db executeQuery:selectGoods];

        GDataXMLElement *goodsElement = [GDataXMLNode elementWithName:@"Goods"];
       
        while([qryGoods next])
        {
            GDataXMLElement *goodElement = [GDataXMLElement elementWithName:@"Good"];
            
            GDataXMLElement *attName = [GDataXMLElement elementWithName:@"Name" stringValue:[qryGoods stringForColumn:@"Name"]];
            GDataXMLElement *attMeasureName = [GDataXMLElement elementWithName:@"MeasureName" stringValue:[qryGoods stringForColumn:@"MeasureName"]];
            GDataXMLElement *attCategoryName = [GDataXMLElement elementWithName:@"CategoryName" stringValue:[qryGoods stringForColumn:@"CategoryName"]];
            GDataXMLElement *attComments = [GDataXMLElement elementWithName:@"Comments" stringValue:[qryGoods stringForColumn:@"Comments"]];
            GDataXMLElement *attPrice = [GDataXMLElement elementWithName:@"Price" stringValue:[qryGoods stringForColumn:@"Price"]];
            GDataXMLElement *attQty = [GDataXMLElement elementWithName:@"Qty" stringValue:[qryGoods stringForColumn:@"Qty"]];
            GDataXMLElement *attAmount = [GDataXMLElement elementWithName:@"Amount" stringValue:[qryGoods stringForColumn:@"Amount"]];
        
            [goodElement addAttribute:attName];
            [goodElement addAttribute:attMeasureName];
            [goodElement addAttribute:attCategoryName];
            [goodElement addAttribute:attComments];
            [goodElement addAttribute:attPrice];
            [goodElement addAttribute:attQty];
            [goodElement addAttribute:attAmount];
            
            [goodsElement addChild:goodElement];
        }
        
        [rootElement addChild:goodsElement];
        
        [qryGoods close];
        
        // формируем файл
        GDataXMLDocument *document = [[GDataXMLDocument alloc] initWithRootElement:rootElement];
        
        return document.XMLData;
    }
    else
    {
        return nil;
    }
}

// сохранение данных в файл
+ (BOOL)saveXMLDataToFile:(NSData *)shopListData withName:(NSString *)fileName;
{
    @try
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
        
        [shopListData writeToFile:filePath atomically:YES];

        return YES;
    }
    @catch (NSException *exception)
    {
        return NO;
    }
}

// формирование списка на основе данных, считаных из XML-файла
+ (NSString *)createListByXMLData:(NSData *)XMLData;
{
    // доступ к глобальному объекту приложения
    LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // необходимо подключение к локальной БД
    FMDatabase *db = appDelegate.localDB.db;
    
    if (db != nil)
    {
        NSError *error;
        
        GDataXMLDocument *XMLdocument = [[GDataXMLDocument alloc] initWithData:XMLData options:0 error:&error];
        
        if (XMLdocument != nil)
        {
            GDataXMLElement *rootElement = [XMLdocument rootElement];
            
            NSString *listId = @"0";
            NSString *listName = [[rootElement attributeForName:@"Name"] stringValue];
            NSString *shopName = [[rootElement attributeForName:@"ShopName"] stringValue];
            NSString *shopId = @"0";
            
            if (![shopName isEqualToString:@""])
            {
                NSString *selectShop = [NSString stringWithFormat:@"SELECT DocId \
                                                                    FROM REF_Shops \
                                                                    WHERE Name_lower = '%@'", [shopName lowercaseString]];
                
                FMResultSet *qryShop = [db executeQuery:selectShop];
            
                // магазин найден по наименованию
                if ([qryShop next])
                {
                    shopId = [qryShop stringForColumn:@"DocId"];
                }
                // магазин придется создать
                else
                {
                    NSDictionary *shopArgsDict = [NSDictionary dictionaryWithObjectsAndKeys:shopName, @"Name", [shopName lowercaseString], @"Name_lower", [NSDate date],    @"CreateDate", nil];
                
                    if ([db executeUpdate:@"INSERT INTO REF_Shops (Name, Name_lower, CreateDate) \
                                            VALUES (:Name, :Name_lower, :CreateDate)" withParameterDictionary:shopArgsDict])
                    {
                        // теперь нужно определить новый DocId
                        FMResultSet *shopId_result = [db executeQuery:@"SELECT last_insert_rowid() as NewDocId"];
                    
                        if ([shopId_result next])
                        {
                            shopId = [shopId_result stringForColumn:@"NewDocId"];
                        }
                    
                        [shopId_result close];
                    }
                }
            }
            
            NSMutableDictionary *shopListArgsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:listName, @"Name",
                                                                                    [listName lowercaseString], @"Name_lower",
                                                                                                        shopId, @"ShopId",
                                                                                  [NSNumber numberWithBool:NO], @"SortAZ",
                                                                                 [NSNumber numberWithBool:YES], @"Active",
                                                                                                 [NSDate date], @"ShoppingDate",
                                                                                                 [NSDate date], @"CreateDate", nil];
            
            [db executeUpdate:@"INSERT INTO ShopLists (Name, Name_lower, ShopId, SortAZ, Active, ShoppingDate, CreateDate) \
                                VALUES (:Name, :Name_lower, :ShopId, :SortAZ, :Active, :ShoppingDate, :CreateDate)" withParameterDictionary:shopListArgsDict];
            
            // теперь нужно определить новый DocId
            FMResultSet *shopListId_result = [db executeQuery:@"SELECT last_insert_rowid() as NewDocId"];
            
            if ([shopListId_result next])
            {
                listId = [shopListId_result stringForColumn:@"NewDocId"];
            
                [shopListId_result close];
                
                // используемые Категории
                NSArray *categories = [rootElement elementsForName:@"Categories"];
                
                if ([categories count] == 1)
                {
                    GDataXMLElement *categoriesElement = (GDataXMLElement *)[categories objectAtIndex:0];
                
                    NSArray *categoriesElements = [categoriesElement elementsForName:@"Category"];
                
                    for (int i = 0; i < [categoriesElements count]; i++)
                    {
                        GDataXMLElement *category = (GDataXMLElement *)[categoriesElements objectAtIndex:i];
                    
                        NSString *categoryName = [[category attributeForName:@"Name"] stringValue];
                        NSString *categoryName_lower = [categoryName lowercaseString];
                    
                        FMResultSet *qryCats = [db executeQuery:[NSString stringWithFormat:@"SELECT DocId FROM REF_GoodCategories WHERE Name_lower = '%@'", categoryName_lower]];
                    
                        // категория не найдена - добавляем
                        if (![qryCats next])
                        {
                            double r = [[[category attributeForName:@"R"] stringValue] doubleValue] / 255.0;
                            double g = [[[category attributeForName:@"G"] stringValue] doubleValue] / 255.0;
                            double b = [[[category attributeForName:@"B"] stringValue] doubleValue] / 255.0;
                            double a = [[[category attributeForName:@"A"] stringValue] doubleValue] / 255.0;
                        
                            NSDictionary *catArgsDict = [NSDictionary dictionaryWithObjectsAndKeys:categoryName, @"Name",
                                                                                             categoryName_lower, @"Name_lower",
                                                                                  [NSNumber numberWithDouble:r], @"ColorR",
                                                                                  [NSNumber numberWithDouble:g], @"ColorG",
                                                                                  [NSNumber numberWithDouble:b], @"ColorB",
                                                                                  [NSNumber numberWithDouble:a], @"ColorAlpha",
                                                                                                  [NSDate date], @"CreateDate", nil];
                        
                            [db executeUpdate:@"INSERT INTO REF_GoodCategories (Name, Name_lower, ColorR, ColorG, ColorB, ColorAlpha, CreateDate) \
                                                VALUES (:Name, :Name_lower, :ColorR, :ColorG, :ColorB, :ColorAlpha, :CreateDate)" withParameterDictionary:catArgsDict];
                        
                        }
                    
                        [qryCats close];
                    }
                }
                
                // используемые Единицы измерения
                NSArray *measures = [rootElement elementsForName:@"Measures"];
                
                if ([measures count] == 1)
                {
                    GDataXMLElement *measuresElement = (GDataXMLElement *)[measures objectAtIndex:0];
                
                    NSArray *measuresElements = [measuresElement elementsForName:@"Measure"];
                
                    for (int i = 0; i < [measuresElements count]; i++)
                    {
                        GDataXMLElement *measure = (GDataXMLElement *)[measuresElements objectAtIndex:i];

                        NSString *measureName = [[measure attributeForName:@"Name"] stringValue];
                        NSString *measureName_lower = [measureName lowercaseString];
                    
                        FMResultSet *qryMeasures = [db executeQuery:[NSString stringWithFormat:@"SELECT DocId FROM REF_Measures WHERE Name_lower = '%@'", measureName_lower]];
                    
                        // категория не найдена - добавляем
                        if (![qryMeasures next])
                        {
                            NSString *name234 = [[measure attributeForName:@"Name234"] stringValue];
                            NSString *name567890 = [[measure attributeForName:@"Name567890"] stringValue];
                            double incQty = [[[measure attributeForName:@"IncQty"] stringValue] doubleValue];
                        
                            NSDictionary *measureArgsDict = [NSDictionary dictionaryWithObjectsAndKeys:measureName, @"Name",
                                                                                                 measureName_lower, @"Name_lower",
                                                                                                           name234, @"Name234",
                                                                                                        name567890, @"Name567890",
                                                                                [NSNumber numberWithDouble:incQty], @"IncQty",
                                                                                                     [NSDate date], @"CreateDate", nil];
                        
                            [db executeUpdate:@"INSERT INTO REF_Measures (Name, Name_lower, Name234, Name567890, IncQty, CreateDate) \
                                                VALUES (:Name, :Name_lower, :Name234, :Name567890, :IncQty, :CreateDate)" withParameterDictionary:measureArgsDict];
                        }
                    
                        [qryMeasures close];
                    }
                }
                
                // список товаров
                NSArray *goods = [rootElement elementsForName:@"Goods"];
                
                if ([goods count] == 1)
                {
                    GDataXMLElement *goodsElement = (GDataXMLElement *)[goods objectAtIndex:0];
                    
                    NSArray *goodsElements = [goodsElement elementsForName:@"Good"];
                    
                    for (int i = 0; i < [goodsElements count]; i++)
                    {
                        GDataXMLElement *good = (GDataXMLElement *)[goodsElements objectAtIndex:i];
                        
                        NSString *goodName = [[good attributeForName:@"Name"] stringValue];
                        NSString *goodName_lower = [goodName lowercaseString];
                        NSString *goodId = @"0";
                        NSString *categoryName = [[good attributeForName:@"CategoryName"] stringValue];
                        NSString *categoryName_lower = [categoryName lowercaseString];
                        NSString *categoryId = @"0";
                        NSString *measureName = [[good attributeForName:@"MeasureName"] stringValue];
                        NSString *measureName_lower = [measureName lowercaseString];
                        NSString *measureId = @"0";
                        
                        // определяем категорию
                        FMResultSet *qryCats = [db executeQuery:[NSString stringWithFormat:@"SELECT DocId FROM REF_GoodCategories WHERE Name_lower = '%@'", categoryName_lower]];

                        if ([qryCats next]) categoryId = [qryCats stringForColumn:@"DocId"];
                        
                        [qryCats close];
                        
                        // определяем единицу измерения
                        FMResultSet *qryMeasures = [db executeQuery:[NSString stringWithFormat:@"SELECT DocId FROM REF_Measures WHERE Name_lower = '%@'", measureName_lower]];
                        
                        if ([qryMeasures next]) measureId = [qryMeasures stringForColumn:@"DocId"];
                        
                        [qryMeasures close];
                        
                        // ищем товар по наименованию, категории и единице измерения
                        FMResultSet *qryGoods = [db executeQuery:[NSString stringWithFormat:@"SELECT g.DocId \
                                                                                              FROM REF_Goods g \
                                                                                                     LEFT JOIN REF_GoodCategories cats \
                                                                                                       ON g.CategoryId = cats.DocId \
                                                                                                     LEFT JOIN REF_Measures m \
                                                                                                       ON g.MeasureId = m.DocId \
                                                                                              WHERE      (g.Name_lower = '%@') \
                                                                                                    and ((IFNULL(cats.Name, '') = '') or (cats.Name_lower = '%@')) \
                                                                                                    and ((IFNULL(m.Name, '') = '') or (m.Name_lower = '%@'))",
                                                                                              goodName_lower, categoryName_lower, measureName_lower]];
                        
                        // товар не найден - добавляем
                        if (![qryGoods next])
                        {
                            NSMutableDictionary *goodArgsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:goodName, @"Name",
                                                                                                            goodName_lower, @"Name_lower",
                                                                                                                categoryId, @"CategoryId",
                                                                                                                 measureId, @"MeasureId",
                                                                                                             [NSDate date], @"CreateDate", nil];
                            
                            if ([db executeUpdate:@"INSERT INTO REF_Goods (Name, Name_lower, CategoryId, MeasureId, CreateDate) \
                                                    VALUES (:Name, :Name_lower, :CategoryId, :MeasureId, :CreateDate)" withParameterDictionary:goodArgsDict])
                            {
                                // узнаем код нового товара
                                FMResultSet *goodId_result = [db executeQuery:@"SELECT last_insert_rowid() as NewDocId"];
                                
                                if ([goodId_result next])
                                {
                                    goodId = [goodId_result stringForColumn:@"NewDocId"];
                                }
                                
                                [goodId_result close];
                            }
                        }
                        // товар уже присутствует в таблице, его код определен по наименованию
                        else
                        {
                            goodId = [qryGoods stringForColumn:@"DocId"];
                        }
                        
                        [qryGoods close];
                        
                        // добавляем товар в список
                        NSString *goodComments = [[good attributeForName:@"Comments"] stringValue];
                        double goodPrice = [[[good attributeForName:@"Price"] stringValue] doubleValue];
                        double goodQty = [[[good attributeForName:@"Qty"] stringValue] doubleValue];
                        double goodAmount = [[[good attributeForName:@"Amount"] stringValue] doubleValue];

                        // добавляем запись в ShopListGoods
                        NSDictionary *shopListGoodArgsDict = [NSDictionary dictionaryWithObjectsAndKeys:listId, @"ShopListId",
                                                                                                        goodId, @"GoodId",
                                                                         [NSNumber numberWithDouble:goodPrice], @"Price",
                                                                           [NSNumber numberWithDouble:goodQty], @"Qty",
                                                                        [NSNumber numberWithDouble:goodAmount], @"Amount",
                                                                                                  goodComments, @"Comments",
                                                                                                 [NSDate date], @"CreateDate", nil];
                        
                        [db executeUpdate:@"INSERT INTO ShopListGoods (ShopListId, GoodId, Price, Qty, Amount, Comments, CreateDate) \
                                            VALUES (:ShopListId, :GoodId, :Price, :Qty, :Amount, :Comments, :CreateDate)" withParameterDictionary:shopListGoodArgsDict];
                    }
                }
                
                return listId;
            }
            else
            {
                [shopListId_result close];
                
                return @"0";
            }
        }
        else
        {
            return @"0";
        }
    }
    else
    {
        return @"0";
    }
}

@end
