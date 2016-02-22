//
//  LDShopListsTableViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 24/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDShopListsTableViewController.h"

@interface LDShopListsTableViewController ()
{
    NSMutableArray *_data;              // данные списка
    NSMutableArray *_sectionsState;     // состояние секций - свернуты/развернуты
    
    BOOL _isBusy;   // флаг текущей обработки данных
    
    CGFloat _gridSectionHeight;     // высоты для секций и ячеек
    CGFloat _gridRowHeight;
    
    CGPoint _tableOffset;       // переменная для сохранения смещения таблицы при уходе с формы
}

@end

@implementation LDShopListsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // тянем настройки
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    _gridSectionHeight = [[defaults stringForKey:@"GridSectionHeight"] doubleValue];
    
    // обработка длительного нажатия для открытия меню
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lpgr.minimumPressDuration = 1.0;
    lpgr.delegate = self;
    [self.tvData addGestureRecognizer:lpgr];
    
    _isBusy = NO;
    
    // создаем индикатор, он невидим
    self.spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake((self.view.frame.size.width - 30.0) / 2.0, (self.view.frame.size.height - 30.0) / 2.0, 30, 30)];
    [self.spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:self.spinner];
    
    _tableOffset = CGPointMake(0.0f, 0.0f);
}

-(BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    // тянем настройки
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    _gridSectionHeight = [[defaults stringForKey:@"GridSectionHeight"] doubleValue];
    _gridRowHeight = [[defaults stringForKey:@"GridRowHeight"] doubleValue];
    
    // показываем нижнюю панель
    [self.tabBarController.tabBar setHidden:NO];
    
    // скрываем верхнюю
    [self.navigationController.navigationBar setHidden:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self loadData];
    
    // восстанавливаем смещение по вертикали и состояние секций
    self.tvData.contentOffset = _tableOffset;
    
    [self restoreSectionsState];
    
    [self.tvData reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    // сохраняем смещение по вертикали и состояние секций
    _tableOffset = self.tvData.contentOffset;
    
    [self saveSectionsState];
}

// перевод таблицы в режим редактирования и обратно
- (IBAction)editListButton:(id)sender
{
    if (self.editing)
    {
        [super setEditing:NO animated:YES];
        
        [self.tvData setEditing:NO animated:YES];
        [self.tvData reloadData];
        
        self.editDoneButton.title = @"Изменить";
        [self.editDoneButton setStyle:UIBarButtonItemStylePlain];
    
        NSMutableArray  *items = [self.toolbar.items mutableCopy];
        [items addObject: self.addButton];
        self.toolbar.items = items;
    }
    else
    {
        [super setEditing:YES animated:YES];
        
        [self.tvData setEditing:YES animated:YES];
        [self.tvData reloadData];
        
        self.editDoneButton.title = @"Готово";
        [self.editDoneButton setStyle:UIBarButtonItemStyleDone];
        
        NSMutableArray  *items = [self.toolbar.items mutableCopy];
        [items removeObject: self.addButton];
        self.toolbar.items = items;
    }
}

////////////////////////
// Фильтрация списков //
////////////////////////

// при изменении настройки фильтрации тянем данные
- (IBAction)scListsFilterValueChanged:(id)sender
{
    [self loadData];
    
    [self restoreSectionsState];
    
    [self.tvData reloadData];
}

//////////////////////////////////////////////////
// сохранение и восстановление состояния секций //
//////////////////////////////////////////////////

// сохранение состояний секций (списки по месяцам)
- (void)saveSectionsState
{
    _sectionsState = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < [_data count]; i++)
    {
        NSString *sectionName = [[_data objectAtIndex:i] valueForKey:@"MonthName"];
        NSNumber *expanded = [[_data objectAtIndex:i] valueForKey:@"SectionExpanded"];
        
        [_sectionsState addObject:[[NSDictionary alloc] initWithObjectsAndKeys:sectionName, @"MonthName", expanded, @"SectionExpanded", nil]];
    }
}

