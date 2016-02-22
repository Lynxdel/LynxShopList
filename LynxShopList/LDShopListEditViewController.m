//
//  LDShopListEditViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 24/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDShopListEditViewController.h"

@interface LDShopListEditViewController ()
{
    NSMutableArray *_listData;          // список товаров (с категориями)
    NSMutableArray *_sectionsState;     // состояние секций - свернуты/развернуты
    
    double _gridSectionHeight;  // настройки внешнего вида списка
    double _gridRowHeight;
    double _gridFontSize;
    
    BOOL _isBusy;               // флаг текущей обработки данных
    
    BOOL _boughtItemsHidden;    // сокрытие купленных позиций, показываются и скрываются они с помощью жеста встряхивания
    BOOL _boughtItemsAtBottom;  // купленные позиции попадают вниз списка
    BOOL _sortListAZ;           // флаг сортировки, YES - сортировка по наименованию, NO - по порядку дополнения
    BOOL _showCategories;       // выводить категории в списке
    
    NSString *_cellViewType;    // отображение строк - простое ("simple") или полное ("full")
    
    BOOL _addGoodByCategory;        // флаг добавления товаров с фильтрацией категории
    NSString *_filterCategoryId;    // код категории для фильтрации товаров при добавлении
    
    BOOL _openDetailsView;      // флаг необходиомсти открытия втью деталей списка
    
    CGPoint _tableOffset;       // переменная для сохранения смещения таблицы при уходе с формы
}

@end

@implementation LDShopListEditViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // смахивание влево и вправо - отметка о покупке товара
    UISwipeGestureRecognizer *swprLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeHorizontal:)];
    swprLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    swprLeft.delegate = self;
    [self.tvList addGestureRecognizer:swprLeft];
    
    UISwipeGestureRecognizer *swprRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeHorizontal:)];
    swprRight.direction = UISwipeGestureRecognizerDirectionRight;
    swprRight.delegate = self;
    [self.tvList addGestureRecognizer:swprRight];
    
    // двойной тап по таблице - открытие таблицы товаров для добавления в список
    UITapGestureRecognizer *dblTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    dblTap.numberOfTapsRequired = 2;
    [self.tvList addGestureRecognizer:dblTap];
    
    _isBusy = NO;
    
    // создаем индикатор, он невидим
    self.spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake((self.view.frame.size.width - 30.0) / 2.0, (self.view.frame.size.height - 30.0) / 2.0, 30, 30)];
    [self.spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:self.spinner];
    
    [self.navigationItem setTitle:@""];
    
    _openDetailsView = NO;
    _tableOffset = CGPointMake(0.0f, 0.0f);
    
    // проверяем, не нужно ли открыть загруженный список
    LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];

    if (![appDelegate.importedListId isEqualToString:@"0"])
    {
        [self setEditListMode:appDelegate.importedListId];
        
        // сбрасываем код импортированного списка
        [appDelegate setImportedListId:@"0"];
        
        UIAlertView *info = [[UIAlertView alloc] initWithTitle:nil
                                                       message:@"Список успешно импортирован"
                                                      delegate:nil
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
        [info show];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [self becomeFirstResponder];
    
    [super viewWillAppear:animated];
    
    // прячем нижнюю панель
    [self.tabBarController.tabBar setHidden:YES];
    
    // показываем верхнюю
    [self.navigationController.navigationBar setHidden:NO];
    
    // тянем настройки
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    _gridSectionHeight = [[defaults stringForKey:@"GridSectionHeight"] doubleValue];
    
    _gridRowHeight = [[defaults stringForKey:@"GridRowHeight"] doubleValue];
    _gridFontSize = [[defaults stringForKey:@"GridFontSize"] doubleValue];
    
    _boughtItemsHidden = [defaults boolForKey:@"HideBought"];
    _boughtItemsAtBottom = [defaults boolForKey:@"BoughtAtBottom"];
    
    _showCategories = [defaults boolForKey:@"CategoriesInLists"];
    
    _cellViewType = [defaults stringForKey:@"GoodCellView"];
    
    // разделитель строк в списке убираем
    self.tvList.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    // цвет кнопки сортировки
    [self setSortButtonTintColor];
    
    self.viewFooter.layer.borderColor = [[UIColor colorWithRed:0.95f green:0.95f blue:0.95f alpha:1.0f] CGColor];
    self.viewFooter.layer.borderWidth = 0.5f;
    
    // удаляем товары, для которых количество стало нулевым (после редактирования через форму деталей)
    [self deleteGoodsWithZeroQty];
    
    [self loadListData];
    
    // восстанавливаем состояния секций
    [self restoreSectionsState];
    
    [self.tvList reloadData];
    
    // создаем вью с заголовочными данными списка, который будет появляться справа
    LDShopListEditDetailsViewController *detailsController = (LDShopListEditDetailsViewController *)[self.storyboard instantiateViewControllerWithIdentifier:@"ShopListEditDetailsView"];
    detailsController.parentListViewController = self;
    self.slidingViewController.underRightViewController = detailsController;
    
    // восстанавливаем смещение по вертикали
    self.tvList.contentOffset = _tableOffset;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // необходимо открыть вью деталей списка (произошел, например, выбор магазина из списка)
    if (_openDetailsView)
    {
        [self.slidingViewController anchorTopViewTo:ECLeft];
        
        _openDetailsView = NO;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self resignFirstResponder];
    
    [super viewWillDisappear:animated];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

// сохранение записи
- (BOOL)saveList:(BOOL)shouldCloseView
{
    BOOL result = NO;
    
    // не допускаем повторного запуска процесса
    if (!_isBusy)
    {
        [NSThread detachNewThreadSelector:@selector(threadStartSpinning:) toTarget:self withObject:nil];
    }
    
    _isBusy = YES;
    
    @try
    {
        // доступ к глобальному объекту приложения
        LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        // необходимо подключение к локальной БД
        FMDatabase *db = appDelegate.localDB.db;
        
        if (db != nil)
        {
            NSMutableDictionary *argsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:_listName, @"Name",
                                                                            [_listName lowercaseString], @"Name_lower",
                                                                                                _shopId, @"ShopId",
                                                                  [NSNumber numberWithBool:_sortListAZ], @"SortAZ", nil];
            
            // новая запись - INSERT
            if ([_docId isEqualToString:@"0"])
            {
                [argsDict setObject:[NSNumber numberWithBool:YES] forKey:@"Active"];
                [argsDict setObject:[NSDate date] forKey:@"ShoppingDate"];
                [argsDict setObject:[NSDate date] forKey:@"CreateDate"];
                
                [db executeUpdate:@"INSERT INTO ShopLists (Name, Name_lower, ShopId, SortAZ, Active, ShoppingDate, CreateDate) \
                                    VALUES (:Name, :Name_lower, :ShopId, :SortAZ, :Active, :ShoppingDate, :CreateDate)" withParameterDictionary:argsDict];
                
                // теперь нужно определить новый DocId
                FMResultSet *docId_result = [db executeQuery:@"SELECT last_insert_rowid() as NewDocId"];
                
                if ([docId_result next])
                {
                    _docId = [docId_result stringForColumn:@"NewDocId"];
                    result = YES;
                }
                
                [docId_result close];
            }
            // существующая - UPDATE
            else
            {
                // проверяем, все ли товары отмечены, если все отмечены - снимаем флаг активности
                _active = ![self checkAllGoodsBought];
                
                [argsDict setObject:[NSNumber numberWithBool:_active] forKey:@"Active"];
                [argsDict setObject:[NSDate date] forKey:@"EditDate"];
                [argsDict setObject:_docId forKey:@"DocId"];
                
                result = [db executeUpdate:@"UPDATE ShopLists \
                                             SET   Name = :Name \
                                                 , Name_lower = :Name_lower \
                                                 , ShopId = :ShopId \
                                                 , SortAZ = :SortAZ \
                                                 , Active = :Active \
                                                 , EditDate = :EditDate \
                                             WHERE DocId = :DocId" withParameterDictionary:argsDict];
            }
            
            // все в порядке возвращаемся в список при необходимости
            if (result)
            {
                if (shouldCloseView)
                {
                    [self.navigationController popViewControllerAnimated:YES];
                }
            }
            else
            {
                UIAlertView *info = [[UIAlertView alloc] initWithTitle:@"Не удалось сохранить данные"
                                                               message:[db lastErrorMessage]
                                                              delegate:nil
                                                     cancelButtonTitle:@"OK"
                                                     otherButtonTitles:nil];
                [info show];
            }
        }
        else
        {
            UIAlertView *info = [[UIAlertView alloc] initWithTitle:@"Не удалось сохранить данные"
                                                           message:[db lastErrorMessage]
                                                          delegate:nil
                                                 cancelButtonTitle:@"OK"
                                                 otherButtonTitles:nil];
            [info show];
        }
    }
    @finally
    {
        _isBusy = NO;
        
        [self.spinner stopAnimating];
    }
    
    return result;
}

// перевод таблицы в режим редактирования и обратно
- (IBAction)editDoneButton:(id)sender
{
    if (self.editing)
    {
        [super setEditing:NO animated:YES];
        
        [self.tvList setEditing:NO animated:YES];
        [self.tvList reloadData];
        
        NSMutableArray *buttons = (NSMutableArray *)[self.toolbar.items mutableCopy];
        [buttons insertObject:self.btnAddGood atIndex:0];
        self.toolbar.items = buttons;
        
        [self.btnEditDone setTitle:@"Удалить"];
        [self.btnEditDone setStyle:UIBarButtonItemStylePlain];
    }
    else
    {
        [super setEditing:YES animated:YES];
        
        [self.tvList setEditing:YES animated:YES];
        [self.tvList reloadData];
        
        NSMutableArray *buttons = (NSMutableArray *)[self.toolbar.items mutableCopy];
        [buttons removeObject:self.btnAddGood];
        self.toolbar.items = buttons;
        
        [self.btnEditDone setTitle:@"Готово"];
        [self.btnEditDone setStyle:UIBarButtonItemStyleDone];
    }
}

// удаление товаров с нулевыми количествами
- (void)deleteGoodsWithZeroQty
{   
    // не допускаем повторного запуска процесса
    if (!_isBusy)
    {
        [NSThread detachNewThreadSelector:@selector(threadStartSpinning:) toTarget:self withObject:nil];
    }
    
    _isBusy = YES;
    
    @try
    {
        // доступ к глобальному объекту приложения
        LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        // необходимо подключение к локальной БД
        FMDatabase *db = appDelegate.localDB.db;
        
        if (db != nil)
        {
            BOOL result = [db executeUpdate:@"DELETE FROM ShopListGoods WHERE ShopListId = ? and IFNULL(Qty, 0) = 0", _docId, nil];
            
            if (!result)
            {
                UIAlertView *info = [[UIAlertView alloc] initWithTitle:@"Ошибка"
                                                               message:db.lastErrorMessage
                                                              delegate:nil
                                                     cancelButtonTitle:@"OK"
                                                     otherButtonTitles:nil];
                [info show];
            }
        }
    }
    @finally
    {
        _isBusy = NO;
        
        [self.spinner stopAnimating];
    }
}

// удаление записи из списка
- (BOOL)deleteGood:(NSString *)docId
{
    BOOL result = NO;
    
    // не допускаем повторного запуска процесса
    if (!_isBusy)
    {
        [NSThread detachNewThreadSelector:@selector(threadStartSpinning:) toTarget:self withObject:nil];
    }
    
    _isBusy = YES;
    
    @try
    {
        // доступ к глобальному объекту приложения
        LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        // необходимо подключение к локальной БД
        FMDatabase *db = appDelegate.localDB.db;
        
        if (db != nil)
        {
            result = [db executeUpdate:@"DELETE FROM ShopListGoods WHERE DocId = ?", docId, nil];

            if (!result)
            {
                UIAlertView *info = [[UIAlertView alloc] initWithTitle:@"Ошибка при удалении"
                                                               message:db.lastErrorMessage
                                                              delegate:nil
                                                     cancelButtonTitle:@"OK"
                                                     otherButtonTitles:nil];
                [info show];
            }
            else
            {
                // сохранение состояний секций
                [self saveSectionsState];
                
                // обновляем подвал
                [self setListFooter];
            }
        }
    }
    @finally
    {
        _isBusy = NO;
        
        [self.spinner stopAnimating];
    }
 
    return result;
}

// обработка двойного тапа для открытия таблицы товаров
- (void)handleDoubleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    // переход на табличную форму только в случае успешного сохранения заголовка списка
    if ([self saveList:NO])
    {
        [self performSegueWithIdentifier:@"selectShopListGoodSegue" sender:self];
    }
}

