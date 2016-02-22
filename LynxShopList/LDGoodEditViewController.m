//
//  LDGoodEditViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 20/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDGoodEditViewController.h"

@interface LDGoodEditViewController ()
{
    NSString *_docId;
    NSString *_goodName;
    
    NSString *_categoryId;
    NSString *_categoryName;
    
    NSString *_measureId;
    NSString *_measureName;
    
    double _price;
    
    BOOL _isBusy;   // флаг текущей обработки данных
    
    CGFloat _keyboardHeight;    // высота клавиатуры
    
    NSString *_refTableName;        // имя таблицы справочника, из которого происходит подбор
    
    NSMutableArray *_filteredData;  // массив отобранных строк справочника (категорий или единиц измерения)
}

@end

@implementation LDGoodEditViewController

@synthesize parentCreateViewDelegate;

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
    
    // для текста кнопки возврата на табличной форме категорий
    [self.navigationItem setTitle:@""];
    
    // таблица для подбора категории и единицы измерения
    self.tvSearchReference = [[UITableView alloc] init];
    
    [self.tvSearchReference setDataSource:self];
    [self.tvSearchReference setDelegate:self];
    
    [self.tvSearchReference.layer setBorderColor:[[[UIColor grayColor] colorWithAlphaComponent:0.5] CGColor]];
    [self.tvSearchReference.layer setBorderWidth:0.5];
    
    self.tvSearchReference.layer.cornerRadius = 5.0;
    self.tvSearchReference.clipsToBounds = YES;
    
    // регистрируем обработчик появления клавиатуры
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(keyboardOnScreen:) name:UIKeyboardDidShowNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    self.txtGoodName.text = _goodName;
    self.txtCategoryName.text = _categoryName;
    self.txtMeasureName.text = _measureName;
    self.txtPrice.text = [NSString stringWithFormat:@"%.2f", _price];
}

// для сокрытия клавиатуры
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.txtGoodName resignFirstResponder];
    [self.txtCategoryName resignFirstResponder];
    [self.txtMeasureName resignFirstResponder];
    [self.txtPrice resignFirstResponder];
}

// обработчик события появления клавиатуры
- (void)keyboardOnScreen:(NSNotification *)notification
{
    NSDictionary *info  = notification.userInfo;
    NSValue *value = info[UIKeyboardFrameEndUserInfoKey];
    
    CGRect rawFrame = [value CGRectValue];
    CGRect keyboardFrame = [self.view convertRect:rawFrame fromView:nil];
    
    _keyboardHeight = keyboardFrame.size.height;
}

//////////////////////
// работа с данными //
//////////////////////

// загрузка данных из БД
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
            FMResultSet *qryGood = [db executeQuery:[NSString stringWithFormat:@"SELECT   g.Name \
                                                                                        , IFNULL(g.CategoryId, 0) AS CategoryId, IFNULL(gc.Name, '') AS CategoryName \
                                                                                        , IFNULL(g.MeasureId, 0) AS MeasureId, IFNULL(m.Name, '') AS MeasureName \
                                                                                        , IFNULL(g.Price, 0) as Price \
                                                                                 FROM REF_Goods g \
                                                                                        LEFT JOIN REF_GoodCategories gc \
                                                                                            ON g.CategoryId = gc.DocId \
                                                                                        LEFT JOIN REF_Measures m \
                                                                                            ON g.MeasureId = m.DocId \
                                                                                 WHERE (g.DocId = %@)", _docId]];
            if ([qryGood next])
            {
                _goodName = [qryGood stringForColumn:@"Name"];
                _categoryId = [qryGood stringForColumn:@"CategoryId"];
                _categoryName = [qryGood stringForColumn:@"CategoryName"];
                _measureId = [qryGood stringForColumn:@"MeasureId"];
                _measureName = [qryGood stringForColumn:@"MeasureName"];
                _price = [qryGood doubleForColumn:@"Price"];
            }
            
            [qryGood close];
        }
    }
    @finally
    {
        _isBusy = NO;
        
        [self.spinner stopAnimating];
    }
}

