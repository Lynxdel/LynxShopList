//
//  LDGoodCategoryEditViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 20/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDGoodCategoryEditViewController.h"

@interface LDGoodCategoryEditViewController ()
{
    NSString *_docId;
    NSString *_catName;
    
    BOOL _isBusy;   // флаг текущей обработки данных
    
    // составляющие цвета
    double _red;
    double _green;
    double _blue;
    double _alpha;
}

@end

@implementation LDGoodCategoryEditViewController

//////////////////
// события view //
//////////////////

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.txtCatName.text = _catName;
    
    // граница поля примечаний - как у однострочных полей ввода
    [self.pnlCatColor.layer setBorderColor:[[[UIColor grayColor] colorWithAlphaComponent:0.5] CGColor]];
    [self.pnlCatColor.layer setBackgroundColor:[[UIColor whiteColor] CGColor]];
    [self.pnlCatColor.layer setBorderWidth:0.5];
    
    self.pnlCatColor.layer.cornerRadius = 5.0;
    self.pnlCatColor.clipsToBounds = YES;
    
    // создаем индикатор, он невидим
    self.spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake((self.view.frame.size.width - 30.0) / 2.0, (self.view.frame.size.height - 30.0) / 2.0, 30, 30)];
    [self.spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:self.spinner];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self loadColors];
}

// для сокрытия клавиатуры
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.txtCatName resignFirstResponder];
}

//////////////////////
// работа с данными //
//////////////////////


