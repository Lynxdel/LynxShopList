//
//  LDGoodCategoriesTableViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 20/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDGoodCategoriesTableViewController.h"

@interface LDGoodCategoriesTableViewController ()
{
    NSMutableArray *_data;
    
    BOOL _isBusy;   // флаг текущей обработки данных
    
    BOOL _isReferenceMode;  // флаг режима справочника (по умолчанию - NO)
}

@end

@implementation LDGoodCategoriesTableViewController

@synthesize parentViewDelegate;

//////////////////
// события view //
//////////////////

- (void)viewDidLoad
{
    [super viewDidLoad];
    
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
}

- (void)viewDidLayoutSubviews
{
    // в режиме справочника растягиваем таблицу до нижней части формы
    if (_isReferenceMode)
    {
        CGRect tvRect = self.tvData.frame;
        
        [self.tvData setFrame:CGRectMake(tvRect.origin.x, tvRect.origin.y, tvRect.size.width, tvRect.size.height + self.toolbar.frame.size.height)];
        
        [self.toolbar setHidden:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    // прячем нижнюю панель
    [self.tabBarController.tabBar setHidden:YES];
    
    // показываем верхнюю
    [self.navigationController.navigationBar setHidden:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self loadData:@""];
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
-(void)loadData:(NSString *)namesLike;
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
                where = [NSString stringWithFormat:@" and Name_lower LIKE '%%%@%%'", [namesLike lowercaseString]];
            }
            
            FMResultSet *results = [db executeQuery:[NSString stringWithFormat:@"SELECT   DocId \
                                                                                        , Name \
                                                                                        , Name_lower \
                                                                                        , IFNULL(ColorR, 1.0) as R \
                                                                                        , IFNULL(ColorG, 1.0) as G \
                                                                                        , IFNULL(ColorB, 1.0) as B \
                                                                                        , IFNULL(ColorAlpha, 1.0) as A \
                                                                                 FROM REF_GoodCategories \
                                                                                 WHERE (1 = 1) %@ \
                                                                                 ORDER BY Name_lower", where]];
            
            _data = [[NSMutableArray alloc] init];
            
            while([results next])
            {
                NSString *docId = [results stringForColumn:@"DocId"];
                NSString *name = [results stringForColumn:@"Name"];
                
                double r = [results doubleForColumn:@"R"];
                double g = [results doubleForColumn:@"G"];
                double b = [results doubleForColumn:@"B"];
                double a = [results doubleForColumn:@"A"];
                
                UIColor *catColor = [UIColor colorWithRed:r green:g blue:b alpha:a];
                
                NSDictionary *ref = [NSDictionary dictionaryWithObjectsAndKeys:docId, @"DocId",
                                     name, @"Name",
                                     catColor, @"Color",
                                     nil];
                [_data addObject:ref];
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

- (BOOL)deleteElement:(NSString *)docId
{
    BOOL result = NO;
    
    // доступ к глобальному объекту приложения
    LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if ([appDelegate.localDB canDeleteGoodCategory:docId])
    {
        result = [appDelegate.localDB deleteRecordByDocId:docId from:@"REF_GoodCategories"];
    }
    else
    {
        UIAlertView *info = [[UIAlertView alloc] initWithTitle:nil
                                                       message:@"Категория используется"
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
    [self loadData:searchText];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    
    [searchBar setText:nil];
    
    [self loadData:@""];
}

/////////////////////////////////
// делегат UITableViewDelegate //
/////////////////////////////////

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"GoodsCatCellItem";
    
    NSDictionary *row = [_data objectAtIndex:indexPath.row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        
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
    }
    
    // наименование
    cell.textLabel.text = [row valueForKey:@"Name"];
    // цвет категории
    UIView *colorStripeView = [cell.contentView viewWithTag:1];
    colorStripeView.backgroundColor = (UIColor *)[row valueForKey:@"Color"];
    
    return cell;
}

// выбор строки - открытие формы редактирования
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // табличная форма - переходим к редактированию
    if (!_isReferenceMode)
    {
        [self performSegueWithIdentifier:@"editGoodCategorySegue" sender:self];
    }
    // выбор из справочника
    else
    {
        [self selectCategory];
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
        NSDictionary *row = [_data objectAtIndex:indexPath.row];
        
        NSString *docId = [row objectForKey:@"DocId"];
        
        // удалили из БД - удаляем из таблицы
        if ([self deleteElement:docId])
        {
            [_data removeObjectAtIndex:indexPath.row];
        }
        
        [self.tvData reloadData];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
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

//////////////
// переходы //
//////////////

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // добавление
    if ([segue.identifier isEqualToString:@"newGoodCategorySegue"])
    {
        LDGoodCategoryEditViewController *destView = segue.destinationViewController;
        
        [destView setNewCatMode];
    }
    else
        // редактирование или удаление
        if ([segue.identifier isEqualToString:@"editGoodCategorySegue"])
        {
            NSDictionary *row = [_data objectAtIndex:self.tvData.indexPathForSelectedRow.row];
            
            LDGoodCategoryEditViewController *destView = segue.destinationViewController;
            
            [destView setEditCatMode:[row valueForKey:@"DocId"] withName:[row valueForKey:@"Name"]];
        }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"editGoodCategorySegue"])
    {
        return (self.tvData.indexPathForSelectedRow != nil);
    }
    else return YES;
}

///////////////////////////////
// вспомогательные процедуры //
///////////////////////////////

// перевод табличной формы в режим справочника
- (void)setReferenceMode
{
    _isReferenceMode = YES;
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

// выбор категории (в режиме справочника)
- (void)selectCategory
{
    if (self.tvData.indexPathForSelectedRow != nil)
    {
        NSDictionary *row = [_data objectAtIndex:self.tvData.indexPathForSelectedRow.row];
        
        // вызываем событие выбора элемента
        [self.parentViewDelegate setSelectedValue:self element:[row objectForKey:@"Name"] key:[row objectForKey:@"DocId"] fromRef:@"REF_GoodCategories" allValues:row];
    
        // переходим на исходный view
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