// восстановление состояний секций
- (void)restoreSectionsState
{
    for (int i = 0; i < [_sectionsState count]; i++)
    {
        NSString *sectionName = [[_sectionsState objectAtIndex:i] valueForKey:@"MonthName"];
        
        for (int j = 0; j < [_data count]; j++)
        {
            NSMutableDictionary *section = (NSMutableDictionary *)[_data objectAtIndex:j];
            
            if ([[section valueForKey:@"MonthName"] isEqualToString:sectionName])
            {
                NSNumber *expanded = [(NSNumber *)[_sectionsState objectAtIndex:i] valueForKey:@"SectionExpanded"];
                
                [section setValue:expanded forKey:@"SectionExpanded"];
                
                break;
            }
        }
    }
}

/////////////////////////
// Взаимодействие с БД //
/////////////////////////

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

// извлечение данных из БД
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
            NSDateComponents *today = [[NSCalendar currentCalendar] components:(NSCalendarUnitMonth | NSCalendarUnitYear) fromDate:[NSDate date]];
            
            NSString *monthsSelect = @"";
            
            // только списки текущего месяца
            if (self.scListsFilter.selectedSegmentIndex == 0)
            {
                NSInteger prevMonth, prevYear;
                
                if (today.month == 1)
                {
                    prevMonth = 12;
                    prevYear = today.year - 1;
                }
                else
                {
                    prevMonth = today.month - 1;
                    prevYear = today.year;
                }
                
                monthsSelect = [NSString stringWithFormat:@"SELECT DISTINCT year, month \
                                                            FROM (SELECT   CAST(strftime('%%Y', datetime(ShoppingDate, 'unixepoch')) AS INT) AS year \
                                                                         , CAST(strftime('%%m', datetime(ShoppingDate, 'unixepoch')) AS INT) AS month \
                                                                  FROM ShopLists) tbl \
                                                            WHERE    (    year = %d \
                                                                      and month = %d) \
                                                                  or (    year = %d \
                                                                      and month = %d) \
                                                            ORDER BY year DESC, month DESC", (int)today.year, (int)today.month, (int)prevYear, (int)prevMonth];
            }
            // все списки
            else
            {
                monthsSelect = @"SELECT DISTINCT year, month \
                                 FROM (SELECT   CAST(strftime('%Y', datetime(ShoppingDate, 'unixepoch')) AS INT) AS year \
                                              , CAST(strftime('%m', datetime(ShoppingDate, 'unixepoch')) AS INT) AS month \
                                       FROM ShopLists) tbl \
                                 ORDER BY year DESC, month DESC";
            }
            
            FMResultSet *qryMonths = [db executeQuery:monthsSelect];
            
            _data = [[NSMutableArray alloc] init];
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"ru_RU"];
            
            while ([qryMonths next])
            {
                NSString *sectionName;
                BOOL sectionExpanded = NO;
                
                int year = [qryMonths intForColumn:@"year"];
                int month = [qryMonths intForColumn:@"month"];
                
                if ((today.year == year) && (today.month == month))
                {
                    sectionName = @"В этом месяце";
                    sectionExpanded = YES;
                }
                else
                    if (((today.year == year) && ((today.month - 1) == month)) || (((today.year - 1) == year) && (today.month == 1) && (month == 12)))
                    {
                        sectionName = @"В прошлом месяце";
                        sectionExpanded = YES;
                    }
                    else
                    {
                        sectionName = [NSString stringWithFormat:@"%@ %d", [[dateFormatter standaloneMonthSymbols] objectAtIndex:(month - 1)], year];
                    }
                
                NSMutableDictionary *monthSection = [[NSMutableDictionary alloc] init];
                
                [monthSection setValue:sectionName forKey:@"MonthName"];
                [monthSection setValue:[NSNumber numberWithBool:sectionExpanded] forKey:@"SectionExpanded"];
                
                // отбираем списки, относящиеся к месяцу
                NSString *select = [NSString stringWithFormat:@"SELECT   sl.DocId \
                                                                       , sl.Name \
                                                                       , IFNULL(sl.ShoppingDate, '') as ShoppingDate \
                                                                       , IFNULL(s.Name, '') as ShopName \
                                                                       , IFNULL(tbl.Amount, 0) as Amount \
                                                                       , IFNULL(sl.Active, 0) as Active \
                                                                FROM ShopLists sl \
                                                                        LEFT JOIN REF_Shops s \
                                                                            ON sl.ShopId = s.DocId \
                                                                        LEFT JOIN (SELECT slg.ShopListId, SUM(IFNULL(slg.Amount, 0.0)) as Amount \
                                                                                   FROM ShopListGoods slg \
                                                                                   GROUP BY slg.ShopListId) tbl  \
                                                                            ON tbl.ShopListId = sl.DocId \
                                                                WHERE     CAST(strftime('%%Y', datetime(sl.ShoppingDate, 'unixepoch')) AS INT) = %d \
                                                                      and CAST(strftime('%%m', datetime(ShoppingDate, 'unixepoch')) AS INT) = %d \
                                                                ORDER BY sl.ShoppingDate DESC", year, month];
                
                FMResultSet *qryLists = [db executeQuery:select];
                
                NSMutableArray *lists = [[NSMutableArray alloc] init];
                
                while([qryLists next])
                {
                    NSString *docId = [qryLists stringForColumn:@"DocId"];
                    NSString *name = [qryLists stringForColumn:@"Name"];
                    NSString *shopName = [qryLists stringForColumn:@"ShopName"];
                    
                    NSString *strShoppingDate = [qryLists stringForColumn:@"ShoppingDate"];
                    if (![strShoppingDate isEqualToString:@""])
                    {
                        NSDate *shoppingDate = [qryLists dateForColumn:@"ShoppingDate"];
                        
                        NSDateFormatter *dateFormats = [[NSDateFormatter alloc] init];
                        [dateFormats setDateFormat:@"dd.MM.yyyy"];
                        strShoppingDate = [dateFormats stringFromDate:shoppingDate];
                    }
                    
                    NSNumber *amount = [NSNumber numberWithDouble:[qryLists doubleForColumn:@"Amount"]];
                    NSNumber *active = [NSNumber numberWithBool:[qryLists boolForColumn:@"Active"]];
                    
                    NSMutableDictionary *ref = [NSMutableDictionary dictionaryWithObjectsAndKeys:docId, @"DocId", name, @"Name", shopName, @"ShopName", strShoppingDate, @"ShoppingDate", amount, @"Amount", active, @"Active", nil];
                    
                    [lists addObject:ref];
                }
                
                [monthSection setValue:lists forKey:@"Lists"];
                
                [qryLists close];
                
                [_data addObject:monthSection];
            }
            
            [qryMonths close];
        }
        
        [self.tvData reloadData];
    }
    @finally
    {
        _isBusy = NO;
        
        [self.spinner stopAnimating];
    }
}

