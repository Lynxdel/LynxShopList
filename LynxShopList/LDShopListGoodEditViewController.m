//
//  LDShopListGoodEditViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 28/12/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDShopListGoodEditViewController.h"

@interface LDShopListGoodEditViewController ()
{
    NSString *_docId;
    
    NSString *_goodId;
    NSString *_goodName;
    
    NSString *_measureName;
    NSString *_measureName234;
    NSString *_measureName567890;
    
    double _qty;
    double _incQty;
    double _price;
    double _amount;
    
    NSString *_comments;
    
    BOOL _isBusy;   // флаг текущей обработки данных
}

@end

@implementation LDShopListGoodEditViewController

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
    
    // граница поля примечаний - как у однострочных полей ввода
    [self.txtComment.layer setBorderColor:[[[UIColor grayColor] colorWithAlphaComponent:0.5] CGColor]];
    [self.txtComment.layer setBorderWidth:0.5];
    
    self.txtComment.layer.cornerRadius = 5.0;
    self.txtComment.clipsToBounds = YES;
    
    self.txtComment.text = @"";
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
    self.txtGoodName.text = _goodName;
    self.txtMeasureName.text = _measureName;
    
    self.txtQty.text = [NSString stringWithFormat:@"%.3f", _qty];
    self.txtPrice.text = [NSString stringWithFormat:@"%.2f", _price];
    self.txtAmount.text = [NSString stringWithFormat:@"%.2f", _amount];
    
    if (_qty < self.stepperQty.minimumValue) self.stepperQty.minimumValue = _qty;
    if (_qty > self.stepperQty.maximumValue) self.stepperQty.maximumValue = _qty;
    
    self.stepperQty.stepValue = _incQty;
    self.stepperQty.value = _qty;
    
    self.txtComment.text = _comments;
    
    [self setCorrectMeasureName];
}

// для сокрытия клавиатуры
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.txtQty resignFirstResponder];
    [self.txtPrice resignFirstResponder];
    [self.txtAmount resignFirstResponder];
    [self.txtComment resignFirstResponder];
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
            FMResultSet *qryGood = [db executeQuery:[NSString stringWithFormat:@"SELECT   sg.GoodId \
                                                                                        , g.Name as GoodName \
                                                                                        , IFNULL(m.Name, '') as MeasureName \
                                                                                        , IFNULL(m.Name234, '') as MeasureName234 \
                                                                                        , IFNULL(m.Name567890, '') as MeasureName567890 \
                                                                                        , IFNULL(sg.Price, 0) as Price \
                                                                                        , IFNULL(sg.Qty, 0) as Qty \
                                                                                        , IFNULL(sg.Amount, 0) as Amount \
                                                                                        , IFNULL(m.IncQty, 1) as IncQty \
                                                                                        , IFNULL(sg.Comments, '') as Comments \
                                                                                 FROM ShopListGoods sg \
                                                                                        INNER JOIN REF_Goods g \
                                                                                            ON sg.GoodId = g.DocId \
                                                                                        LEFT JOIN REF_Measures m \
                                                                                            ON m.DocId = g.MeasureId \
                                                                                 WHERE (sg.DocId = %@)", _docId]];
            if ([qryGood next])
            {
                _goodId = [qryGood stringForColumn:@"GoodId"];
                _goodName = [qryGood stringForColumn:@"GoodName"];
                
                _measureName = [qryGood stringForColumn:@"MeasureName"];
                _measureName234 = [qryGood stringForColumn:@"MeasureName234"];
                _measureName567890 = [qryGood stringForColumn:@"MeasureName567890"];
                
                _price = [qryGood doubleForColumn:@"Price"];
                _qty = [qryGood doubleForColumn:@"Qty"];
                _incQty = [qryGood doubleForColumn:@"IncQty"];
                _amount = [qryGood doubleForColumn:@"Amount"];
                
                _comments = [qryGood stringForColumn:@"Comments"];
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

// обновление записи
- (void)saveData
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
            NSMutableDictionary *argsDict = [[NSMutableDictionary alloc] init];
            
            [self setPriceFromText];
            [self setQtyFromText];
            [self setAmountFromText];
            
            _amount = _price * _qty;
            
            [argsDict setObject:[NSNumber numberWithDouble:_price] forKey:@"Price"];
            [argsDict setObject:[NSNumber numberWithDouble:_qty] forKey:@"Qty"];
            [argsDict setObject:[NSNumber numberWithDouble:_amount] forKey:@"Amount"];
            [argsDict setObject:self.txtComment.text forKey:@"Comments"];
            [argsDict setObject:[NSDate date] forKey:@"EditDate"];
            [argsDict setObject:_docId forKey:@"DocId"];
            
            BOOL result = NO;
            
            result = [db executeUpdate:@"UPDATE ShopListGoods \
                                         SET   Price = :Price \
                                             , Qty = :Qty \
                                             , Amount = :Amount \
                                             , Comments = :Comments \
                                             , EditDate = :EditDate \
                                         WHERE DocId = :DocId" withParameterDictionary:argsDict];
            
            if (result)
            {
                // обновляем цену в карточке товара
                @try
                {
                    [db executeUpdate:@"UPDATE REF_Goods \
                                        SET   Price = :Price \
                                            , EditDate = :EditDate \
                                        WHERE DocId = :GoodId" withParameterDictionary:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:_price], @"Price",
                                                                                                                                                       [NSDate date], @"EditDate",
                                                                                                                                                             _goodId, @"GoodId", nil]];
                }
                @finally
                {
                    // возвращаемся в список
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
}