// открытие таблицы магазинов для выбора из справочника
- (void)performSelectShopSegue
{
    [self performSegueWithIdentifier:@"selectShopSegue" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // сохраняем смещение по вертикали
    _tableOffset = self.tvList.contentOffset;
    
    // переход для выбора магазина
    if ([segue.identifier isEqualToString:@"selectShopSegue"])
    {
        LDShopsTableViewController *destView = segue.destinationViewController;
        
        destView.parentViewDelegate = self;
        
        [destView setReferenceMode];
    }
    else
        // добавление товара в список
        if ([segue.identifier isEqualToString:@"selectShopListGoodSegue"])
        {
            LDGoodsTableViewController *destView = segue.destinationViewController;
            
            destView.parentViewDelegate = self;
            
            [destView setReferenceMode:_docId];
            
            // товары добавляются из определенной категории
            if (_addGoodByCategory)
            {
                [destView addFilterCategory:_filterCategoryId];
                
                // сбрасываем фильтрацию для последующих вызовов справочника
                _addGoodByCategory = NO;
                _filterCategoryId = @"";
            }
        }
        else
            // редактирование кол-ва и цен товаров
            if ([segue.identifier isEqualToString:@"editShopListGoodSegue"])
            {
                LDShopListGoodEditViewController *destView = segue.destinationViewController;
                
                NSMutableDictionary *row = [_listData objectAtIndex:self.tvList.indexPathForSelectedRow.section];
                NSArray *goods = (NSArray *)[row valueForKey:@"Goods"];
                NSDictionary *good = [goods objectAtIndex:self.tvList.indexPathForSelectedRow.row];
                
                [destView setEditMode:[good objectForKey:@"DocId"]];
            }
}

// возможность перехода по segue
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    // перед добавлением товара в список последний необходимо сохранить
    if ([identifier isEqualToString:@"selectShopListGoodSegue"])
    {
        // переход - в случае успешного сохранения
        return [self saveList:NO];
    }
    else
        // редактирование кол-ва и цены товара
        if ([identifier isEqualToString:@"editShopListGoodSegue"])
        {
            // должна быть выбрана строка для редактирования
            return (self.tvList.indexPathForSelectedRow != nil);
        }
        else return YES;
}