// удаление списка
- (BOOL)deleteList:(NSString *)docId
{
    BOOL result = NO;
    
    // доступ к глобальному объекту приложения
    LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // необходимо подключение к локальной БД
    FMDatabase *db = appDelegate.localDB.db;
    
    if (db != nil)
    {
        result = [db executeUpdate:@"DELETE FROM ShopListGoods WHERE ShopListId = ?", docId, nil];
        
        if (result)
        {
            result = [db executeUpdate:@"DELETE FROM ShopLists WHERE DocId = ?", docId, nil];
        
            if (!result)
            {
                UIAlertView *info = [[UIAlertView alloc] initWithTitle:@"Ошибка при удалении"
                                                               message:db.lastErrorMessage
                                                              delegate:nil
                                                     cancelButtonTitle:@"OK"
                                                     otherButtonTitles:nil];
                [info show];
            }
        }
        else
        {
            UIAlertView *info = [[UIAlertView alloc] initWithTitle:@"Ошибка при удалении"
                                                           message:db.lastErrorMessage
                                                          delegate:nil
                                                 cancelButtonTitle:@"OK"
                                                 otherButtonTitles:nil];
            [info show];
        }
    }
    
    return result;
}

/////////////////////////////////////////////
// Реализация делегата UITableViewDelegate //
/////////////////////////////////////////////

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return _gridSectionHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return _gridRowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"ShopsListCellItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *monthSection = [_data objectAtIndex:indexPath.section];
    NSArray *lists = [monthSection objectForKey:@"Lists"];
    NSDictionary *list = [lists objectAtIndex:indexPath.row];
    
    UILabel *lblDate = (UILabel *)[cell viewWithTag:1];
    lblDate.text = [list objectForKey:@"ShoppingDate"];
    
    UILabel *lblAmount = (UILabel *)[cell viewWithTag:2];
    lblAmount.text = [NSString stringWithFormat:@"%.2f руб", [[list objectForKey:@"Amount"] doubleValue]];

    UILabel *lblName = (UILabel *)[cell viewWithTag:3];
    lblName.text = [list objectForKey:@"Name"];
    
    UILabel *lblShopName = (UILabel *)[cell viewWithTag:4];
    [lblShopName setHidden:NO];
    lblShopName.text = [list objectForKey:@"ShopName"];
 
    
    // активен ли список
    BOOL active = [[list objectForKey:@"Active"] boolValue];
    
    if (active)
    {
        [lblDate setTextColor:[UIColor blackColor]];
        [lblAmount setTextColor:[UIColor blackColor]];
        [lblName setTextColor:[UIColor blackColor]];
        [lblShopName setTextColor:[UIColor blackColor]];
    }
    else
    {
        [lblDate setTextColor:[UIColor lightGrayColor]];
        [lblAmount setTextColor:[UIColor lightGrayColor]];
        [lblName setTextColor:[UIColor lightGrayColor]];
        [lblShopName setTextColor:[UIColor lightGrayColor]];
    }
    
    return cell;
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
        // не допускаем повторного запуска процесса
        if (!_isBusy)
        {
            [NSThread detachNewThreadSelector:@selector(threadStartSpinning:) toTarget:self withObject:nil];
        }
        
        _isBusy = YES;
        
        @try
        {
            NSDictionary *monthSection = [_data objectAtIndex:indexPath.section];
            NSMutableArray *lists = [monthSection objectForKey:@"Lists"];
            NSDictionary *list = [lists objectAtIndex:indexPath.row];
            
            NSString *docId = [list objectForKey:@"DocId"];
            
            // удалили из БД - удаляем из таблицы
            if ([self deleteList:docId])
            {
                [lists removeObjectAtIndex:indexPath.row];
            }
            
            [self.tvData reloadData];
        }
        @finally
        {
            _isBusy = NO;
            
            [self.spinner stopAnimating];
        }
    }
}