///////////////////////
// события контролов //
///////////////////////

// изменение количества с помощью степпера
- (IBAction)stepperQtyValueChanged:(id)sender
{
    self.txtQty.text = [NSString stringWithFormat:@"%.3f", self.stepperQty.value];
    _qty = self.stepperQty.value;
    
    _amount = _price * _qty;
    self.txtAmount.text = [NSString stringWithFormat:@"%.2f", _amount];
    
    [self setCorrectMeasureName];
}

// изменение цены в поле ввода
- (IBAction)priceTextEditingEnded:(id)sender
{
    [self setPriceFromText];
    
    _amount = _price * _qty;
    self.txtAmount.text = [NSString stringWithFormat:@"%.2f", _amount];
}

- (IBAction)amountTextEditingEnded:(id)sender
{
    [self setAmountFromText];
    
    _price = _amount / _qty;
    self.txtPrice.text = [NSString stringWithFormat:@"%.2f", _price];
}

// изменение количества непосредственно в поле ввода
- (IBAction)qtyTextEditingEnded:(id)sender
{
    [self setQtyFromText];
    
    _amount = _price * _qty;
    self.txtAmount.text = [NSString stringWithFormat:@"%.2f", _amount];
    
    [self setCorrectMeasureName];
}

- (IBAction)saveShopListGood:(id)sender
{
    [self saveData];
}

///////////////////////////////
// вспомогательные процедуры //
///////////////////////////////

- (void)setEditMode:(NSString *)docId
{
    _docId = docId;
    
    [self loadData];
}

// установка цены на основе данных поля ввода
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
        // при ошибке преобразования строки в число восстанавливаем в поле ввода значение из поля класса
        self.txtPrice.text = [NSString stringWithFormat:@"%.3f", _price];
    }
}

// установка значения кол-ва на основе данных поля ввода
- (void)setQtyFromText
{
    NSScanner *scanner = [NSScanner scannerWithString:[self.txtQty.text stringByReplacingOccurrencesOfString:@"," withString:@"."]];
    
    double value = 0;
    
    if ([scanner scanDouble:&value])
    {
        self.stepperQty.value = value;
    }
    else
    {
        // при ошибке преобразования строки в число восстанавливаем в поле ввода значение из счетчика
        self.txtQty.text = [NSString stringWithFormat:@"%.3f", self.stepperQty.value];
    }
    
    _qty = self.stepperQty.value;
}

// установка значения суммы на основе данных поля ввода
- (void)setAmountFromText
{
    NSScanner *scanner = [NSScanner scannerWithString:[self.txtAmount.text stringByReplacingOccurrencesOfString:@"," withString:@"."]];
    
    double value = 0;
    
    if ([scanner scanDouble:&value])
    {
        _amount = value;
    }
    else
    {
        // при ошибке преобразования строки в число восстанавливаем в поле ввода значение из поля класса
        self.txtAmount.text = [NSString stringWithFormat:@"%.3f", _amount];
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

// установка наименования единицы измерения в склонении, соответствующем числу едениц
- (void)setCorrectMeasureName
{
    // склоняем наименование единицы измерения
    int modQty = (int)fmodf(trunc(_qty), 10);
    
    NSString *measureName = _measureName;
    
    if ((modQty >= 2) && (modQty <= 4))
    {
        measureName = _measureName234;
    }
    else
        if ((modQty == 0) || ((modQty >= 5) && (modQty <= 9)))
        {
            measureName = _measureName567890;
        }
    
    if ([measureName isEqualToString:@""]) measureName = _measureName;
    
    self.txtMeasureName.text = measureName;
}

/////////////////////////////////
// делегат UITextFieldDelegate //
/////////////////////////////////

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if ((textField == self.txtPrice) || (textField == self.txtQty) || (textField == self.txtAmount))
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
    if ((textField == self.txtPrice) || (textField == self.txtQty) || (textField == self.txtAmount))
    {
        [textField resignFirstResponder];
        return NO;
    }
    else return YES;
}

@end