// загрузка информации о цвете категории
- (void)loadColors
{
    if (![_docId isEqualToString:@"0"])
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
                FMResultSet *qryColor = [db executeQuery:[NSString stringWithFormat:@"SELECT   IFNULL(ColorR, 0.0) as R \
                                                                                             , IFNULL(ColorG, 0.0) as G \
                                                                                             , IFNULL(ColorB, 0.0) as B \
                                                                                             , IFNULL(ColorAlpha, 0.0) as A \
                                                                                      FROM REF_GoodCategories \
                                                                                      WHERE DocId = %@", _docId]];
                
                if ([qryColor next])
                {
                    _red = [qryColor doubleForColumn:@"R"];
                    _green = [qryColor doubleForColumn:@"G"];
                    _blue = [qryColor doubleForColumn:@"B"];
                    _alpha = [qryColor doubleForColumn:@"A"];
                    
                    [_sldR setValue:(float)(_red * 255.0) animated:NO];
                    [_sldG setValue:(float)(_green * 255.0) animated:NO];
                    [_sldB setValue:(float)(_blue * 255.0) animated:NO];
                    [_sldA setValue:(float)(_alpha * 255.0) animated:NO];
                    
                    self.lblR.text = [NSString stringWithFormat:@"%d", (int)(_red * 255.0)];
                    self.lblG.text = [NSString stringWithFormat:@"%d", (int)(_green * 255.0)];
                    self.lblB.text = [NSString stringWithFormat:@"%d", (int)(_blue * 255.0)];
                    self.lblA.text = [NSString stringWithFormat:@"%d", (int)(_alpha * 255.0)];
                    
                    [self.pnlCatColor.layer setBackgroundColor:[[UIColor colorWithRed:_red green:_green blue:_blue alpha:_alpha] CGColor]];
                }
                
                [qryColor close];
            }
            else
            {
                UIAlertView *info = [[UIAlertView alloc] initWithTitle:@"Не удалось извлечь данные"
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
}

// сохранение новой записи
- (void)saveCat
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
            
            // новая запись - INSERT
            if ([_docId isEqualToString:@"0"])
            {
                NSDictionary *argsDict = [NSDictionary dictionaryWithObjectsAndKeys:self.txtCatName.text, @"Name",
                                          [self.txtCatName.text lowercaseString], @"Name_lower",
                                          [NSNumber numberWithDouble:_red ], @"ColorR",
                                          [NSNumber numberWithDouble:_green ], @"ColorG",
                                          [NSNumber numberWithDouble:_blue ], @"ColorB",
                                          [NSNumber numberWithDouble:_alpha ], @"ColorAlpha",
                                          [NSDate date], @"CreateDate", nil];
                
                result = [db executeUpdate:@"INSERT INTO REF_GoodCategories (Name, Name_lower, ColorR, ColorG, ColorB, ColorAlpha, CreateDate) \
                                             VALUES (:Name, :Name_lower, :ColorR, :ColorG, :ColorB, :ColorAlpha, :CreateDate)" withParameterDictionary:argsDict];
            }
            // существующая - UPDATE
            else
            {
                NSDictionary *argsDict = [NSDictionary dictionaryWithObjectsAndKeys:self.txtCatName.text, @"Name",
                                          [self.txtCatName.text lowercaseString], @"Name_lower",
                                          [NSNumber numberWithDouble:_red], @"ColorR",
                                          [NSNumber numberWithDouble:_green], @"ColorG",
                                          [NSNumber numberWithDouble:_blue], @"ColorB",
                                          [NSNumber numberWithDouble:_alpha], @"ColorAlpha",
                                          [NSDate date], @"EditDate",
                                          _docId, @"DocId", nil];
                result = [db executeUpdate:@"UPDATE REF_GoodCategories \
                                             SET   Name = :Name \
                                                 , Name_lower = :Name_lower \
                                                 , ColorR = :ColorR \
                                                 , ColorG = :ColorG \
                                                 , ColorB = :ColorB \
                                                 , ColorAlpha = :ColorAlpha \
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

///////////////////////
// события контролов //
///////////////////////

// редактирование цвета категории
- (IBAction)sldValueChaged:(id)sender
{
    _red = self.sldR.value / 255.0;
    _green = self.sldG.value / 255.0;
    _blue = self.sldB.value / 255.0;
    _alpha = self.sldA.value;
    
    self.lblR.text = [NSString stringWithFormat:@"%d", (int)(_red * 255.0)];
    self.lblG.text = [NSString stringWithFormat:@"%d", (int)(_green * 255.0)];
    self.lblB.text = [NSString stringWithFormat:@"%d", (int)(_blue * 255.0)];
    self.lblA.text = [NSString stringWithFormat:@"%d", (int)(_alpha * 255.0)];
    
    [self.pnlCatColor.layer setBackgroundColor:[[UIColor colorWithRed:_red green:_green blue:_blue alpha:_alpha] CGColor]];
}

- (IBAction)saveCatButton:(id)sender
{
    [self saveCat];
}

- (IBAction)decRButton:(id)sender
{
    self.sldR.value -= 1;
    _red = self.sldR.value / 255.0;
    self.lblR.text = [NSString stringWithFormat:@"%d", (int)(_red * 255.0)];
}

- (IBAction)incRButton:(id)sender
{
    self.sldR.value += 1;
    _red = self.sldR.value / 255.0;
    self.lblR.text = [NSString stringWithFormat:@"%d", (int)(_red * 255.0)];
}

- (IBAction)decGButton:(id)sender
{
    self.sldG.value -= 1;
    _green = self.sldG.value / 255.0;
    self.lblG.text = [NSString stringWithFormat:@"%d", (int)(_green * 255.0)];
}

- (IBAction)incGButton:(id)sender
{
    self.sldG.value += 1;
    _green = self.sldG.value / 255.0;
    self.lblG.text = [NSString stringWithFormat:@"%d", (int)(_green * 255.0)];
}

- (IBAction)decBButton:(id)sender
{
    self.sldB.value -= 1;
    _blue = self.sldB.value / 255.0;
    self.lblB.text = [NSString stringWithFormat:@"%d", (int)(_blue * 255.0)];
}

- (IBAction)incBButton:(id)sender
{
    self.sldB.value += 1;
    _blue = self.sldB.value / 255.0;
    self.lblB.text = [NSString stringWithFormat:@"%d", (int)(_blue * 255.0)];
}

- (IBAction)decAlphaButton:(id)sender
{
    self.sldA.value -= self.sldA.maximumValue / 255.0;
    _alpha = self.sldA.value;
    self.lblA.text = [NSString stringWithFormat:@"%d", (int)(_alpha * 255.0)];
}

- (IBAction)incAlphaButton:(id)sender
{
    self.sldA.value += self.sldA.maximumValue / 255.0;
    _alpha = self.sldA.value;
    self.lblA.text = [NSString stringWithFormat:@"%d", (int)(_alpha * 255.0)];
}

///////////////////////////////
// вспомогательные процедуры //
///////////////////////////////

// создание новой записи
- (void)setNewCatMode
{
    _docId = @"0";
    _catName = @"";
    
    _red = 1.0;
    _green = 1.0;
    _blue = 1.0;
    _alpha = 1.0;
    
    self.lblR.text = [NSString stringWithFormat:@"%d", (int)(_red * 255.0)];
    self.lblG.text = [NSString stringWithFormat:@"%d", (int)(_green * 255.0)];
    self.lblB.text = [NSString stringWithFormat:@"%d", (int)(_blue * 255.0)];
    self.lblA.text = [NSString stringWithFormat:@"%d", (int)(_alpha * 255.0)];
}

// редактирование или удаление текущей записи
- (void)setEditCatMode:(NSString *)docId withName:(NSString *)catName;
{
    _docId = docId;
    _catName = catName;
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