// число записей в секции
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
{
    NSDictionary *monthSection = (NSDictionary *)[_data objectAtIndex:sectionIndex];
    
    if ([[monthSection valueForKey:@"SectionExpanded"] boolValue])
    {
        return [(NSArray *)[monthSection valueForKey:@"Lists"] count];
    }
    else return 0;
}

// число секций в таблице
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_data count];
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
    NSDictionary *monthSection = (NSDictionary *)[_data objectAtIndex:section];
    NSArray *lists = (NSArray *)[monthSection objectForKey:@"Lists"];
    
    if ([lists count] > 0)
    {
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, _gridSectionHeight)];
        [headerView setBackgroundColor:[UIColor whiteColor]];
        
        UIImage *imgShowHide;
        
        if ([[monthSection valueForKey:@"SectionExpanded"] boolValue])
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
        [btnShowHide setBackgroundColor:[UIColor lightGrayColor]];
        [btnShowHide setTag:section];
        [btnShowHide setImage:imgShowHide forState:UIControlStateNormal];
        [btnShowHide addTarget:self action:@selector(sectionShowHideButtonTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
        
        [headerView addSubview:btnShowHide];
        
        // наименование категории
        CGRect rectHeaderLabel = CGRectMake(rectShowHide.origin.x + rectShowHide.size.width, 1.0, self.view.frame.size.width - (rectShowHide.origin.x + rectShowHide.size.width + 1.0), _gridSectionHeight - 1.0);
        
        UILabel* headerLabel = [[UILabel alloc] init];
        [headerLabel setUserInteractionEnabled:YES];
        [headerLabel setFrame:rectHeaderLabel];
        [headerLabel setBackgroundColor:[UIColor lightGrayColor]];
        [headerLabel setTag:section];
        [headerLabel setTextColor:[UIColor blackColor]];
        [headerLabel setFont:[UIFont boldSystemFontOfSize:17.0]];
        [headerLabel setText:[monthSection valueForKey:@"MonthName"]];
        // будем обрабатывать тапы по названию категории
        UITapGestureRecognizer *labelTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(sectionLabelTapped:)];
        labelTap.numberOfTapsRequired = 1;
        [headerLabel addGestureRecognizer:labelTap];
        
        [headerView addSubview:headerLabel];
        
        return headerView;
    }
    else return nil;
}