// сохранение новой записи
- (void)saveGood
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
            bool result = NO;
            
            [self setPriceFromText];
            
            NSMutableDictionary *argsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:self.txtGoodName.text, @"Name",
                                                                            [self.txtGoodName.text lowercaseString], @"Name_lower",
                                                                                                        _categoryId, @"CategoryId",
                                                                                                         _measureId, @"MeasureId",
                                                                                 [NSNumber numberWithDouble:_price], @"Price", nil];
            
            // новая запись - INSERT
            if ([_docId isEqualToString:@"0"])
            {
                [argsDict setObject:[NSDate date] forKey:@"CreateDate"];
                
                result = [db executeUpdate:@"INSERT INTO REF_Goods (Name, Name_lower, CategoryId, MeasureId, Price, CreateDate) \
                                             VALUES (:Name, :Name_lower, :CategoryId, :MeasureId, :Price, :CreateDate)" withParameterDictionary:argsDict];
                if (result)
                {
                    // теперь нужно определить новый DocId
                    FMResultSet *docId_result = [db executeQuery:@"SELECT last_insert_rowid() as NewDocId"];
                    
                    // определили - сообщаем табличной форме о создании нового товара
                    if ([docId_result next])
                    {
                        [self.parentCreateViewDelegate setCreatedValue:self element:self.txtGoodName.text key:[docId_result stringForColumn:@"NewDocId"] fromRef:@"REF_Goods" allValues:argsDict];
                    }
                    
                    [docId_result close];
                }
            }
            // существующая - UPDATE
            else
            {
                [argsDict setObject:[NSDate date] forKey:@"EditDate"];
                [argsDict setObject:_docId forKey:@"DocId"];
                
                result = [db executeUpdate:@"UPDATE REF_Goods \
                                             SET   Name = :Name \
                                                 , Name_lower = :Name_lower \
                                                 , CategoryId = :CategoryId \
                                                 , MeasureId = :MeasureId \
                                                 , Price = :Price \
                                                 , EditDate = :EditDate \
                                             WHERE DocId = :DocId" withParameterDictionary:argsDict];
            }
            
            if (result)
            {
                // все в порядке возвращаемся в список магазинов
                [self.navigationController popViewControllerAnimated:YES];
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
}

// извлечение данных заданного справочника из БД
- (void)loadFilteredData:(NSString *)fromTable with:(NSString *)namesLike;
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
            NSString *where = [NSString stringWithFormat:@"Name_lower LIKE '%@%%'", [namesLike lowercaseString]];
            
            FMResultSet *qry = [db executeQuery:[NSString stringWithFormat:@"SELECT DocId, Name \
                                                                             FROM %@ \
                                                                             WHERE %@ \
                                                                             ORDER BY IFNULL(Name_lower, '')", fromTable, where]];
            
            _filteredData = [[NSMutableArray alloc] init];
            
            while([qry next])
            {
                NSString *docId = [qry stringForColumn:@"DocId"];
                NSString *name = [qry stringForColumn:@"Name"];
                
                NSMutableDictionary *row = [[NSMutableDictionary alloc] init];
                
                [row setObject:docId forKey:@"DocId"];
                [row setObject:name forKey:@"Name"];
                
                [_filteredData addObject:row];
            }
        }
        
        [self.tvSearchReference reloadData];
    }
    @finally
    {
        _isBusy = NO;
        
        [self.spinner stopAnimating];
    }
}

- (IBAction)saveGoodButton:(id)sender
{
    [self saveGood];
}

///////////////////////////////
// вспомогательные процедуры //
///////////////////////////////

// создание новой записи
- (void)setNewGoodMode
{
    _docId = @"0";
    _goodName = @"";
    _categoryId = @"0";
    _categoryName = @"";
    _measureId = @"0";
    _measureName = @"";
    _price = 0.0;
}

// редактирование или удаление текущей записи
- (void)setEditGoodMode:(NSString *)docId;
{
    _docId = docId;
    
    [self loadData];
}

// выбор категории для товара (например, при добавлении по кнопке в секции категории)
- (void)setCategoryForNewGood:(NSString *)categoryId with:(NSString *)categoryName
{
    _categoryId = categoryId;
    _categoryName = categoryName;
    
    self.txtCategoryName.text = categoryName;
}

// установка значения примерной цены на основе данных поля ввода
- (void)setPriceFromText
{
    NSScanner *scanner = [NSScanner scannerWithString:[self.txtPrice.text stringByReplacingOccurrencesOfString:@"," withString:@"."]];
    
    double value = 0;
    
    if ([scanner scanDouble:&value])
    {
        _price = value;
    }
    else
    {
        _price = 0.0;
        self.txtPrice.text = @"0.0";
    }
}

// обработка выбора категории
- (void)setSelectedValue:(id)sender element:(NSString *)name key:(NSString *)value fromRef:(NSString *)tableName allValues:(NSDictionary *)values
{
    if ([tableName isEqualToString:@"REF_GoodCategories"])
    {
        _categoryId = value;
        _categoryName = name;
        
        self.txtCategoryName.text = _categoryName;
    }
    else
        if ([tableName isEqualToString:@"REF_Measures"])
        {
            _measureId = value;
            _measureName = name;
            
            self.txtMeasureName.text = _measureName;
        }
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

//////////////
// переходы //
//////////////

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // переход для выбора категории товара
    if ([segue.identifier isEqualToString:@"selectGoodCatSegue"])
    {
        _goodName = self.txtGoodName.text;
        
        LDGoodCategoriesTableViewController *destView = segue.destinationViewController;
        
        destView.parentViewDelegate = self;
        
        [destView setReferenceMode];
    }
    else
        // переход для выбора единицы измерения
        if ([segue.identifier isEqualToString:@"selectGoodMeasureSegue"])
        {
            _goodName = self.txtGoodName.text;
            
            LDMeasuresTableViewController *destView = segue.destinationViewController;
            
            destView.parentViewDelegate = self;
            
            [destView setReferenceMode];
        }
}

/////////////////////////////////////
// подбор значений из справочников //
/////////////////////////////////////

