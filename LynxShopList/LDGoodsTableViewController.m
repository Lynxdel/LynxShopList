//
//  LDGoodsTableViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 20/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDGoodsTableViewController.h"

@interface LDGoodsTableViewController ()
{
    NSMutableArray *_data;
    
    BOOL _isBusy;               // флаг текущей обработки данных
    
    BOOL _isReferenceMode;      // флаг режима справочника (по умолчанию - NO)
    
    NSString *_shopListId;      // код редактируемого списка (в режиме справочника)
    
    CGFloat _gridSectionHeight;     // высоты для секций и ячеек
    CGFloat _gridRowHeight;
    
    NSIndexPath *_openedGoodIndexPath;   // ссылка на товар, карточка которого была открыта и из которой произошел возврат
    
    NSIndexPath *_cellGestureStarted;    // переменная для хранения адреса ячейки, в которой начался жест
    NSMutableDictionary *_editedGood;    // редактируемый товар (меняется количество и стоимость)
    double _editGoodStartQty;
    double _editGoodIncQty;
    CGPoint _gestureStartPoint;          // начальная точка жеста добавления
    
    BOOL _filterByCategories;               // управление фильтрацией категорий
    NSMutableArray *_filterCategoryIds;
}

@end

@implementation LDGoodsTableViewController

@synthesize parentViewDelegate;

//////////////////
// события view //
//////////////////

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _openedGoodIndexPath = nil;
    
    // создаем индикатор, он невидим
    self.spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake((self.view.frame.size.width - 30.0) / 2.0, (self.view.frame.size.height - 30.0) / 2.0, 30, 30)];
    [self.spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:self.spinner];
    
    // переименовываем кнопку "Cancel"
    for(UIView *subView in self.searchBar.subviews)
    {
        for (UIView *subSubview in subView.subviews)
        {
            if ([subSubview isKindOfClass:[UIButton class]])
            {
                UIButton *cancelButton = (UIButton*)subSubview;
                
                [cancelButton setTitle:@"Отмена" forState:UIControlStateNormal];
                
                break;
            }
        }
    }
    
    UIPanGestureRecognizer *cellPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleCellPan:)];
    cellPan.delegate = self;
    [self.tvData addGestureRecognizer:cellPan];
    
    // тянем настройки
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    _gridSectionHeight = [[defaults stringForKey:@"GridSectionHeight"] doubleValue];
    _gridRowHeight = [[defaults stringForKey:@"GridRowHeight"] doubleValue];
    
    [self loadData:@"" showSectionsExpanded:NO];    
}

-(void)viewDidLayoutSubviews
{
    // определяем, какие кнопки будут отображаться на нижнем тулбаре
    NSMutableArray *toolbarButtons = [[NSMutableArray alloc] initWithArray:self.toolbar.items];
    
    if (_isReferenceMode)
    {
        // в режиме справочника не даем удалять элементы
        [toolbarButtons removeObject:self.editDoneButton];
    }
    
    if (!_filterByCategories)
    {
        // кнопки показа/сокрытия категорий нет
        [toolbarButtons removeObject:self.btnFilter];
    }
    
    [self.toolbar setItems:toolbarButtons];
    
    // если удалил обе кнопки, остается разделитель
    if (self.toolbar.items.count == 1)
    {
        // кнопок не осталось - прячем тулбар
        [self.toolbar setHidden:YES];
        
        // таблицу растягиваем до нижней части формы
        CGRect tableViewRect = self.tvData.frame;
        tableViewRect.size.height += self.toolbar.frame.size.height;
        
        [self.tvData setFrame:tableViewRect];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    // если вернулись из карточки товара, обновляем таблицу
    if (_openedGoodIndexPath)
    {
        [self reloadListDataAt:_openedGoodIndexPath];
        
        _openedGoodIndexPath = nil;
    }
    
    // прячем нижнюю панель
    [self.tabBarController.tabBar setHidden:YES];
    
    // показываем верхнюю
    [self.navigationController.navigationBar setHidden:NO];
}

// для сокрытия клавиатуры
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.searchBar resignFirstResponder];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

////////////
// кнопки //
////////////

// перевод таблицы в режим удаления элементов и обратно
- (IBAction)editListButton:(id)sender
{
    if (self.editing)
    {
        [super setEditing:NO animated:YES];
        
        [self.tvData setEditing:NO animated:YES];
        [self.tvData reloadData];
        
        self.editDoneButton.title = @"Изменить";
        [self.editDoneButton setStyle:UIBarButtonItemStylePlain];
        
        self.navigationItem.rightBarButtonItem = self.addButton;
    }
    else
    {
        [super setEditing:YES animated:YES];
        
        [self.tvData setEditing:YES animated:YES];
        [self.tvData reloadData];
        
        self.editDoneButton.title = @"Готово";
        [self.editDoneButton setStyle:UIBarButtonItemStyleDone];
        
        self.navigationItem.rightBarButtonItem = nil;
    }
}

