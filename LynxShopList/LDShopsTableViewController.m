//
//  LDShopsTableViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 16/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDShopsTableViewController.h"

@interface LDShopsTableViewController ()
{
    NSMutableArray *_data;
    
    BOOL _isBusy;   // флаг текущей обработки данных
    
    BOOL _isReferenceMode;  // флаг режима справочника (по умолчанию - NO)
}

@end

@implementation LDShopsTableViewController

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
// предусмотрен параметр для поиска, но контролы для поиска были удалены
- (void)loadData:(NSString *)namesLike
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
                where = [NSString stringWithFormat:@"WHERE Name_lower LIKE '%%%@%%'", [namesLike lowercaseString]];
            }
            
            FMResultSet *results = [db executeQuery:[NSString stringWithFormat:@"SELECT DocId, Name, Name_lower \
                                                                                 FROM REF_Shops \
                                                                                 %@ \
                                                                                 ORDER BY Name_lower", where]];
            
            _data = [[NSMutableArray alloc] init];
            
            while([results next])
            {
                NSString *docId = [results stringForColumn:@"DocId"];
                NSString *name = [results stringForColumn:@"Name"];
                
                NSDictionary *ref = [NSDictionary dictionaryWithObjectsAndKeys:docId, @"DocId", name, @"Name", nil];
                
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
    
    if ([appDelegate.localDB canDeleteShop:docId])
    {
        result = [appDelegate.localDB deleteRecordByDocId:docId from:@"REF_Shops"];
    }
    else
    {
        UIAlertView *info = [[UIAlertView alloc] initWithTitle:nil
                                                       message:@"Магазин используется в списках"
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
    static NSString *cellIdentifier = @"ShopsCellItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        
        // выводим галку, как бы намекающую на то, что по тапу будет открыта форма редактирования (didSelectRowAtIndexPath)
        // в режиме выбора из справочника тап - выбор элемента, галку справа убираем
        if (!_isReferenceMode)
        {
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        }
    }
    
    NSDictionary *row = [_data objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [row valueForKey:@"Name"];
    
    return cell;
}

// выбор строки - открытие формы редактирования
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // табличная форма - переходим к редактированию
    if (!_isReferenceMode)
    {
        [self performSegueWithIdentifier:@"editShopSegue" sender:self];
    }
    // выбор из справочника
    else
    {
        [self selectShop];
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
    if ([segue.identifier isEqualToString:@"newShopSegue"])
    {
        LDShopEditViewController *destView = segue.destinationViewController;
        
        [destView setNewShopMode];
    }
    else
        // редактирование или удаление
        if ([segue.identifier isEqualToString:@"editShopSegue"])
        {
            NSDictionary *row = [_data objectAtIndex:self.tvData.indexPathForSelectedRow.row];
            
            LDShopEditViewController *destView = segue.destinationViewController;
            
            [destView setEditShopMode:[row valueForKey:@"DocId"] withName:[row valueForKey:@"Name"]];
        }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"editShopSegue"])
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

// выбор магазина (в режиме справочника)
- (void)selectShop
{
    if (self.tvData.indexPathForSelectedRow != nil)
    {
        NSDictionary *row = [_data objectAtIndex:self.tvData.indexPathForSelectedRow.row];
        
        // вызываем событие выбора элемента
        [self.parentViewDelegate setSelectedValue:self element:[row objectForKey:@"Name"] key:[row objectForKey:@"DocId"] fromRef:@"REF_Shops" allValues:row];
        
        // переходим на исходный view
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
