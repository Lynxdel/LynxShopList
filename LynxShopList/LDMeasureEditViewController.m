//
//  LDMeasureEditViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 08/02/14.
//  Copyright (c) 2014 Денис Ломанов. All rights reserved.
//

#import "LDMeasureEditViewController.h"

@interface LDMeasureEditViewController ()
{
    NSString *_docId;
    
    NSString *_measureName;
    NSString *_measureName234;
    NSString *_measureName567890;
    
    double _incQty;
    
    BOOL _isBusy;   // флаг текущей обработки данных
}

@end

@implementation LDMeasureEditViewController

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
}

- (void)viewDidAppear:(BOOL)animated
{
    self.txtMeasureName.text = _measureName;
    self.txtMeasureName234.text = _measureName234;
    self.txtMeasureName567890.text = _measureName567890;
    self.txtIncQty.text = [NSString stringWithFormat:@"%.3f", _incQty];
}

// для сокрытия клавиатуры
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.txtMeasureName resignFirstResponder];
    [self.txtMeasureName234 resignFirstResponder];
    [self.txtMeasureName567890 resignFirstResponder];
    [self.txtIncQty resignFirstResponder];
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
            FMResultSet *qryMeasure = [db executeQuery:[NSString stringWithFormat:@"SELECT   Name \
                                                                                           , Name234 \
                                                                                           , Name567890 \
                                                                                           , IFNULL(IncQty, 1.0) AS IncQty \
                                                                                    FROM REF_Measures \
                                                                                    WHERE (DocId = %@)", _docId]];
            if ([qryMeasure next])
            {
                _measureName = [qryMeasure stringForColumn:@"Name"];
                _measureName234 = [qryMeasure stringForColumn:@"Name234"];
                _measureName567890 = [qryMeasure stringForColumn:@"Name567890"];
                _incQty = [qryMeasure doubleForColumn:@"IncQty"];
            }
            
            [qryMeasure close];
        }
    }
    @finally
    {
        _isBusy = NO;
        
        [self.spinner stopAnimating];
    }
}

// сохранение новой записи
- (void)saveMeasure
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
            
            [self setIncQtyFromText];
            
            // новая запись - INSERT
            if ([_docId isEqualToString:@"0"])
            {
                NSDictionary *argsDict = [NSDictionary dictionaryWithObjectsAndKeys:self.txtMeasureName.text, @"Name",
                                                                  [self.txtMeasureName.text lowercaseString], @"Name_lower",
                                                                                 self.txtMeasureName234.text, @"Name234",
                                                                              self.txtMeasureName567890.text, @"Name567890",
                                                                         [NSNumber numberWithDouble:_incQty], @"IncQty",
                                                                                               [NSDate date], @"CreateDate", nil];
                
                result = [db executeUpdate:@"INSERT INTO REF_Measures (Name, Name_lower, Name234, Name567890, IncQty, CreateDate) \
                                             VALUES (:Name, :Name_lower, :Name234, :Name567890, :IncQty, :CreateDate)" withParameterDictionary:argsDict];
            }
            // существующая - UPDATE
            else
            {
                NSDictionary *argsDict = [NSDictionary dictionaryWithObjectsAndKeys:self.txtMeasureName.text, @"Name",
                                                                  [self.txtMeasureName.text lowercaseString], @"Name_lower",
                                                                                 self.txtMeasureName234.text, @"Name234",
                                                                              self.txtMeasureName567890.text, @"Name567890",
                                                                         [NSNumber numberWithDouble:_incQty], @"IncQty",
                                                                                               [NSDate date], @"EditDate",
                                                                                                      _docId, @"DocId", nil];
                
                result = [db executeUpdate:@"UPDATE REF_Measures \
                                             SET   Name = :Name \
                                                 , Name_lower = :Name_lower \
                                                 , Name234 = :Name234 \
                                                 , Name567890 = :Name567890 \
                                                 , IncQty = :IncQty \
                                                 , EditDate = :EditDate \
                                             WHERE DocId = :DocId" withParameterDictionary:argsDict];
            }
            
            if (result)
            {
                // все в порядке возвращаемся в список
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

///////////////////////
// события контролов //
///////////////////////

- (IBAction)incQtyTextEditingEnded:(id)sender
{
    [self setIncQtyFromText];
}

- (IBAction)saveMeasureButton:(id)sender
{
    [self saveMeasure];
}

- (IBAction)measureNameChanged:(id)sender
{
    _measureName = self.txtMeasureName.text;
    
    _measureName234 = _measureName;
    self.txtMeasureName234.text = _measureName;
    
    _measureName567890 = _measureName;
    self.txtMeasureName567890.text = _measureName;
}

///////////////////////////////
// вспомогательные процедуры //
///////////////////////////////

// создание новой записи
- (void)setNewMeasureMode
{
    _docId = @"0";
    _measureName = @"";
    _measureName234 = @"";
    _measureName567890 = @"";
    _incQty = 1.0;
}

// редактирование или удаление текущей записи
- (void)setEditMeasureMode:(NSString *)docId;
{
    _docId = docId;
        
    [self loadData];
}

// установка значения приращения на основе текста из поля ввода
- (void)setIncQtyFromText
{
    NSScanner *scanner = [NSScanner scannerWithString:[self.txtIncQty.text stringByReplacingOccurrencesOfString:@"," withString:@"." ]];
    
    double value = 0;
    
    if ([scanner scanDouble:&value])
    {
        _incQty = value;
    }
    else
    {
        // при ошибке преобразования строки в число восстанавливаем в поле ввода значение из счетчика
        self.txtIncQty.text = [NSString stringWithFormat:@"%.3f", _incQty];
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

/////////////////////////////////
// делегат UITextFieldDelegate //
/////////////////////////////////

// обработка ввода шага редактирования
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == self.txtIncQty)
    {
        NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        
        NSRegularExpression *regexDot = [NSRegularExpression regularExpressionWithPattern:@"^(?:|0|[1-9]\\d*)(\\.([0-9]{1,3})?)?$"
                                                                                  options:NSRegularExpressionCaseInsensitive
                                                                                    error:nil];
        NSRegularExpression *regexComma = [NSRegularExpression regularExpressionWithPattern:@"^(?:|0|[1-9]\\d*)(\\,([0-9]{1,3})?)?$"
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