- (IBAction)categoryEditingChanged:(id)sender
{
    // сбрасываем имеющееся значение при начале редактирования
    _categoryId = @"0";
    
    id lastSubview = [self.view.subviews objectAtIndex:(self.view.subviews.count - 1)];
    
    // если таблица для подбора еще не присутсвует на форме, выводим ее
    if (![lastSubview isKindOfClass:[UITableView class]])
    {
        UITextField *txt = (UITextField *)sender;
        
        CGFloat vertGap = self.view.frame.size.height - txt.frame.origin.y - txt.frame.size.height - _keyboardHeight;
        int rowHeightsCount = vertGap / txt.frame.size.height;
        
        // рассчитываем высоту таблицы таким образом, чтобы в ней умещалось целое число строк
        CGRect rect = CGRectMake(txt.frame.origin.x, txt.frame.origin.y + txt.frame.size.height, txt.frame.size.width, rowHeightsCount * txt.frame.size.height);
        
        [self.tvSearchReference setFrame:rect];
        
        [self.view addSubview:self.tvSearchReference];
    }
    
    _refTableName = @"REF_GoodCategories";
    
    [self loadFilteredData:_refTableName with:((UITextField *)sender).text];
}

- (IBAction)measureEditingChanged:(id)sender
{
    // сбрасываем имеющееся значение при начале редактирования
    _measureId = @"0";
    
    id lastSubview = [self.view.subviews objectAtIndex:(self.view.subviews.count - 1)];
    
    // если таблица для подбора еще не присутсвует на форме, выводим ее
    if (![lastSubview isKindOfClass:[UITableView class]])
    {
        UITextField *txt = (UITextField *)sender;
        
        CGFloat vertGap = self.view.frame.size.height - txt.frame.origin.y - txt.frame.size.height - _keyboardHeight;
        int rowHeightsCount = vertGap / txt.frame.size.height;
        
        // рассчитываем высоту таблицы таким образом, чтобы в ней умещалось целое число строк
        CGRect rect = CGRectMake(txt.frame.origin.x, txt.frame.origin.y + txt.frame.size.height, txt.frame.size.width, rowHeightsCount * txt.frame.size.height);
        
        [self.tvSearchReference setFrame:rect];
        
        [self.view addSubview:self.tvSearchReference];
    }
    
    _refTableName = @"REF_Measures";
    
    [self loadFilteredData:_refTableName with:((UITextField *)sender).text];
}

- (IBAction)categoryEditingDidEnd:(id)sender
{
    [self.tvSearchReference removeFromSuperview];
}

- (IBAction)measureEditingDidEnd:(id)sender
{
    [self.tvSearchReference removeFromSuperview];
}

//////////////////////////////////////////////////////////////////////
// делегат UITableViewDelegate для подбора значений из справочников //
//////////////////////////////////////////////////////////////////////

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"SearchCellItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        
        [cell.textLabel setFont:self.txtCategoryName.font];
    }
    
    NSDictionary *row = [_filteredData objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [row valueForKey:@"Name"];
    
    return cell;
}

// выбор строки в таблице подбора - установка значения поля
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *row = [_filteredData objectAtIndex:indexPath.row];
    
    NSString *docId = [row valueForKey:@"DocId"];
    NSString *name = [row valueForKey:@"Name"];
    
    // категория
    if ([_refTableName isEqualToString:@"REF_GoodCategories"])
    {
        _categoryId = docId;
        _categoryName = name;
        
        self.txtCategoryName.text = _categoryName;
    }
    else
        // единица измерения
        if ([_refTableName isEqualToString:@"REF_Measures"])
        {
            _measureId = docId;
            _measureName = name;
            
            self.txtMeasureName.text = _measureName;
        }
    
    // закрываем список подбора
    [self.tvSearchReference removeFromSuperview];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
{
    return [_filteredData count];
}

// высота строк соответствует высоте поля ввода
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.txtCategoryName.frame.size.height;
}

/////////////////////////////////
// делегат UITextFieldDelegate //
/////////////////////////////////

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == self.txtPrice)
    {
        NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        
        NSRegularExpression *regexDot = [NSRegularExpression regularExpressionWithPattern:@"^(?:|0|[1-9]\\d*)(\\.([0-9]{1,2})?)?$"
                                                                                  options:NSRegularExpressionCaseInsensitive
                                                                                    error:nil];
        NSRegularExpression *regexComma = [NSRegularExpression regularExpressionWithPattern:@"^(?:|0|[1-9]\\d*)(\\,([0-9]{1,2})?)?$"
                                                                                    options:NSRegularExpressionCaseInsensitive
                                                                                      error:nil];
        
        NSUInteger numberOfMatchesDot = [regexDot numberOfMatchesInString:newString
                                                                  options:0
                                                                    range:NSMakeRange(0, [newString length])];
        NSUInteger numberOfMatchesComma = [regexComma numberOfMatchesInString:newString
                                                                      options:0
                                                                        range:NSMakeRange(0, [newString length])];
        
        if ((numberOfMatchesDot == 0) && (numberOfMatchesComma == 0))
        {
            return NO;
        }
    }
    
    return YES;
}

// для сокрытия клавиатуры
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField)
    {
        [textField resignFirstResponder];
    }
    
    return NO;
}

@end