//////////////////////
// работа с данными //
//////////////////////

// извлечение данных из БД
// предусмотрен параметр для поиска, но контролы для поиска были удалены
- (void)loadData:(NSString *)namesLike showSectionsExpanded:(BOOL)expanded;
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
            NSString *where = @"";
            
            if (![namesLike isEqualToString:@""])
            {
                where = [NSString stringWithFormat:@" and g.Name_lower LIKE '%%%@%%'", [namesLike lowercaseString]];
            }
            
            // предустановленный фильтр по категориям
            if (_filterByCategories)
                if (_filterCategoryIds != nil)
                {
                    for (int i = 0; i < _filterCategoryIds.count; i++)
                    {
                        where = [NSString stringWithFormat:@" %@ and (g.CategoryId = %@)", where, [_filterCategoryIds objectAtIndex:i]];
                    }
                }
            
            // отбираем категории
            FMResultSet *qryCats = [db executeQuery:[NSString stringWithFormat:@"SELECT DISTINCT   IFNULL(g.CategoryId, 0) AS CategoryId \
                                                                                                 , IFNULL(gc.Name, '') AS CategoryName \
                                                                                                 , IFNULL(gc.ColorR, 1.0) as R \
                                                                                                 , IFNULL(gc.ColorG, 1.0) as G \
                                                                                                 , IFNULL(gc.ColorB, 1.0) as B \
                                                                                                 , IFNULL(gc.ColorAlpha, 1.0) as A \
                                                                                 FROM REF_Goods g \
                                                                                        LEFT JOIN REF_GoodCategories gc \
                                                                                            ON g.CategoryId = gc.DocId \
                                                                                 WHERE (1 = 1) %@ \
                                                                                 ORDER BY IFNULL(gc.Name, '')", where]];
            
            _data = [[NSMutableArray alloc] init];
            
            while([qryCats next])
            {
                NSString *catId = [qryCats stringForColumn:@"CategoryId"];
                NSString *catName = [qryCats stringForColumn:@"CategoryName"];
                
                if ((_shopListId == nil) || [_shopListId isEqualToString:@""])
                {
                    _shopListId = @"0";
                }
                
                // товары категории
                // в режиме справочника присоединяем редактируемый список - вытаскиваем из него количества
                FMResultSet *qryGoods = [db executeQuery:[NSString stringWithFormat:@"SELECT   g.DocId, g.Name \
                                                                                             , IFNULL(g.MeasureId, 0) as MeasureId \
                                                                                             , IFNULL(m.Name, '') as MeasureName, IFNULL(m.Name234, '') as MeasureName234, IFNULL(m.Name567890, '') as MeasureName567890 \
                                                                                             , IFNULL(g.Price, 0) as PriceFromRef \
                                                                                             , IFNULL(slg.Price, 0) as PriceFromList \
                                                                                             , IFNULL(slg.Qty, 0) as Qty \
                                                                                             , IFNULL(m.IncQty, 0) as IncQty \
                                                                                      FROM REF_Goods g \
                                                                                            LEFT JOIN REF_Measures m \
                                                                                                ON m.DocId = g.MeasureId \
                                                                                            LEFT JOIN ShopListGoods slg \
                                                                                                ON     slg.ShopListId = %@ \
                                                                                                   and slg.GoodId = g.DocId \
                                                                                      WHERE (IFNULL(g.CategoryId, 0) = %@) %@ \
                                                                                      ORDER BY g.Name", _shopListId, catId, where]];
                
                NSMutableDictionary *row = [[NSMutableDictionary alloc] init];
                NSMutableArray *goods = [[NSMutableArray alloc] init];
                
                [row setObject:catId forKey:@"CatId"];
                [row setObject:catName forKey:@"CatName"];
                
                // цвет категории
                double r = [qryCats doubleForColumn:@"R"];
                double g = [qryCats doubleForColumn:@"G"];
                double b = [qryCats doubleForColumn:@"B"];
                double a = [qryCats doubleForColumn:@"A"];
                
                UIColor *catColor = [UIColor colorWithRed:r green:g blue:b alpha:a];
                
                [row setObject:catColor forKey:@"Color"];
                
                // признак свернутой/рвзвернутой секции категории
                [row setObject:[NSNumber numberWithBool:expanded] forKey:@"CategoryExpanded"];
                
                while ([qryGoods next])
                {
                    NSString *goodId = [qryGoods stringForColumn:@"DocId"];
                    NSString *goodName = [qryGoods stringForColumn:@"Name"];
                    NSString *measureId = [qryGoods stringForColumn:@"MeasureId"];
                    NSString *measureName = [qryGoods stringForColumn:@"MeasureName"];
                    NSString *measureName234 = [qryGoods stringForColumn:@"MeasureName234"];
                    NSString *measureName567890 = [qryGoods stringForColumn:@"MeasureName567890"];
                    NSNumber *qty = [NSNumber numberWithDouble:[qryGoods doubleForColumn:@"Qty"]];
                    NSNumber *incQty = [NSNumber numberWithDouble:[qryGoods doubleForColumn:@"IncQty"]];
                    
                    BOOL addedToList = ([qty doubleValue] != 0.0);  // кол-во в редактируемом списке не равно 0 - товар добавлен с список
                    
                    NSNumber *price;
                    
                    // режим спраовочника для добавления товаров в список
                    if (_isReferenceMode)
                    {
                        // товар добавлен в список - берем цену из списка
                        if (addedToList)
                        {
                            price = [NSNumber numberWithDouble:[qryGoods doubleForColumn:@"PriceFromList"]];
                        }
                        // товара нет в списке - цена из справочника
                        else
                        {
                            price = [NSNumber numberWithDouble:[qryGoods doubleForColumn:@"PriceFromRef"]];
                        }
                    }
                    // табличный режим - цена из справочника
                    else
                    {
                        price = [NSNumber numberWithDouble:[qryGoods doubleForColumn:@"PriceFromRef"]];
                    }
                    
                    [goods addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:goodId, @"DocId",
                                                                                     goodName, @"Name",
                                                                                    measureId, @"MeasureId",
                                                                                  measureName, @"MeasureName",
                                                                               measureName234, @"MeasureName234",
                                                                            measureName567890, @"MeasureName567890",
                                                                                        price, @"Price",
                                                                                          qty, @"Qty",
                                                                                       incQty, @"IncQty",
                                                        [NSNumber numberWithBool:addedToList], @"AddedToList", nil]];
                }
                
                [row setObject:goods forKey:@"Goods"];
                
                // итоговый массив
                [_data addObject:row];
            }
        }
        
        [self.tvData reloadData];
    }
    @finally
    {
        _isBusy = NO;
        
        [self.spinner stopAnimating];
    }
}

