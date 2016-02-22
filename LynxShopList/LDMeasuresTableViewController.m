//
//  LDMeasuresTableViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 24/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDMeasuresTableViewController.h"

@interface LDMeasuresTableViewController ()
{
    NSMutableArray *_data;
    
    BOOL _isBusy;   // флаг текущей обработки данных
    
    BOOL _isReferenceMode;  // флаг режима справочника (по умолчанию - NO)
}

@end

@implementation LDMeasuresTableViewController

@synthesize parentViewDelegate;

//////////////////
// события view //
//////////////////

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _isBusy = NO;
    
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
-(void)loadData:(NSString *)namesLike
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
            
            FMResultSet *results = [db executeQuery:[NSString stringWithFormat:@"SELECT DocId, Name, IFNULL(IncQty, 1.0) as IncQty \
                                                                                 FROM REF_Measures \
                                                                                 WHERE (1 = 1) %@ \
                                                                                 ORDER BY Name", where]];
            
            _data = [[NSMutableArray alloc] init];
            
            while([results next])
            {
                NSString *docId = [results stringForColumn:@"DocId"];
                NSString *name = [results stringForColumn:@"Name"];
                NSNumber *incQty = [NSNumber numberWithDouble:[results doubleForColumn:@"IncQty"]];
                
                NSDictionary *ref = [NSDictionary dictionaryWithObjectsAndKeys:docId, @"DocId", name, @"Name", incQty, @"IncQty", nil];
                
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

// удаление записи
- (BOOL)deleteElement:(NSString *)docId
{
    BOOL result = NO;
    
    // доступ к глобальному объекту приложения
    LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];

    if ([appDelegate.localDB canDeleteMeasure:docId])
    {
        result = [appDelegate.localDB deleteRecordByDocId:docId from:@"REF_Measures"];
    }
    else
    {
        UIAlertView *info = [[UIAlertView alloc] initWithTitle:nil
                                                       message:@"Единица измерения используется"
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
    static NSString *cellIdentifier = @"MeasuresCellItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        
        // выводим галку, как бы намекающую на то, что по тапу будет открыта форма редактирования (didSelectRowAtIndexPath)
        // в режиме выбора из справочника тап - выбор элемента, галку справа убираем
        if (!_isReferenceMode)
        {
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        }
    }
    
    NSDictionary *row = [_data objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [row valueForKey:@"Name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"▽ %.3f △", [[row objectForKey:@"IncQty"] doubleValue]];
    
    return cell;
}

// выбор строки - открытие формы редактирования
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // табличная форма - переходим к редактированию
    if (!_isReferenceMode)
    {
        [self performSegueWithIdentifier:@"editMeasureSegue" sender:self];
    }
    // выбор из справочника
    else
    {
        [self selectMeasure];
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
    if ([segue.identifier isEqualToString:@"newMeasureSegue"])
    {
        LDMeasureEditViewController *destView = segue.destinationViewController;
        
        [destView setNewMeasureMode];
    }
    else
        // редактирование или удаление
        if ([segue.identifier isEqualToString:@"editMeasureSegue"])
        {
            // строка выбрана
            NSDictionary *row = [_data objectAtIndex:self.tvData.indexPathForSelectedRow.row];
            
            LDMeasureEditViewController *destView = segue.destinationViewController;
            
            [destView setEditMeasureMode:[row valueForKey:@"DocId"]];
        }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"editMeasureSegue"])
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

// выбор единицы (в режиме справочника)
- (void)selectMeasure
{
    if (self.tvData.indexPathForSelectedRow != nil)
    {
        NSDictionary *row = [_data objectAtIndex:self.tvData.indexPathForSelectedRow.row];
        
        // вызываем событие выбора элемента
        [self.parentViewDelegate setSelectedValue:self element:[row objectForKey:@"Name"] key:[row objectForKey:@"DocId"] fromRef:@"REF_Measures" allValues:row];
        
        // переходим на исходный view
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