// обработка выбора категории
- (void)setSelectedValue:(id)sender element:(NSString *)name key:(NSString *)value fromRef:(NSString *)tableName allValues:(NSDictionary *)values
{
    if ([tableName isEqualToString:@"REF_Shops"])
    {
        _shopId = value;
        _shopName = name;
        
        // при открытии формы списка развернем вью деталей (viewDidAppear)
        _openDetailsView = YES;
    }
    else
        // добавление товара в список
        if ([tableName isEqualToString:@"REF_Goods"])
        {
            // доступ к глобальному объекту приложения
            LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
            
            // необходимо подключение к локальной БД
            FMDatabase *db = appDelegate.localDB.db;
            
            if (db != nil)
            {
                double qty = [[values objectForKey:@"Qty"] doubleValue];
                
                BOOL success = NO;
                
                // товар добавлен или изменено кол-во
                if (qty > 0.0)
                {
                    double price = [[values objectForKey:@"Price"] doubleValue];
                    double amount = price * qty;
                    
                    BOOL goodInList = NO;
                    
                    // проверяем, есть ли в списке такой товар
                    for (int i = 0; i < [_listData count]; i++)
                    {
                        NSArray *categoryGoods = [_listData[i] objectForKey:@"Goods"];
                        
                        for (int j = 0; j < [categoryGoods count]; j++)
                        {
                            NSDictionary *good = categoryGoods[j];
                            
                            NSString *goodId = [NSString stringWithFormat:@"%@", [good objectForKey:@"GoodId"]];
                            
                            if ([goodId isEqualToString:value])
                            {
                                goodInList = YES;
                                
                                break;
                            }
                        }
                    }
                    
                    // добавляем новую строку с товаром
                    if (!goodInList)
                    {
                        // добавляем запись в ShopListGoods
                        NSDictionary *argsDict = [NSDictionary dictionaryWithObjectsAndKeys:_docId, @"ShopListId",
                                                                                             value, @"GoodId",
                                                                 [NSNumber numberWithDouble:price], @"Price",
                                                                   [NSNumber numberWithDouble:qty], @"Qty",
                                                                [NSNumber numberWithDouble:amount], @"Amount",
                                                                                     [NSDate date], @"CreateDate", nil];
                        
                        success = [db executeUpdate:@"INSERT INTO ShopListGoods (ShopListId, GoodId, Price, Qty, Amount, CreateDate) \
                                                      VALUES (:ShopListId, :GoodId, :Price, :Qty, :Amount, :CreateDate)" withParameterDictionary:argsDict];
                    }
                    // обновляем имеющуюся строку
                    else
                    {
                        NSDictionary *argsDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:price], @"Price",
                                                                                              [NSNumber numberWithDouble:qty], @"Qty",
                                                                                           [NSNumber numberWithDouble:amount], @"Amount",
                                                                                                                [NSDate date], @"EditDate",
                                                                                                                       _docId, @"ShopListId",
                                                                                                                        value, @"GoodId", nil];
                        success = [db executeUpdate:@"UPDATE ShopListGoods \
                                                      SET   Price = :Price \
                                                          , Qty = :Qty \
                                                          , Amount = :Amount \
                                                          , EditDate = :EditDate \
                                                      WHERE     ShopListId = :ShopListId \
                                                            and GoodId = :GoodId" withParameterDictionary:argsDict];
                    }
                }
                // товар с нулевым кол-вом - необходимо удалить из списка
                else
                {
                    success = [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM ShopListGoods WHERE GoodId = %@", value]];
                }
                
                if (success)
                {                    
                    // анализируем изменение флага активности списка
                    // после добавления нового товара список должен стать активным
                    BOOL prevActiveFlag = _active;
                    
                    _active = ![self checkAllGoodsBought];
                    
                    if (_active != prevActiveFlag)
                    {
                        [self setListActive:_active];
                    }
                    
                    [self loadListData];
                }
            }
        }
}

// загрузка данных заголовка списка из БД
- (void)loadData
{
    // не допускаем повторного запуска процесса
    if (!_isBusy)
    {
        [NSThread detachNewThreadSelector:@selector(threadStartSpinning:) toTarget:self withObject:nil];
    }
    
    _isBusy = YES;
    
    @try
    {
        // доступ к глобальному объекту приложения
        LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        // необходимо подключение к локальной БД
        FMDatabase *db = appDelegate.localDB.db;
        
        if (db != nil)
        {
            FMResultSet *qryList = [db executeQuery:[NSString stringWithFormat:@"SELECT   sl.Name \
                                                                                        , IFNULL(sl.ShopId, 0) AS ShopId, IFNULL(s.Name, '') AS ShopName \
                                                                                        , IFNULL(sl.SortAZ, 0) AS SortAZ \
                                                                                        , IFNULL(sl.Active, 0) AS Active \
                                                                                 FROM ShopLists sl \
                                                                                        LEFT JOIN REF_Shops s \
                                                                                            ON sl.ShopId = s.DocId \
                                                                                 WHERE (sl.DocId = %@)", _docId]];
            if ([qryList next])
            {
                _listName = [qryList stringForColumn:@"Name"];
                _shopId = [qryList stringForColumn:@"ShopId"];
                _shopName = [qryList stringForColumn:@"ShopName"];
                
                // флаг сортировки списка - хранится непосредственно в заголовке списка
                _sortListAZ = [qryList boolForColumn:@"SortAZ"];
                
                // флаг активности списка
                _active = [qryList boolForColumn:@"Active"];
            }
            
            [qryList close];
        }
    }
    @finally
    {
        _isBusy = NO;
        
        [self.spinner stopAnimating];
    }
}