// тап по названию секции
- (void)sectionLabelTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    UILabel *lblSection = (UILabel *)gestureRecognizer.view;
    
    [self expandCollapseSection:lblSection.tag];
}

// тап по кнопке "свернуть/разварнуть"
- (void)sectionShowHideButtonTouchUpInside:(UIButton*)sender
{
    [self expandCollapseSection:sender.tag];
}

//////////////////////////////////
// Обработка переходов по segue //
//////////////////////////////////

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // добавление
    if ([segue.identifier isEqualToString:@"newListSegue"])
    {
        LDShopListEditViewController *destView = segue.destinationViewController;
        
        [destView setNewListMode];
    }
    else
        // редактирование или удаление
        if ([segue.identifier isEqualToString:@"editListSegue"])
        {
            NSDictionary *monthSection = (NSDictionary *)[_data objectAtIndex:self.tvData.indexPathForSelectedRow.section];
            NSArray *lists = (NSArray *)[monthSection objectForKey:@"Lists"];
            NSDictionary *list = [lists objectAtIndex:self.tvData.indexPathForSelectedRow.row];
            
            LDShopListEditViewController *destView = segue.destinationViewController;

            [destView setEditListMode:[list valueForKey:@"DocId"]];
        }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"editListSegue"])
    {
        return (self.tvData.indexPathForSelectedRow != nil);
    }
    else return YES;
}

/////////////////////////////////////////////////////
// Реализация делегата UIGestureRecognizerDelegate //
/////////////////////////////////////////////////////

// обработка длительного нажатия для открытия меню
- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {      
        NSIndexPath *pressedIndexPath = [self.tvData indexPathForRowAtPoint:[gestureRecognizer locationInView:self.tvData]];
        
        if (pressedIndexPath && (pressedIndexPath.row != NSNotFound))
        {
            [self becomeFirstResponder];
            
            NSDictionary *monthSection = (NSDictionary *)[_data objectAtIndex:pressedIndexPath.section];
            NSArray *lists = (NSArray *)[monthSection objectForKey:@"Lists"];
            NSDictionary *list = [lists objectAtIndex:pressedIndexPath.row];
            
            BOOL active = [[list objectForKey:@"Active"] boolValue];
            
            LDCellMenuItem *copyMenuItem = [[LDCellMenuItem alloc] initWithTitle:@"Копировать" action:@selector(copyShopListMenuItemPressed:)];
            copyMenuItem.indexPath = pressedIndexPath;
            
            NSString *title;

            if (active)
            {
                title = @"Закрыть";
            }
            else
            {
                title = @"Активировать";
            }
            
            LDCellMenuItem *activateMenuItem = [[LDCellMenuItem alloc] initWithTitle:title action:@selector(activateShopListMenuItemPressed:)];
            activateMenuItem.indexPath = pressedIndexPath;

            LDCellMenuItem *sendMenuItem = [[LDCellMenuItem alloc] initWithTitle:@"Отправить" action:@selector(sendShopListMenuItemPressed:)];
            sendMenuItem.indexPath = pressedIndexPath;
            
            UIMenuController *menuController = [UIMenuController sharedMenuController];
            menuController.menuItems = @[copyMenuItem, activateMenuItem, sendMenuItem];
            
            CGRect cellRect = [self.tvData rectForRowAtIndexPath:pressedIndexPath];
            
            [menuController setTargetRect:cellRect inView:self.tvData];
            [menuController setMenuVisible:YES animated:YES];
        }
    }
}