// удаление записи
- (BOOL)deleteElement:(NSString *)docId
{
    BOOL result = NO;
    
    // доступ к глобальному объекту приложения
    LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if ([appDelegate.localDB canDeleteGood:docId])
    {
        result = [appDelegate.localDB deleteRecordByDocId:docId from:@"REF_Goods"];
    }
    else
    {
        UIAlertView *info = [[UIAlertView alloc] initWithTitle:nil
                                                       message:@"Товар используется в списках"
                                                      delegate:nil
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
        [info show];
    }
    
    return result;
}

/////////////////////////////////
// делегат UISearchBarDelegate //
/////////////////////////////////

-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self loadData:searchText showSectionsExpanded:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    
    [searchBar setText:nil];
    
    [self loadData:@"" showSectionsExpanded:NO];
}

/////////////////////////////////
// делегат UITableViewDelegate //
/////////////////////////////////

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return _gridSectionHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return _gridRowHeight;
}

// ячейки - товары
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"GoodCellItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        
        // в левой части ячейки узкая цветная полоска
        UIView *colorStripeView = [[UIView alloc] initWithFrame:CGRectMake(1.0, 1.0, cell.contentView.frame.size.width * 0.025, cell.contentView.frame.size.height - 2.0)];
        [colorStripeView setTag:1];
        
        [cell.contentView addSubview:colorStripeView];
        
        // выводим галку, как бы намекающую на то, что по тапу будет открыта форма редактирования (didSelectRowAtIndexPath)
        // в режиме выбора из справочника тап - выбор элемента, галку справа убираем
        if (!_isReferenceMode)
        {
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        }
        // в режиме справочника ячейки при тапе не выделяются
        else
        {
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        }
    }
    
    NSDictionary *row = (NSDictionary *)[_data objectAtIndex:indexPath.section];
    NSArray *goods = (NSArray *)[row valueForKey:@"Goods"];
    NSDictionary *good = [goods objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [good valueForKey:@"Name"];
    // цвет категории
    UIView *colorStripeView = [cell.contentView viewWithTag:1];
    colorStripeView.backgroundColor = (UIColor *)[row valueForKey:@"Color"];
    
    // цена и единица измерения
    double price = [[good valueForKey:@"Price"] doubleValue];
    NSString *measure = [good valueForKey:@"MeasureName"];
    
    // в режиме справочника отмечаем серым цветом шрифта добавленные в список товары
    if (_isReferenceMode)
    {
        BOOL addedToList = [[good objectForKey:@"AddedToList"] boolValue];
        
        if (addedToList)
        {
            [cell.textLabel setFont:[UIFont boldSystemFontOfSize:cell.textLabel.font.pointSize]];
            
            double qty = [[good objectForKey:@"Qty"] doubleValue];
            double amount = price * qty;
            
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
            
            if (amount != 0)
            {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.3f %@ (%.2f руб)", qty, measureName, amount];
            }
            else
            {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.3f %@", qty, measureName];
            }
            
            double grayComponent = 245.0/255.0;
            
            cell.backgroundColor = [UIColor colorWithRed:grayComponent green:grayComponent blue:grayComponent alpha:1.0];
        }
        else
        {
            [cell.textLabel setFont:[UIFont systemFontOfSize:cell.textLabel.font.pointSize]];
            
            if ((price != 0) && (![measure isEqualToString:@""]))
            {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f руб / %@", price, measure];
            }
            else
            {
                cell.detailTextLabel.text = nil;
            }
            
            cell.backgroundColor = [UIColor whiteColor];
        }
    }
    // режим табличной формы
    else
    {
        if ((price != 0) && (![measure isEqualToString:@""]))
        {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f руб / %@", price, measure];
        }
        else
        {
            cell.detailTextLabel.text = nil;
        }
    }
    
    return cell;
}