// загрузка данных списка из БД
- (void)loadListData
{
    // не допускаем повторного запуска процесса
    if (!_isBusy)
    {
        [NSThread detachNewThreadSelector:@selector(threadStartSpinning:) toTarget:self withObject:nil];
    }
    
    _isBusy = YES;
    
    @try
    {
        // доступ к глобальному объекту приложения
        LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        // необходимо подключение к локальной БД
        FMDatabase *db = appDelegate.localDB.db;
        
        if (db != nil)
        {
            NSString *boughtFilter = @"",
            *orderBy = @"";
            
            // флаг _boughtItemsHidden определяет, нужно ли прятать отмеченные (купленные) строки
            if (_boughtItemsHidden)
            {
                boughtFilter = @" and (   IFNULL(sl.Bought, 'NO') = 'NO' \
                                       or IFNULL(sl.Bought, 0) = 0)";
            }
            
            // определяем, нужна ли сортировка, учитывая настройку о положении отмеченных позиций внизу списка
            if (_boughtItemsAtBottom)
            {
                if (_sortListAZ)
                {
                    orderBy = @"ORDER BY sl.Bought, g.Name ";
                }
                else
                {
                    orderBy = @"ORDER BY sl.Bought, sl.DocId ";
                }
            }
            else
            {
                if (_sortListAZ)
                {
                    orderBy = @"ORDER BY g.Name ";
                }
            }
            
            //////////////////////////////////////////////////////////////////////
            // разделения на категории нет - создаем одну "фиктивную" категорию //
            //////////////////////////////////////////////////////////////////////
            if (!_showCategories)
            {
                FMResultSet *qryList = [db executeQuery:[NSString stringWithFormat:@"SELECT   sl.DocId \
                                                                                            , sl.GoodId \
                                                                                            , g.Name as GoodName \
                                                                                            , sl.Qty \
                                                                                            , IFNULL(m.Name, '') as MeasureName \
                                                                                            , IFNULL(m.Name234, '') as MeasureName234 \
                                                                                            , IFNULL(m.Name567890, '') as MeasureName567890 \
                                                                                            , IFNULL(m.IncQty, 1) as IncQty \
                                                                                            , sl.Amount \
                                                                                            , sl.Bought \
                                                                                     FROM ShopListGoods sl \
                                                                                            LEFT JOIN REF_Goods g \
                                                                                                ON sl.GoodId = g.DocId \
                                                                                            LEFT JOIN REF_Measures m \
                                                                                                ON g.MeasureId = m.DocId \
                                                                                     WHERE (sl.ShopListId = %@) \
                                                                                           %@ \
                                                                                           %@", _docId, boughtFilter, orderBy]];
                _listData = [[NSMutableArray alloc] init];
                
                NSMutableDictionary *categoryAllList = [[NSMutableDictionary alloc] init];
                
                // добавляем "фиктивную" категорию для всего списка товаров
                [categoryAllList setObject:@"0" forKey:@"CatId"];
                [categoryAllList setObject:@"содержимое списка" forKey:@"CatName"];
                [categoryAllList setObject:[NSNumber numberWithBool:YES] forKey:@"CategoryExpanded"];
                
                // создаем массив товаров
                NSMutableArray *goods = [[NSMutableArray alloc] init];
                
                while([qryList next])
                {
                    NSString *docId = [qryList stringForColumn:@"DocId"];
                    NSString *goodId = [qryList stringForColumn:@"GoodId"];
                    NSString *goodName = [qryList stringForColumn:@"GoodName"];
                    NSNumber *qty = [NSNumber numberWithDouble:[qryList doubleForColumn:@"Qty"]];
                    NSString *measure = [qryList stringForColumn:@"MeasureName"];
                    NSString *measure234 = [qryList stringForColumn:@"MeasureName234"];
                    NSString *measure567890 = [qryList stringForColumn:@"MeasureName567890"];
                    NSNumber *amount = [NSNumber numberWithDouble:[qryList doubleForColumn:@"Amount"]];
                    NSNumber *bought = [NSNumber numberWithBool:[qryList boolForColumn:@"Bought"]];
                    
                    NSMutableDictionary *row = [NSMutableDictionary dictionaryWithObjectsAndKeys: docId, @"DocId",
                                                                                                 goodId, @"GoodId",
                                                                                               goodName, @"GoodName",
                                                                                                    qty, @"Qty",
                                                                                                measure, @"MeasureName",
                                                                                             measure234, @"MeasureName234",
                                                                                          measure567890, @"MeasureName567890",
                                                                                                 amount, @"Amount",
                                                                                                 bought, @"Bought", nil];
                    [goods addObject:row];
                }
                
                // добавляем массив товаров
                [categoryAllList setObject:goods forKey:@"Goods"];
                
                [_listData addObject:categoryAllList];
                
                [qryList close];
            }
            ////////////////////////////////////////
            // необходимо разделение на категории //
            ////////////////////////////////////////
            else
            {
                NSString *categoryOrderBy = @"";
                
                if (_sortListAZ)
                {
                    categoryOrderBy = @"ORDER BY IFNULL(cat.Name, 'категория не выбрана')";
                }
                
                FMResultSet *qryCats = [db executeQuery:[NSString stringWithFormat:@"SELECT DISTINCT   IFNULL(cat.DocId, 0) as CategoryId \
                                                                                                     , IFNULL(cat.Name, 'категория не выбрана') as CategoryName \
                                                                                                     , IFNULL(cat.ColorR, 1.0) as R \
                                                                                                     , IFNULL(cat.ColorG, 1.0) as G \
                                                                                                     , IFNULL(cat.ColorB, 1.0) as B \
                                                                                                     , IFNULL(cat.ColorAlpha, 1.0) as A \
                                                                                     FROM ShopListGoods sl \
                                                                                            LEFT JOIN REF_Goods g \
                                                                                                ON sl.GoodId = g.DocId \
                                                                                            LEFT JOIN REF_GoodCategories cat \
                                                                                                ON g.CategoryId = cat.DocId \
                                                                                     WHERE (sl.ShopListId = %@) \
                                                                                           %@ \
                                                                                           %@", _docId, boughtFilter, categoryOrderBy]];
                
                _listData = [[NSMutableArray alloc] init];
                
                while([qryCats next])
                {
                    NSString *catId = [qryCats stringForColumn:@"CategoryId"];
                    NSString *catName = [qryCats stringForColumn:@"CategoryName"];
                    
                    NSMutableDictionary *categoryWithGoods = [[NSMutableDictionary alloc] init];
                    
                    // добавляем категорию
                    [categoryWithGoods setObject:catId forKey:@"CatId"];
                    [categoryWithGoods setObject:catName forKey:@"CatName"];
                    
                    // цвет категории
                    double r = [qryCats doubleForColumn:@"R"];
                    double g = [qryCats doubleForColumn:@"G"];
                    double b = [qryCats doubleForColumn:@"B"];
                    double a = [qryCats doubleForColumn:@"A"];
                    
                    UIColor *catColor = [UIColor colorWithRed:r green:g blue:b alpha:a];
                    
                    [categoryWithGoods setObject:catColor forKey:@"Color"];
                    
                    // первоначально все категории cвернуты
                    [categoryWithGoods setObject:[NSNumber numberWithBool:NO] forKey:@"CategoryExpanded"];
                    
                    FMResultSet *qryList = [db executeQuery:[NSString stringWithFormat:@"SELECT   sl.DocId \
                                                                                                , sl.GoodId \
                                                                                                , g.Name as GoodName \
                                                                                                , sl.Qty \
                                                                                                , IFNULL(m.Name, '') as MeasureName \
                                                                                                , IFNULL(m.Name234, '') as MeasureName234 \
                                                                                                , IFNULL(m.Name567890, '') as MeasureName567890 \
                                                                                                , sl.Amount \
                                                                                                , sl.Bought \
                                                                                         FROM ShopListGoods sl \
                                                                                                LEFT JOIN REF_Goods g \
                                                                                                    ON sl.GoodId = g.DocId \
                                                                                                LEFT JOIN REF_Measures m \
                                                                                                    ON g.MeasureId = m.DocId \
                                                                                         WHERE     (sl.ShopListId = %@) \
                                                                                               and (g.CategoryId = %@) \
                                                                                               %@ \
                                                                                               %@", _docId, catId, boughtFilter, orderBy]];
                    // создаем массив товаров
                    NSMutableArray *goods = [[NSMutableArray alloc] init];
                    
                    while([qryList next])
                    {
                        NSString *docId = [qryList stringForColumn:@"DocId"];
                        NSString *goodId = [qryList stringForColumn:@"GoodId"];
                        NSString *goodName = [qryList stringForColumn:@"GoodName"];
                        NSNumber *qty = [NSNumber numberWithDouble:[qryList doubleForColumn:@"Qty"]];
                        NSString *measure = [qryList stringForColumn:@"MeasureName"];
                        NSString *measure234 = [qryList stringForColumn:@"MeasureName234"];
                        NSString *measure567890 = [qryList stringForColumn:@"MeasureName567890"];
                        NSNumber *amount = [NSNumber numberWithDouble:[qryList doubleForColumn:@"Amount"]];
                        NSNumber *bought = [NSNumber numberWithBool:[qryList boolForColumn:@"Bought"]];
                        
                        NSMutableDictionary *row = [NSMutableDictionary dictionaryWithObjectsAndKeys: docId, @"DocId",
                                                                                                     goodId, @"GoodId",
                                                                                                   goodName, @"GoodName",
                                                                                                        qty, @"Qty",
                                                                                                    measure, @"MeasureName",
                                                                                                 measure234, @"MeasureName234",
                                                                                              measure567890, @"MeasureName567890",
                                                                                                     amount, @"Amount",
                                                                                                     bought, @"Bought", nil];
                        
                        [goods addObject:row];
                    }
                    
                    [qryList close];
                    
                    // добавляем массив товаров
                    [categoryWithGoods setObject:goods forKey:@"Goods"];
                    
                    [_listData addObject:categoryWithGoods];
                }
            }
            
            // обновляем подвал
            [self setListFooter];
            
            [self.tvList reloadData];
        }
    }
    @finally
    {
        _isBusy = NO;
        
        [self.spinner stopAnimating];
    }
}

