//
//  LDShopEditViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 17/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import "LDShopEditViewController.h"

@interface LDShopEditViewController ()
{
    NSString *_docId;
    NSString *_shopName;
    
    BOOL _isBusy;   // флаг текущей обработки данных
}

@end

@implementation LDShopEditViewController

//////////////////
// события view //
//////////////////

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.txtShopName.text = _shopName;
    
    _isBusy = NO;
    
    // создаем индикатор, он невидим
    self.spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake((self.view.frame.size.width - 30.0) / 2.0, (self.view.frame.size.height - 30.0) / 2.0, 30, 30)];
    [self.spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:self.spinner];
}

// для сокрытия клавиатуры
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.txtShopName resignFirstResponder];
}

//////////////////////
// работа с данными //
//////////////////////

// сохранение новой записи
- (void)saveShop
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
                NSDictionary *argsDict = [NSDictionary dictionaryWithObjectsAndKeys:self.txtShopName.text, @"Name", [self.txtShopName.text lowercaseString], @"Name_lower", [NSDate date], @"CreateDate", nil];
                
                result = [db executeUpdate:@"INSERT INTO REF_Shops (Name, Name_lower, CreateDate) \
                                             VALUES (:Name, :Name_lower, :CreateDate)" withParameterDictionary:argsDict];
            }
            // существующая - UPDATE
            else
            {
                NSDictionary *argsDict = [NSDictionary dictionaryWithObjectsAndKeys:self.txtShopName.text, @"Name", [self.txtShopName.text lowercaseString], @"Name_lower", [NSDate date], @"EditDate", _docId, @"DocId", nil];
                
                result = [db executeUpdate:@"UPDATE REF_Shops \
                                             SET   Name = :Name \
                                                 , Name_lower = :Name_lower \
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

- (IBAction)saveShopButton:(id)sender
{
    [self saveShop];
}

///////////////////////////////
// вспомогательные процедуры //
///////////////////////////////

// создание новой записи
- (void)setNewShopMode
{
    _docId = @"0";
    _shopName = @"";
}

// редактирование или удаление текущей записи
- (void)setEditShopMode:(NSString *)docId withName:(NSString *)shopName;
{
    _docId = docId;
    _shopName = shopName;
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