// выбор строки - открытие формы редактирования
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // табличная форма - переходим к редактированию
    if (!_isReferenceMode)
    {
        _openedGoodIndexPath = indexPath;
        
        [self performSegueWithIdentifier:@"editGoodSegue" sender:self];
    }
    // выбор из справочника, форму не закрываем
    else
    {
        [self.searchBar resignFirstResponder];
        
        [self addGoodToShopList:NO];
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
        NSDictionary *category = (NSDictionary *)[_data objectAtIndex:indexPath.section];
        NSMutableArray *goods = (NSMutableArray *)[category valueForKey:@"Goods"];
        NSDictionary *good = [goods objectAtIndex:indexPath.row];
        
        NSString *docId = [good objectForKey:@"DocId"];
        
        // удалили из БД - удаляем из таблицы
        if ([self deleteElement:docId])
        {
            [goods removeObjectAtIndex:indexPath.row];
            
            // если в категории не осталось товаров, удаляем ее
            if ([goods count] == 0)
            {
                [_data removeObject:category];
            }
        }
        
        [self.tvData reloadData];
    }
}

// число записей в секции
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
{
    NSDictionary *category = (NSDictionary *)[_data objectAtIndex:sectionIndex];
    
    if ([[category valueForKey:@"CategoryExpanded"] boolValue])
    {
        return [(NSArray *)[category valueForKey:@"Goods"] count];
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
    NSDictionary *row = (NSDictionary *)[_data objectAtIndex:section];
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
        CGRect rectAddGood = CGRectMake(headerView.frame.size.width * 0.9 - 1.0, 1.0, headerView.frame.size.width * 0.1, _gridSectionHeight - 1.0);
        
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

// тап по названию категории - в секции
- (void)categoryLabelTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    UILabel *lblSection = (UILabel *)gestureRecognizer.view;
    
    [self expandCollapseSection:lblSection.tag];
}

// тап по кнопке "свернуть/разварнуть"
- (void)sectionShowHideButtonTouchUpInside:(UIButton *)sender
{
    [self expandCollapseSection:sender.tag];
}

// тап по кнопке добавления товара в категорию
- (void)addGoodButtonTouchUpInside:(UIButton *)sender
{
    [self performSegueWithIdentifier:@"newGoodWithCategorySegue" sender:sender];
}

//////////////
// переходы //
//////////////

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // добавление
    if ([segue.identifier isEqualToString:@"newGoodSegue"])
    {
        LDGoodEditViewController *destView = segue.destinationViewController;
        
        destView.parentCreateViewDelegate = self;
        
        [destView setNewGoodMode];
    }
    else
        // добавление с заранее заданной категорией
        if ([segue.identifier isEqualToString:@"newGoodWithCategorySegue"])
        {
            LDGoodEditViewController *destView = segue.destinationViewController;
            
            destView.parentCreateViewDelegate = self;
            
            [destView setNewGoodMode];
            // задаем категорию
            if ([sender isKindOfClass:[UIButton class]])
            {
                int sectionIndex = (int)((UIButton *)sender).tag;

                NSDictionary *category = (NSDictionary *)[_data objectAtIndex:sectionIndex];
                
                [destView setCategoryForNewGood:[category valueForKey:@"CatId"] with:[category valueForKey:@"CatName"]];
            }
        }
        else
            // редактирование или удаление
            if ([segue.identifier isEqualToString:@"editGoodSegue"])
            {
                // строка выбрана
                NSDictionary *row = [_data objectAtIndex:self.tvData.indexPathForSelectedRow.section];
                NSArray *goods = (NSArray *)[row valueForKey:@"Goods"];
                NSDictionary *good = [goods objectAtIndex:self.tvData.indexPathForSelectedRow.row];
            
                LDGoodEditViewController *destView = segue.destinationViewController;
            
                [destView setEditGoodMode:[good valueForKey:@"DocId"]];
            }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"editGoodSegue"])
    {
        return (self.tvData.indexPathForSelectedRow != nil);
    }
    else return YES;
}