- (IBAction)sortGoodsButton:(id)sender
{
    _sortListAZ = !_sortListAZ;
    
    [self setSortButtonTintColor];
    
    // сразу же сохраняем флаг сортировки в заголовке списка, если заголовок уже есть
    if (![_docId isEqualToString:@"0"])
    {
        LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
    
        FMDatabase *db = appDelegate.localDB.db;
    
        if (db != nil)
        {
            NSMutableDictionary *argsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:_sortListAZ], @"SortAZ", [NSDate date], @"EditDate", _docId, @"DocId", nil];
            
            [db executeUpdate:@"UPDATE ShopLists \
                                SET   SortAZ = :SortAZ \
                                    , EditDate = :EditDate \
                                WHERE DocId = :DocId" withParameterDictionary:argsDict];
        }
    }
    
    [self loadListData];
}

// установка цвета кнопки сортировки
- (void)setSortButtonTintColor
{
    if (_sortListAZ)
    {
        self.btnSort.tintColor = [self.view tintColor];
    }
    else self.btnSort.tintColor = [UIColor colorWithRed:220.0/255.0 green:220.0/255.0 blue:220.0/255.0 alpha:1.0];
}

/////////////////////////////////////////////
// Реализация делегата UITableViewDelegate //
/////////////////////////////////////////////

// высота секций
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (tableView == self.tvList)
    {
        if (_showCategories)
        {
            NSDictionary *category = (NSDictionary *)[_listData objectAtIndex:section];
            
            if ([[category objectForKey:@"Goods"] count] > 0)
            {
                return _gridSectionHeight;
            }
            else return 0;
        }
        else return 0;
    }
    else return 0;
}

// высота ячеек
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (CGFloat)_gridRowHeight;
}