// копирование списка
- (void)copyShopListMenuItemPressed:(UIMenuController *)menuController
{
    LDCellMenuItem *menuItem = [[UIMenuController sharedMenuController] menuItems][0];
    
    // строка таблицы выбрана
    if (menuItem.indexPath)
    {
        [self resignFirstResponder];
    
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
                NSDictionary *monthSection = (NSDictionary *)[_data objectAtIndex:menuItem.indexPath.section];
                NSArray *lists = (NSArray *)[monthSection objectForKey:@"Lists"];
                NSDictionary *list = [lists objectAtIndex:menuItem.indexPath.row];
                
                // код исходного списка
                NSString *sourceDocId = [list objectForKey:@"DocId"];
                
                NSString *newListName = [NSString stringWithFormat:@"%@ (копия)", [list objectForKey:@"Name"]];
                
                NSMutableDictionary *argsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:newListName, @"Name",
                                                                                [newListName lowercaseString], @"Name_lower",
                                                                                                [NSDate date], @"ShoppingDate",
                                                                                [NSNumber numberWithBool:YES], @"Active",
                                                                                                [NSDate date], @"CreateDate",
                                                                                                  sourceDocId, @"SourceDocId", nil];
                
                BOOL result = [db executeUpdate:@"INSERT INTO ShopLists (Name, Name_lower, ShopId, ShoppingDate, Active, CreateDate) \
                                                  SELECT :Name as Name, :Name_lower as Name_lower, ShopId, :ShoppingDate as ShoppingDate, :Active as Active, :CreateDate as CreateDate \
                                                  FROM ShopLists \
                                                  WHERE DocId = :SourceDocId" withParameterDictionary:argsDict];
                
                if (result)
                {
                    // теперь нужно определить новый DocId
                    FMResultSet *docId_result = [db executeQuery:@"SELECT last_insert_rowid() as NewDocId"];
                    
                    // определили - копируем табличную часть
                    if ([docId_result next])
                    {
                        NSString *copyDocId = [docId_result stringForColumn:@"NewDocId"];
                        
                        argsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:copyDocId, @"newListId", [NSNumber numberWithBool:NO], @"Bought", [NSDate date], @"CreateDate", sourceDocId, @"SourceDocId", nil];
                        
                        result = [db executeUpdate:@"INSERT INTO ShopListGoods (ShopListId, GoodId, Qty, Amount, Bought, CreateDate) \
                                                     SELECT :newListId as ShopListId, GoodId, Qty, Amount, :Bought as Bought, :CreateDate as CreateDate \
                                                     FROM ShopListGoods \
                                                     WHERE ShopListId = :SourceDocId" withParameterDictionary:argsDict];
                        // обновляем список
                        [self loadData];
                    }
                    
                    [docId_result close];
                }
                else
                {
                    UIAlertView *info = [[UIAlertView alloc] initWithTitle:@"Ошибка при копировании"
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
}

// активирование/деактивирование списка
- (void)activateShopListMenuItemPressed:(UIMenuController *)menuController
{
    LDCellMenuItem *menuItem = [[UIMenuController sharedMenuController] menuItems][0];
    
    // строка таблицы выбрана
    if (menuItem.indexPath)
    {
        [self resignFirstResponder];
        
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
                NSDictionary *monthSection = (NSDictionary *)[_data objectAtIndex:menuItem.indexPath.section];
                NSArray *lists = (NSArray *)[monthSection objectForKey:@"Lists"];
                NSMutableDictionary *list = [lists objectAtIndex:menuItem.indexPath.row];
                
                // код списка
                NSString *docId = [list objectForKey:@"DocId"];
                
                BOOL result = [db executeUpdate:[NSString stringWithFormat:@"UPDATE ShopLists \
                                                                             SET Active = NOT IFNULL(Active, 0) \
                                                                             WHERE DocId = %@", docId ]];
                
                if (result)
                {
                    BOOL active = [[list objectForKey:@"Active"] boolValue];
                    
                    [list setValue:[NSNumber numberWithBool:!active] forKey:@"Active"];
                    
                    [self.tvData reloadData];
                }
                else
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
}

// отправка списка по e-mail
- (void)sendShopListMenuItemPressed:(UIMenuController *)menuController
{
    LDCellMenuItem *menuItem = [[UIMenuController sharedMenuController] menuItems][0];
    
    // строка таблицы выбрана
    if (menuItem.indexPath)
    {
        [self resignFirstResponder];
        
        // не допускаем повторного запуска процесса
        if (!_isBusy)
        {
            [NSThread detachNewThreadSelector:@selector(threadStartSpinning:) toTarget:self withObject:nil];
        }
        
        _isBusy = YES;
        
        @try
        {
            NSDictionary *monthSection = (NSDictionary *)[_data objectAtIndex:menuItem.indexPath.section];
            NSArray *lists = (NSArray *)[monthSection objectForKey:@"Lists"];
            NSMutableDictionary *list = [lists objectAtIndex:menuItem.indexPath.row];
            
            // код списка
            NSString *docId = [list objectForKey:@"DocId"];
            
            // формируем XML-данные
            NSData *xmlData = [LDShopListXML createXMLDataByList:docId];
            
            if (xmlData != nil)
            {
                NSString *fileName = [NSString stringWithFormat:@"ShopList%@.lsl", docId];
                
                // сохраняем данные в файл
                if ([LDShopListXML saveXMLDataToFile:xmlData withName:fileName])
                {

                    MFMailComposeViewController *composer = [[MFMailComposeViewController alloc] init];
                    [composer setMailComposeDelegate:self];
                    
                    if ([MFMailComposeViewController canSendMail])
                    {
                        //[composer setToRecipients:[NSArray arrayWithObjects:_developerEMail, nil]];
                        [composer setSubject:@"Список покупок (LynxShopList)"];
                        
                        [composer addAttachmentData:xmlData mimeType:@"application/lynxshoplist" fileName:fileName];
                        
                        [composer setMessageBody:@"" isHTML:NO];
                        [composer setModalTransitionStyle:UIModalTransitionStyleCrossDissolve];
                        
                        [self presentViewController:composer animated:YES completion:nil];
                    }
                    
                }
            }
            else
            {
                UIAlertView *info = [[UIAlertView alloc] initWithTitle:@"Ошибка"
                                                               message:@"Не удалось сохранить файл"
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
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    UIAlertView *info;
    
    if (result == MFMailComposeResultSent)
    {
        info = [[UIAlertView alloc] initWithTitle:@""
                                          message:@"Список успешно отправлен"
                                         delegate:self
                                cancelButtonTitle:@"OK"
                                otherButtonTitles:nil, nil];
    }
    else
    {
        info = [[UIAlertView alloc] initWithTitle:@""
                                          message:@"Список не был отправлен"
                                         delegate:self
                                cancelButtonTitle:@"OK"
                                otherButtonTitles:nil, nil];
    }
    
    [info show];
    
    [controller dismissViewControllerAnimated:YES completion:nil];
}


// процедура сворачивания/развертывания секции
- (void)expandCollapseSection:(long)section
{
    NSMutableDictionary *monthSection = (NSMutableDictionary *)[_data objectAtIndex:section];
    BOOL sectionExpanded = ![[monthSection valueForKey:@"SectionExpanded"] boolValue];
    
    [monthSection setObject:[NSNumber numberWithBool:sectionExpanded] forKey:@"SectionExpanded"];
    
    [self.tvData reloadData];
}

@end