///////////////////////////////
// вспомогательные процедуры //
///////////////////////////////

// перевод табличной формы в режим справочника
- (void)setReferenceMode:(NSString *)shopListId
{
    _isReferenceMode = YES;
    
    _shopListId = shopListId;
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

// выбор товара (в режиме справочника)
// closeTableView - флаг, определяющий, нужно ли закрыть табличную форму товаров после выбора товара
- (void)addGoodToShopList:(BOOL)closeTableView
{
    if (self.tvData.indexPathForSelectedRow != nil)
    {
        NSMutableDictionary *row = (NSMutableDictionary *)[_data objectAtIndex:self.tvData.indexPathForSelectedRow.section];
        NSMutableArray *goods = (NSMutableArray *)[row valueForKey:@"Goods"];
        NSMutableDictionary *good = [goods objectAtIndex:self.tvData.indexPathForSelectedRow.row];
        
        // переходим на исходный view - если взведен соответствующий флаг
        if (closeTableView)
        {
            [self.parentViewDelegate setSelectedValue:self element:[good objectForKey:@"Name"] key:[good objectForKey:@"DocId"] fromRef:@"REF_Goods" allValues:good];
            
            [self.navigationController popViewControllerAnimated:YES];
        }
        // если табличную форму закрывать не нужно, значит мы производим множественное добавление товаров в список,
        // и требуется убрать добавленный в список товар из таблицы
        else
        {
            double qty = [[NSString stringWithFormat:@"%@", [good objectForKey:@"Qty"]] doubleValue];
            double incQty = [[NSString stringWithFormat:@"%@", [good objectForKey:@"IncQty"]] doubleValue];
            
            [self.tvData beginUpdates];
            [good setObject:[NSNumber numberWithBool:YES] forKey:@"AddedToList"];
            [good setObject:[NSNumber numberWithDouble:(qty + incQty)] forKey:@"Qty"];
            [self.tvData endUpdates];
            
            [self.parentViewDelegate setSelectedValue:self element:[good objectForKey:@"Name"] key:[good objectForKey:@"DocId"] fromRef:@"REF_Goods" allValues:good];
            
            [self.tvData reloadData];
        }
    }
    // все товары добавили, таблица судя по всему опустела, при нажатии на зеленую галку возвращаемся в список покупок
    else [self.navigationController popViewControllerAnimated:YES];
}

// процедура сворачивания/развертывания секции
- (void)expandCollapseSection:(long)section
{
    [self.searchBar resignFirstResponder];
    
    NSMutableDictionary *category = (NSMutableDictionary *)[_data objectAtIndex:section];
    BOOL categoryExpanded = ![[category valueForKey:@"CategoryExpanded"] boolValue];
    
    [category setObject:[NSNumber numberWithBool:categoryExpanded] forKey:@"CategoryExpanded"];
    
    [self.tvData reloadData];
}

// загрузка из БД и перерисовка элемента в заданной строке
- (void)reloadListDataAt:(NSIndexPath *)indexPath
{
    if (indexPath)
    {
        NSMutableDictionary *row = (NSMutableDictionary *)[_data objectAtIndex:indexPath.section];
        NSMutableArray *goods = (NSMutableArray *)[row valueForKey:@"Goods"];
        NSMutableDictionary *good = [goods objectAtIndex:indexPath.row];
        
        NSString *goodId = [good valueForKey:@"DocId"];
        NSString *categoryId = [row valueForKey:@"CatId"];
        
        // доступ к глобальному объекту приложения
        LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        // необходимо подключение к локальной БД
        FMDatabase *db = appDelegate.localDB.db;
        
        if (db != nil)
        {
            FMResultSet *qryGood = [db executeQuery:[NSString stringWithFormat:@"SELECT   g.Name \
                                                                                        , g.CategoryId, cat.Name as CategoryName \
                                                                                        , IFNULL(g.MeasureId, 0) as MeasureId, IFNULL(m.Name, '') as MeasureName \
                                                                                        , IFNULL(g.Price, 0) as PriceFromRef \
                                                                                        , IFNULL(slg.Price, 0) as PriceFromList \
                                                                                        , IFNULL(slg.Qty, 0) as Qty \
                                                                                        , IFNULL(m.IncQty, 0) as IncQty \
                                                                                 FROM REF_Goods g \
                                                                                        LEFT JOIN REF_Measures m \
                                                                                            ON m.DocId = g.MeasureId \
                                                                                        LEFT JOIN ShopListGoods slg \
                                                                                            ON     slg.ShopListId = %@ \
                                                                                               and slg.GoodId = g.DocId \
                                                                                        LEFT JOIN REF_GoodCategories cat \
                                                                                            ON cat.DocId = g.CategoryId \
                                                                                 WHERE (g.DocId = %@)", _shopListId, goodId]];
            
            if ([qryGood next])
            {
                NSString *goodName = [qryGood stringForColumn:@"Name"];
                NSString *newCategoryId = [qryGood stringForColumn:@"CategoryId"];
                NSString *newCategoryName = [qryGood stringForColumn:@"CategoryName"];
                NSString *measureId = [qryGood stringForColumn:@"MeasureId"];
                NSString *measureName = [qryGood stringForColumn:@"MeasureName"];
                NSNumber *qty = [NSNumber numberWithDouble:[qryGood doubleForColumn:@"Qty"]];
                NSNumber *incQty = [NSNumber numberWithDouble:[qryGood doubleForColumn:@"IncQty"]];
                
                BOOL addedToList = ([qty doubleValue] != 0.0);  // кол-во в редактируемом списке не равно 0 - товар добавлен с список
                
                NSNumber *price;
                
                // режим спраовочника для добавления товаров в список
                if (_isReferenceMode)
                {
                    // товар добавлен в список - берем цену из списка
                    if (addedToList)
                    {
                        price = [NSNumber numberWithDouble:[qryGood doubleForColumn:@"PriceFromList"]];
                    }
                    // товара нет в списке - цена из справочника
                    else
                    {
                        price = [NSNumber numberWithDouble:[qryGood doubleForColumn:@"PriceFromRef"]];
                    }
                }
                // табличный режим - цена из справочника
                else
                {
                    price = [NSNumber numberWithDouble:[qryGood doubleForColumn:@"PriceFromRef"]];
                }
                
                [good setValue:goodName forKey:@"Name"];
                [good setValue:newCategoryId forKey:@"CategoryId"];
                [good setValue:newCategoryName forKey:@"CategoryName"];
                [good setValue:measureId forKey:@"MeasureId"];
                [good setValue:measureName forKey:@"MeasureName"];
                [good setValue:price forKey:@"Price"];
                [good setValue:qty forKey:@"Qty"];
                [good setValue:incQty forKey:@"IncQty"];
                [good setValue:[NSNumber numberWithBool:addedToList] forKey:@"AddedToList"];
                
                // категория изменилась - необходимо перекинуть товар в нужную секцию
                if (![categoryId isEqualToString:newCategoryId])
                {
                    // из текущей категории исключаем
                    [goods removeObjectAtIndex:indexPath.row];
                    
                    // ищем секцию новой категории
                    for (int i = 0; i < [_data count]; i++)
                    {
                        NSMutableDictionary *category = (NSMutableDictionary *)[_data objectAtIndex:i];
                        
                        if ([[category valueForKey:@"CatId"] isEqualToString:newCategoryId])
                        {
                            NSMutableArray *categoryGoods = (NSMutableArray *)[category valueForKey:@"Goods"];
                            
                            [categoryGoods addObject:good];
                            
                            break;
                        }
                    }
                }
                
                // обновляем таблицу
                [self.tvData reloadData];
            }
            
            [qryGood close];
        }
    }
}

/////////////////////////////////////////
// управление фильтрацией по ктагориям //
/////////////////////////////////////////

// добавление категории для фильтрации
- (void)addFilterCategory:(NSString *)categoryId
{
    _filterByCategories = YES;

    [self setFilterButtonTintColor];
        
    NSMutableArray *buttons = (NSMutableArray *)[self.toolbar.items mutableCopy];
        
    if ([buttons indexOfObject:self.btnFilter] == NSNotFound)
    {
        [buttons insertObject:self.btnFilter atIndex:0];
        self.toolbar.items = buttons;
    }
    
    if (_filterCategoryIds == nil)
    {
        _filterCategoryIds = [[NSMutableArray alloc] init];
    }
    
    BOOL found = NO;
    
    for (int i = 0; i < _filterCategoryIds.count; i++)
        if ([[_filterCategoryIds objectAtIndex:i] isEqualToString:categoryId])
        {
            found = YES;
            break;
        }
    
    if (!found)
    {
        [_filterCategoryIds addObject:categoryId];
        
        // добавили идентификатор для фильтрации - обновляем список
        [self loadData:self.searchBar.text showSectionsExpanded:YES];
    }
}

// удаление категории из фильтра
- (void)removeFilterCategory:(NSString *)categoryId
{
    if (_filterCategoryIds != nil)
    {
        BOOL found = NO;
        
        for (int i = 0; i < _filterCategoryIds.count; i++)
            if ([[_filterCategoryIds objectAtIndex:i] isEqualToString:categoryId])
            {
                [_filterCategoryIds removeObjectAtIndex:i];
                
                found = YES;
                
                break;
            }
        
        if (_filterCategoryIds.count == 0)
        {
            _filterByCategories = NO;
            
            // скрываем кнопку фильтрации
            NSMutableArray *buttons = (NSMutableArray *)[self.toolbar.items mutableCopy];
            [buttons removeObject:self.btnFilter];
            self.toolbar.items = buttons;
        }
        
        if (found)
        {
            // обновляем список
            [self loadData:self.searchBar.text showSectionsExpanded:NO];
        }
    }
}

// очистка списка категорий для фильтрации
- (void)clearFilterCategories
{
    // чистим массив идентификаторов
    [_filterCategoryIds removeAllObjects];
    
    _filterByCategories = NO;
    
    [self setFilterButtonTintColor];
    
    // скрываем кнопку фильтрации
    NSMutableArray *buttons = (NSMutableArray *)[self.toolbar.items mutableCopy];
    [buttons removeObject:self.btnFilter];
    self.toolbar.items = buttons;
    
    // обновляем список
    [self loadData:self.searchBar.text showSectionsExpanded:NO];
}

// фильтрация записей с помощью предустановленного фильтра
- (IBAction)filterButton:(id)sender
{
    _filterByCategories = !_filterByCategories;
    
    [self setFilterButtonTintColor];
    
    // обновляем список
    [self loadData:self.searchBar.text showSectionsExpanded:NO];
}

// установка цвета кнопки фильтрации
- (void)setFilterButtonTintColor
{
    if (_filterByCategories)
    {
        self.btnFilter.tintColor = [self.view tintColor];
    }
    else self.btnFilter.tintColor = [UIColor colorWithRed:220.0/255.0 green:220.0/255.0 blue:220.0/255.0 alpha:1.0];
}

///////////////////////////////////////
// протокол LDRefCreateValueDelegate //
///////////////////////////////////////

// обрабатываем создание нового товара - добавляем его в нужную категорию
- (void)setCreatedValue:(id)sender element:(NSString *)name key:(NSString *)value fromRef:(NSString *)tableName allValues:(NSDictionary *)values
{
    // доступ к глобальному объекту приложения
    LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // необходимо подключение к локальной БД
    FMDatabase *db = appDelegate.localDB.db;
    
    if (db != nil)
    {
        FMResultSet *qryGood = [db executeQuery:[NSString stringWithFormat:@"SELECT   g.Name \
                                                                                    , g.CategoryId, cat.Name as CategoryName \
                                                                                    , IFNULL(cat.ColorR, 1.0) as R, IFNULL(cat.ColorG, 1.0) as G, IFNULL(cat.ColorB, 1.0) as B \
                                                                                    , IFNULL(cat.ColorAlpha, 1.0) as A \
                                                                                    , IFNULL(g.MeasureId, 0) as MeasureId, IFNULL(m.Name, '') as MeasureName, IFNULL(m.Name234, '') as MeasureName234, IFNULL(m.Name567890, '') as MeasureName567890 \
                                                                                    , IFNULL(g.Price, 0) as Price \
                                                                                    , IFNULL(m.IncQty, 0) as IncQty \
                                                                             FROM REF_Goods g \
                                                                                    LEFT JOIN REF_Measures m \
                                                                                        ON m.DocId = g.MeasureId \
                                                                                    LEFT JOIN REF_GoodCategories cat \
                                                                                        ON cat.DocId = g.CategoryId \
                                                                             WHERE (g.DocId = %@)", value]];        
        if ([qryGood next])
        {
            NSString *goodName = [qryGood stringForColumn:@"Name"];
            NSString *categoryId = [qryGood stringForColumn:@"CategoryId"];
            NSString *categoryName = [qryGood stringForColumn:@"CategoryName"];
            NSString *measureId = [qryGood stringForColumn:@"MeasureId"];
            NSString *measureName = [qryGood stringForColumn:@"MeasureName"];
            NSString *measureName234 = [qryGood stringForColumn:@"MeasureName234"];
            NSString *measureName567890 = [qryGood stringForColumn:@"MeasureName567890"];
            NSNumber *price = [NSNumber numberWithDouble:[qryGood doubleForColumn:@"Price"]];
            NSNumber *qty = [NSNumber numberWithDouble:0.0];
            NSNumber *incQty = [NSNumber numberWithDouble:[qryGood doubleForColumn:@"IncQty"]];
            NSNumber *addedToList = [NSNumber numberWithBool:NO];

            NSMutableDictionary *good = [[NSMutableDictionary alloc] init];
            
            [good setValue:value forKey:@"DocId"];
            [good setValue:goodName forKey:@"Name"];
            [good setValue:categoryId forKey:@"CategoryId"];
            [good setValue:categoryName forKey:@"CategoryName"];
            [good setValue:measureId forKey:@"MeasureId"];
            [good setValue:measureName forKey:@"MeasureName"];
            [good setValue:measureName234 forKey:@"MeasureName234"];
            [good setValue:measureName567890 forKey:@"MeasureName567890"];
            [good setValue:price forKey:@"Price"];
            [good setValue:qty forKey:@"Qty"];
            [good setValue:incQty forKey:@"IncQty"];
            [good setValue:addedToList forKey:@"AddedToList"];
            
            BOOL categoryFound = NO;
            
            // ищем секцию новой категории
            for (int i = 0; i < [_data count]; i++)
            {
                NSMutableDictionary *category = (NSMutableDictionary *)[_data objectAtIndex:i];
                
                if ([[category valueForKey:@"CatId"] isEqualToString:categoryId])
                {
                    NSMutableArray *categoryGoods = (NSMutableArray *)[category valueForKey:@"Goods"];
                    
                    [categoryGoods insertObject:good atIndex:0];
                    
                    categoryFound = YES;
                    
                    break;
                }
            }
            
            // категории не было в списке - необходимо добавить ее
            if (!categoryFound)
            {
                NSMutableDictionary *category = [[NSMutableDictionary alloc] init];
                NSMutableArray *goods = [[NSMutableArray alloc] init];
                
                [category setObject:categoryId forKey:@"CatId"];
                [category setObject:categoryName forKey:@"CatName"];
                
                // цвет категории
                double r = [qryGood doubleForColumn:@"R"];
                double g = [qryGood doubleForColumn:@"G"];
                double b = [qryGood doubleForColumn:@"B"];
                double a = [qryGood doubleForColumn:@"A"];
                
                UIColor *catColor = [UIColor colorWithRed:r green:g blue:b alpha:a];
                
                [category setObject:catColor forKey:@"Color"];
                
                // признак свернутой/рвзвернутой секции категории
                [category setObject:[NSNumber numberWithBool:YES] forKey:@"CategoryExpanded"];
                
                [goods addObject:good];
                
                [category setObject:goods forKey:@"Goods"];
                
                [_data insertObject:category atIndex:0];
            }
            
            // обновляем таблицу
            [self.tvData reloadData];
        }
        
        [qryGood close];
    }
}

//////////////////////
// обработка жестов //
//////////////////////

// обработка изменения количества с помощью жеста
- (void)handleCellPan:(UIPanGestureRecognizer *)gestureRecognizer
{
    if (_isReferenceMode)
    {
        NSIndexPath *indexPath = [self.tvData indexPathForRowAtPoint:[gestureRecognizer locationInView:self.tvData]];
        
        // в начале жеста сохраняем индекс ячейки
        if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
        {
            _cellGestureStarted = indexPath;
            _gestureStartPoint = [gestureRecognizer translationInView:self.view];
            
            NSMutableDictionary *category = [_data objectAtIndex:indexPath.section];
            NSMutableArray *goods = (NSMutableArray *)[category valueForKey:@"Goods"];
            _editedGood = (NSMutableDictionary *)[goods objectAtIndex:indexPath.row];
            _editGoodStartQty = [[_editedGood valueForKey:@"Qty"] doubleValue];
            
            _editGoodIncQty = [[_editedGood valueForKey:@"IncQty"] doubleValue];
            
            if (_editGoodIncQty == 0.0)
            {
                _editGoodIncQty = 1.0;
            }
        }
        else
            // после окончания сбрасываем индекс
            if (gestureRecognizer.state == UIGestureRecognizerStateEnded)
            {
                _cellGestureStarted = nil;
                _editedGood = nil;
            }
            else
            {
                if (indexPath != nil)
                {
                    // проверяем, что остались в пределах начальной ячейки
                    if ([indexPath isEqual:_cellGestureStarted])
                    {
                        CGPoint pnt = [gestureRecognizer translationInView:self.view];
                        
                        // вычисляем угол направления жеста в градусах
                        double angleDeg = (pnt.x != _gestureStartPoint.x ? atan(fabs(pnt.y - _gestureStartPoint.y) / fabs(pnt.x - _gestureStartPoint.x)) / M_PI * 180.0 : 0.0);
                        
                        // угол траектории - в пределах 30 градусов, если линия движения круче - перестаем считать
                        if ((pnt.y < _gridRowHeight) && (angleDeg < 30.0))
                        {
                            double coeff = self.view.frame.size.width / 40.0;
                            
                            if (fabs(pnt.x / coeff) >= 1.0)
                            {
                                // считаем число инкрементов
                                int incsNumber = pnt.x / coeff;
                                
                                // новое количество
                                double newQty = _editGoodStartQty + (_editGoodIncQty * incsNumber);
                                
                                if (newQty < 0) newQty = 0.0;
                                
                                [_editedGood setValue:[NSNumber numberWithBool:(newQty > 0.0)] forKey:@"AddedToList"];
                                [_editedGood setValue:[NSNumber numberWithDouble:newQty] forKey:@"Qty"];
                                
                                [self.parentViewDelegate setSelectedValue:self element:[_editedGood objectForKey:@"Name"] key:[_editedGood objectForKey:@"DocId"] fromRef:@"REF_Goods" allValues:_editedGood];
                                    
                                // обновляем строку таблицы
                                [self.tvData reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                            }
                        }
                    }
                }
            }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

@end