// отображение ячейки
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ////////////////////
    // таблица списка //
    ////////////////////
    if (tableView == self.tvList)
    {
        static NSString *cellIdentifier = @"ShopsListGoodCellItem";
        static NSString *tmpStrValue = @"1.0";
        
        UITableViewCell *cell;
        
        UIImageView *imgCheck;
        UILabel *lblGoodName;
        
        NSMutableDictionary *row = [_listData objectAtIndex:indexPath.section];
        NSArray *goods = (NSArray *)[row valueForKey:@"Goods"];
        NSDictionary *good = [goods objectAtIndex:indexPath.row];
        
        ///////////////////////////////////////////
        // полное представление строк с товарами //
        ///////////////////////////////////////////
        if ([_cellViewType isEqualToString:@"full"])
        {
            UILabel *lblQty;
            UILabel *lblAmount;
            
            cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            
            if (cell == nil)
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
                
                // выводим галку, как бы намекающую на то, что по тапу будет открыта форма редактирования (didSelectRowAtIndexPath)
                [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
                
                [cell setFrame:CGRectMake(cell.frame.origin.x, cell.frame.origin.x, cell.frame.size.width, _gridRowHeight)];
                
                CGRect cellRect = cell.frame;
                
                imgCheck = [[UIImageView alloc] init];
                [imgCheck setTag:6];
                
                lblGoodName = [[UILabel alloc] init];
                [lblGoodName setTag:1];
                [lblGoodName setFont:[UIFont boldSystemFontOfSize:_gridFontSize]];
                [lblGoodName setTextColor:[UIColor darkTextColor]];
                
                lblQty = [[UILabel alloc] init];
                [lblQty setTag:2];
                [lblQty setFont:[UIFont systemFontOfSize:_gridFontSize - 1.0]];
                [lblQty setTextAlignment:NSTextAlignmentLeft];
                
                lblAmount = [[UILabel alloc] init];
                [lblAmount setTag:3];
                [lblAmount setFont:[UIFont systemFontOfSize:_gridFontSize - 3.0]];
                [lblAmount setTextAlignment:NSTextAlignmentLeft];
                
                // галка покупки
                [imgCheck setFrame:CGRectMake(_gridRowHeight / 4.0, _gridRowHeight / 4.0, _gridRowHeight / 2.0, _gridRowHeight / 2.0)];
                
                [cell.contentView addSubview:imgCheck];
                
                // наименование товара
                CGSize maximumLabelSize = CGSizeMake(cellRect.size.width - (imgCheck.frame.size.width + _gridRowHeight / 2.0), FLT_MAX);
                CGSize expectedLabelSize = [tmpStrValue boundingRectWithSize:maximumLabelSize options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading) attributes: @{NSFontAttributeName:lblGoodName.font} context: nil].size;
            
                [lblGoodName setFrame:CGRectMake(imgCheck.frame.size.width + _gridRowHeight / 2.0, 0.0, maximumLabelSize.width, expectedLabelSize.height)];
                [cell.contentView addSubview:lblGoodName];
                
                CGFloat offsetXY = cellRect.size.height - lblGoodName.frame.size.height - 2.0;
                CGFloat bottomLabelWidth = (cellRect.size.width - (_gridRowHeight / 2.0) - (offsetXY + 2.0) - 2.0) / 2.0;
                
                // кол-во
                maximumLabelSize = CGSizeMake(bottomLabelWidth, FLT_MAX);
                expectedLabelSize = [tmpStrValue boundingRectWithSize:maximumLabelSize options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading) attributes: @{NSFontAttributeName:lblQty.font} context: nil].size;
                
                [lblQty setFrame:CGRectMake(lblGoodName.frame.origin.x, lblGoodName.frame.origin.y + lblGoodName.frame.size.height + 1.0 + ((offsetXY - expectedLabelSize.height) / 2.0), bottomLabelWidth, expectedLabelSize.height)];
                [cell.contentView addSubview:lblQty];
                
                // стоимость
                expectedLabelSize = [tmpStrValue boundingRectWithSize:maximumLabelSize options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading) attributes: @{NSFontAttributeName:lblAmount.font} context: nil].size;
                
                [lblAmount setFrame:CGRectMake(lblQty.frame.origin.x + lblQty.frame.size.width + 1.0, lblQty.frame.origin.y, bottomLabelWidth, expectedLabelSize.height)];
                [cell.contentView addSubview:lblAmount];
                
                // в левой части ячейки узкая цветная полоска, если выводятся категории
                if (_showCategories)
                {
                    UIView *colorStripeView = [[UIView alloc] initWithFrame:CGRectMake(1.0, 1.0, cell.contentView.frame.size.width * 0.025, cell.contentView.frame.size.height - 2.0)];
                    [colorStripeView setTag:7];
                    
                    [cell.contentView addSubview:colorStripeView];
                }
            }
            
            // заполняем ячейку контролами и передаем данные
            lblGoodName = (UILabel *)[cell viewWithTag:1];
            lblGoodName.text = [good objectForKey:@"GoodName"];
            
            double qty = [[good objectForKey:@"Qty"] doubleValue];
            double amount = [[good objectForKey:@"Amount"] doubleValue];
            
            lblQty = (UILabel *)[cell viewWithTag:2];
            if (qty > 0.0)
            {
                // склоняем наименование единицы измерения
                int qtyTrunc = trunc(qty),
                    modQty = (int)fmodf(qtyTrunc, 10);
                
                NSString *measureName = [good objectForKey:@"MeasureName"];
                
                if ((qtyTrunc >= 11) && (qtyTrunc <= 20))
                {
                    measureName = [good objectForKey:@"MeasureName567890"];
                }
                else
                {
                    if ((modQty >= 2) && (modQty <= 4))
                    {
                        measureName = [good objectForKey:@"MeasureName234"];
                    }
                    else
                        if ((modQty == 0) || ((modQty >= 5) && (modQty <= 9)))
                        {
                            measureName = [good objectForKey:@"MeasureName567890"];
                        }
                }
                
                if ([measureName isEqualToString:@""]) measureName = [good objectForKey:@"MeasureName"];
                
                lblQty.text = [NSString stringWithFormat:@"%.3f %@", qty, measureName];
            }
            else lblQty.text = @"";
            
            lblAmount = (UILabel *)[cell viewWithTag:3];
            if (amount > 0.0)
            {
                lblAmount.text = [NSString stringWithFormat:@"%.2f руб", amount];
            }
            else lblAmount.text = @"";
            
            imgCheck = (UIImageView *)[cell viewWithTag:6];
            
            // строка отмечена
            BOOL bought = [[good objectForKey:@"Bought"] boolValue];
            
            if (bought)
            {
                lblGoodName.textColor = [UIColor lightGrayColor];
                lblQty.textColor = [UIColor lightGrayColor];
                lblAmount.textColor = [UIColor lightGrayColor];
                
                imgCheck.image = [UIImage imageNamed:@"Check_yes"];
            }
            else
            {
                lblGoodName.textColor = [UIColor blackColor];
                lblQty.textColor = [UIColor darkGrayColor];
                lblAmount.textColor = [UIColor darkGrayColor];
                
                imgCheck.image = [UIImage imageNamed:@"Check_no"];
            }
        }
        else
            ///////////////////////////////////////////////
            // упрощенное представление строк с товарами //
            ///////////////////////////////////////////////
            if ([_cellViewType isEqualToString:@"simple"])
            {
                cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
                
                if (cell == nil)
                {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
                    
                    // выводим галку, как бы намекающую на то, что по тапу будет открыта форма редактирования (didSelectRowAtIndexPath)
                    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
                    
                    [cell setFrame:CGRectMake(cell.frame.origin.x, cell.frame.origin.x, cell.frame.size.width, _gridRowHeight)];
                    
                    CGRect cellRect = cell.frame;
                    
                    imgCheck = [[UIImageView alloc] init];
                    [imgCheck setTag:6];
                    
                    lblGoodName = [[UILabel alloc] init];
                    [lblGoodName setTag:1];
                    [lblGoodName setFont:[UIFont boldSystemFontOfSize:_gridFontSize]];
                    [lblGoodName setTextColor:[UIColor darkTextColor]];
                    
                    // галка покупки
                    [imgCheck setFrame:CGRectMake(_gridRowHeight / 4.0, _gridRowHeight / 4.0, _gridRowHeight / 2.0, _gridRowHeight / 2.0)];
                    
                    [cell.contentView addSubview:imgCheck];
                    
                    CGSize maximumLabelSize = CGSizeMake(cellRect.size.width - (imgCheck.frame.size.width + _gridRowHeight / 2.0), FLT_MAX);
                    CGSize expectedLabelSize = [tmpStrValue boundingRectWithSize:maximumLabelSize options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading) attributes: @{NSFontAttributeName:lblGoodName.font} context: nil].size;
                    
                    [lblGoodName setFrame:CGRectMake(imgCheck.frame.size.width + _gridRowHeight / 2.0, (_gridRowHeight - expectedLabelSize.height) / 2.0, maximumLabelSize.width, expectedLabelSize.height)];
                    
                    [cell.contentView addSubview:lblGoodName];
                    
                    // в левой части ячейки узкая цветная полоска, если выводятся категории
                    if (_showCategories)
                    {
                        UIView *colorStripeView = [[UIView alloc] initWithFrame:CGRectMake(1.0, 1.0, cell.contentView.frame.size.width * 0.025, cell.contentView.frame.size.height - 2.0)];
                        [colorStripeView setTag:7];
                        
                        [cell.contentView addSubview:colorStripeView];
                    }
                }
                
                // заполняем ячейку контролами и передаем данные
                lblGoodName = (UILabel *)[cell viewWithTag:1];
                lblGoodName.text = [good objectForKey:@"GoodName"];
                
                imgCheck = (UIImageView *)[cell viewWithTag:6];
                
                // строка отмечена
                BOOL bought = [[good objectForKey:@"Bought"] boolValue];
                
                if (bought)
                {
                    lblGoodName.textColor = [UIColor lightGrayColor];
                    
                    imgCheck.image = [UIImage imageNamed:@"Check_yes"];
                }
                else
                {
                    lblGoodName.textColor = [UIColor blackColor];
                    
                    imgCheck.image = [UIImage imageNamed:@"Check_no"];
                }
            }
        
        // цвет категории, если они выводятся
        if (_showCategories)
        {
            UIView *colorStripeView = [cell.contentView viewWithTag:7];
            colorStripeView.backgroundColor = (UIColor *)[row valueForKey:@"Color"];
        }
        
        [cell setBackgroundColor:[UIColor whiteColor]];
        
        return cell;
    }
    else return nil;
}

// выбор строки - открытие формы редактирования
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.tvList)
    {
        // открытие формы редактирования строки списка
        [self performSegueWithIdentifier:@"editShopListGoodSegue" sender:self];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)aTableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.editing || !indexPath)
    {
        return UITableViewCellEditingStyleNone;
    }
    else
        if (self.editing)
        {
            return UITableViewCellEditingStyleDelete;
        }
        else return UITableViewCellEditingStyleNone;
}

// удаление записи с помощью стандартных возможностей TableView
- (void)tableView:(UITableView *)aTableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        NSMutableDictionary *row = [_listData objectAtIndex:indexPath.section];
        NSMutableArray *goods = (NSMutableArray *)[row valueForKey:@"Goods"];
        NSMutableDictionary *good = (NSMutableDictionary *)[goods objectAtIndex:indexPath.row];
        
        NSString *docId = [good objectForKey:@"DocId"];
        
        // удалили из БД - удаляем из таблицы
        if ([self deleteGood:docId])
        {
            [goods removeObjectAtIndex:indexPath.row];
            
            // проверяем, что нужно сделать с флагом активности списка
            BOOL prevActiveFlag = _active;
            
            _active = ![self checkAllGoodsBought];
            
            if (_active != prevActiveFlag)
            {
                [self setListActive:_active];
            }
        }
        
        [self.tvList reloadData];
    }
}

// число записей (товаров) в секции (категории)
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
{
    if (tableView == self.tvList)
    {
        NSDictionary *category = (NSDictionary *)[_listData objectAtIndex:sectionIndex];

        // список разделен на категории
        if (_showCategories)
        {
            if ([[category valueForKey:@"CategoryExpanded"] boolValue])
            {
                return [(NSArray *)[category valueForKey:@"Goods"] count];
            }
            else return 0;
        }
        // категории не показываются
        else
        {
            return [(NSArray *)[category valueForKey:@"Goods"] count];
        }
    }
    else return 0;
}

// число секций (категорий товаров) в таблице
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (tableView == self.tvList)
    {
        return [_listData count];
    }
    else return 0;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Удалить";
}

// представление для секции - категории
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (_showCategories)
    {
        NSDictionary *row = (NSDictionary *)[_listData objectAtIndex:section];
        NSArray *goods = (NSArray *)[row objectForKey:@"Goods"];
        
        if ([goods count] > 0)
        {
            // цвет категории
            UIColor *backColor = (UIColor *)[row valueForKey:@"Color"];
            
            UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, _gridSectionHeight)];
            [headerView setBackgroundColor:[UIColor whiteColor]];
            
            UIImage *imgShowHide;
            
            if ([[row valueForKey:@"CategoryExpanded"] boolValue])
            {
                imgShowHide = [UIImage imageNamed:@"ExpandedSection"];
            }
            else
            {
                imgShowHide = [UIImage imageNamed:@"CollapsedSection"];
            }
            
            // кнопка "свернуть/развернуть"
            CGRect rectShowHide = CGRectMake(1.0, 1.0, _gridSectionHeight - 1.0, _gridSectionHeight - 1.0);
            
            UIButton *btnShowHide = [UIButton buttonWithType:UIButtonTypeCustom];
            [btnShowHide setFrame:rectShowHide];
            [btnShowHide setBackgroundColor:backColor];
            [btnShowHide setTag:section];
            [btnShowHide setImage:imgShowHide forState:UIControlStateNormal];
            [btnShowHide addTarget:self action:@selector(sectionShowHideButtonTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
            
            [headerView addSubview:btnShowHide];
            
            // кнопка добавления товара в категорию
            CGRect rectAddGood = CGRectMake(headerView.frame.size.width * 0.9 - 1.0, 1.0, headerView.frame.size.width * 0.1 + 1.0, _gridSectionHeight - 1.0);
            
            UIButton *btnAddGood = [UIButton buttonWithType:UIButtonTypeContactAdd];
            [btnAddGood setTintColor:[UIColor blackColor]];
            [btnAddGood setFrame:rectAddGood];
            [btnAddGood setBackgroundColor:backColor];
            [btnAddGood setTag:section];
            [btnAddGood addTarget:self action:@selector(addGoodButtonTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
            
            [headerView addSubview:btnAddGood];
            
            // наименование категории
            CGRect rectHeaderLabel = CGRectMake(rectShowHide.origin.x + rectShowHide.size.width, 1.0,
                                                self.view.frame.size.width - (rectShowHide.origin.x + rectShowHide.size.width + 1.0) - headerView.frame.size.width * 0.1, _gridSectionHeight - 1.0);
            
            UILabel* headerLabel = [[UILabel alloc] init];
            [headerLabel setUserInteractionEnabled:YES];
            [headerLabel setFrame:rectHeaderLabel];
            [headerLabel setBackgroundColor:backColor];
            [headerLabel setTag:section];
            [headerLabel setTextColor:[UIColor blackColor]];
            [headerLabel setFont:[UIFont boldSystemFontOfSize:17.0]];
            [headerLabel setText:[row valueForKey:@"CatName"]];
            // будем обрабатывать тапы по названию категории
            UITapGestureRecognizer *labelTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(categoryLabelTapped:)];
            labelTap.numberOfTapsRequired = 1;
            [headerLabel addGestureRecognizer:labelTap];
            
            [headerView addSubview:headerLabel];
            
            return headerView;
        }
        else return nil;
    }
    else return nil;
}

// тап по названию категории - в секции
- (void)categoryLabelTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    UILabel *lblSection = (UILabel *)gestureRecognizer.view;
    
    [self expandCollapseSection:lblSection.tag];
}

// тап по кнопке "свернуть/разварнуть"
- (void)sectionShowHideButtonTouchUpInside:(UIButton*)sender
{
    [self expandCollapseSection:sender.tag];
}

// тап по кнопке добавления товара из заданной категории
- (void)addGoodButtonTouchUpInside:(UIButton *)sender
{
    // задаем категорию
    if ([sender isKindOfClass:[UIButton class]])
    {
        _addGoodByCategory = YES;
        
        int sectionIndex = (int)((UIButton *)sender).tag;
        
        NSDictionary *category = (NSDictionary *)[_listData objectAtIndex:sectionIndex];
        
        _filterCategoryId = [category valueForKey:@"CatId"];
        
        [self performSegueWithIdentifier:@"selectShopListGoodSegue" sender:self];
    }
}

///////////////////////////////
// вспомогательные процедуры //
///////////////////////////////

// создание новой записи
- (void)setNewListMode
{
    _docId = @"0";
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd.MM.yyyy"];
    
    _listName = [NSString stringWithFormat:@"Список %@", [NSString stringWithFormat:@"%@", [dateFormatter stringFromDate:[NSDate date]]]];
    
    _shopId = @"0";
    _shopName = @"";
}

// редактирование или удаление текущей записи
- (void)setEditListMode:(NSString *)docId;
{
    _docId = docId;
    
    [self loadData];
}

// процедура сворачивания/развертывания секции
- (void)expandCollapseSection:(long)section
{
    NSMutableDictionary *category = (NSMutableDictionary *)[_listData objectAtIndex:section];
    BOOL categoryExpanded = ![[category valueForKey:@"CategoryExpanded"] boolValue];
    
    [category setObject:[NSNumber numberWithBool:categoryExpanded] forKey:@"CategoryExpanded"];
    
    // сохранение состояний секций
    [self saveSectionsState];
    
    [self.tvList reloadData];
}

// процедура проверки, все ли товары отмечены
- (BOOL)checkAllGoodsBought
{
    BOOL result = YES;
    
    if ([_listData count] > 0)
    {
        for (int i = 0; i < [_listData count]; i++)
        {
            NSDictionary *category = (NSDictionary *)[_listData objectAtIndex:i];
            NSArray *goods = (NSArray *)[category valueForKey:@"Goods"];
            
            for (int j = 0; j < [goods count]; j++)
            {
                NSDictionary *good = (NSDictionary *)[goods objectAtIndex:j];
                
                if (![[good valueForKey:@"Bought"] boolValue])
                {
                    result = NO;
                    break;
                }
            }
        }
    }
    // список пуст, надо проверить, действительно ли он пуст, или скрыты все отмеченные товары
    else
    {
        LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        FMDatabase *db = appDelegate.localDB.db;
        
        if (db != nil)
        {
            FMResultSet *qryGoods = [db executeQuery:[NSString stringWithFormat:@"SELECT COUNT(*) as GoodsCount \
                                                                                  FROM ShopListGoods \
                                                                                  WHERE ShopListId = %@", _docId]];
            if ([qryGoods next])
            {
                result = ([qryGoods intForColumn:@"GoodsCount"] != 0);
            }
            
            [qryGoods close];
        }
    }
    
    return result;
}

// отметка флага активности в БД
- (void)setListActive:(BOOL)activeFlag
{
    if (![_docId isEqualToString:@"0"])
    {
        LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        FMDatabase *db = appDelegate.localDB.db;
        
        if (db != nil)
        {
            NSMutableDictionary *argsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:activeFlag], @"Active", [NSDate date], @"EditDate", _docId, @"DocId", nil];
            
            [db executeUpdate:@"UPDATE ShopLists \
                                SET   Active = :Active \
                                    , EditDate = :EditDate \
                                WHERE DocId = :DocId" withParameterDictionary:argsDict];
        }
    }
}

// вывод информации о списке в нижней части формы
- (void)setListFooter
{
    LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    FMDatabase *db = appDelegate.localDB.db;
    
    if (db != nil)
    {
        NSString *strAmount = @"0",
                 *strCountBought = @"0",
                 *strCountAll = @"0";
        
        FMResultSet *qry = [db executeQuery:[NSString stringWithFormat:@"SELECT SUM(IFNULL(Amount, 0)) as Amount \
                                                                         FROM ShopListGoods \
                                                                         WHERE ShopListId = %@", _docId]];
        if ([qry next])
        {
            strAmount = [NSString stringWithFormat:@"%.2f", [qry doubleForColumn:@"Amount"]];
        }
        
        [qry close];
        
        qry = [db executeQuery:[NSString stringWithFormat:@"SELECT COUNT(*) as CountBought \
                                                            FROM ShopListGoods sl \
                                                            WHERE     sl.ShopListId = %@ \
                                                                  and sl.Bought = 1", _docId]];
        if ([qry next])
        {
            strCountBought = [qry stringForColumn:@"CountBought"];
        }
        
        [qry close];
        
        qry = [db executeQuery:[NSString stringWithFormat:@"SELECT COUNT(*) as CountAll \
                                                            FROM ShopListGoods sl \
                                                            WHERE sl.ShopListId = %@", _docId]];
        if ([qry next])
        {
            strCountAll = [qry stringForColumn:@"CountAll"];
        }
        
        [qry close];
        
        [self.lblGoodsCountBought setText:strCountBought];
        [self.lblGoodsCountAll setText:strCountAll];
        [self.lblListSum setText:[NSString stringWithFormat:@"%@ руб", strAmount]];
    }
}

// сохранение состояний секций (категорий)
- (void)saveSectionsState
{
    _sectionsState = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < [_listData count]; i++)
    {
        NSString *categoryId = [[_listData objectAtIndex:i] valueForKey:@"CatId"];
        NSNumber *expanded = [[_listData objectAtIndex:i] valueForKey:@"CategoryExpanded"];
        
        [_sectionsState addObject:[[NSDictionary alloc] initWithObjectsAndKeys:categoryId, @"CatId", expanded, @"CategoryExpanded", nil]];
    }
}

// восстановление состояний секций
- (void)restoreSectionsState
{
    for (int i = 0; i < [_sectionsState count]; i++)
    {
        NSString *categoryId = [[_sectionsState objectAtIndex:i] valueForKey:@"CatId"];
        
        for (int j = 0; j < [_listData count]; j++)
        {
            NSMutableDictionary *section = (NSMutableDictionary *)[_listData objectAtIndex:j];
            
            if ([[section valueForKey:@"CatId"] isEqualToString:categoryId])
            {
                NSNumber *expanded = [(NSNumber *)[_sectionsState objectAtIndex:i] valueForKey:@"CategoryExpanded"];
                
                [section setValue:expanded forKey:@"CategoryExpanded"];
                
                break;
            }
        }
    }
}

// обработка горизонтального смахивания для отметки или отмены покупки
- (void)handleSwipeHorizontal:(UISwipeGestureRecognizer *)gestureRecognizer
{
    NSIndexPath *indexPath = [self.tvList indexPathForRowAtPoint:[gestureRecognizer locationInView:self.tvList]];
        
    if (indexPath != nil)
    {
        // доступ к глобальному объекту приложения
        LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        // необходимо подключение к локальной БД
        FMDatabase *db = appDelegate.localDB.db;
        
        if (db != nil)
        {
            NSMutableDictionary *row = [_listData objectAtIndex:indexPath.section];
            NSMutableArray *goods = (NSMutableArray *)[row valueForKey:@"Goods"];
            NSMutableDictionary *good = (NSMutableDictionary *)[goods objectAtIndex:indexPath.row];
            
            BOOL bought = [[good objectForKey:@"Bought"] boolValue];
        
            NSMutableDictionary *argsDict = [[NSMutableDictionary alloc] init];
            
            [argsDict setObject:[NSNumber numberWithBool:!bought] forKey:@"Bought"];
            [argsDict setObject:[NSDate date] forKey:@"EditDate"];
            [argsDict setObject:[good objectForKey:@"DocId"] forKey:@"DocId"];
            
            BOOL result = [db executeUpdate:@"UPDATE ShopListGoods \
                                              SET   Bought = :Bought \
                                                  , EditDate = :EditDate \
                                              WHERE DocId = :DocId" withParameterDictionary:argsDict];
            if (result)
            {
                // если требуется скрывать купленное - скрываем
                if (_boughtItemsHidden && !bought)
                {
                    [goods removeObjectAtIndex:indexPath.row];
                
                    [self.tvList beginUpdates];
                    [self.tvList deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationMiddle];
                    [self.tvList endUpdates];
                    
                    [self.tvList reloadData];
                }
                else
                {
                    [good setObject:[NSNumber numberWithBool:!bought] forKey:@"Bought"];
                    
                    // не требуется перемещать отмеченные позиции вниз списка
                    if (!_boughtItemsAtBottom || bought)
                    {
                        [self.tvList beginUpdates];
                        [self.tvList reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                        [self.tvList endUpdates];
                    }
                    // отмеченные позиции - вниз списка
                    else
                    {
                        if (!bought)
                        {
                            id object = [goods objectAtIndex:indexPath.row];
                            
                            [goods removeObjectAtIndex:indexPath.row];
                            [goods addObject:object];
                            
                            [self.tvList beginUpdates];
                            [self.tvList reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationMiddle];
                            [self.tvList endUpdates];
                        }
                        
                        [self.tvList reloadData];
                    }
                }
                
                // товар был отмечен до жеста смахивания - делаем список активным
                if (bought)
                {
                    if (!_active)
                    {
                        _active = YES;
                        
                        [self setListActive:_active];
                    }
                }
                // товар не был отмечен до жеста смахивания - проверяем, есть ли еще неотмеченные товары
                else
                {
                    BOOL prevActiveFlag = _active;
                    
                    _active = ![self checkAllGoodsBought];
                    
                    if (_active != prevActiveFlag)
                    {
                        [self setListActive:_active];
                    }
                }
                
                // обновляем подвал
                [self setListFooter];
            }
        }
    }
}

// обработка встряхивания
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (event.subtype == UIEventSubtypeMotionShake)
    {
        _boughtItemsHidden = !_boughtItemsHidden;
        
        [self loadListData];
    }
    
    if ([super respondsToSelector:@selector(motionEnded:withEvent:)])
        [super motionEnded:motion withEvent:event];
}

- (IBAction)saveListButton:(id)sender
{
    [self.slidingViewController anchorTopViewTo:ECLeft];
}

// запуск индикатора с задержкой
- (void)threadStartSpinning:(id)data
{
    // ждем 1 с
    [NSThread sleepForTimeInterval:1.0];
    
    // если через 1 с обработка данных еще не завершена, показываем индикатор
    if (_isBusy)
    {
        [self.spinner startAnimating];
    }
}

@end
