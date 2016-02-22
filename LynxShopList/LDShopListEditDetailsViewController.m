//
//  LDShopListEditDetailsViewController.m
//  LynxShopList
//
//  Created by Денис Ломанов on 06/06/14.
//  Copyright (c) 2014 Денис Ломанов. All rights reserved.
//

#import "LDShopListEditDetailsViewController.h"

@interface LDShopListEditDetailsViewController ()
{
    CGFloat _keyboardHeight;    // высота клавиатуры
    
    NSMutableArray *_filteredRefData;   // массив отобранных строк справочника магазинов
}

@end

@implementation LDShopListEditDetailsViewController

@synthesize parentListViewController;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.slidingViewController setAnchorLeftPeekAmount:40.0f];
    self.slidingViewController.underRightWidthLayout = ECVariableRevealWidth;
    
    self.view.layer.borderColor = [[UIColor blackColor] CGColor];
    self.view.layer.borderWidth = 0.5f;
    
    // таблица для подбора магазина
    self.tvSearchReference = [[UITableView alloc] init];
    self.tvSearchReference.layer.cornerRadius = 5.0;
    self.tvSearchReference.clipsToBounds = YES;
    [self.tvSearchReference setDataSource:self];
    [self.tvSearchReference setDelegate:self];
    [self.tvSearchReference.layer setBorderColor:[[[UIColor grayColor] colorWithAlphaComponent:0.5] CGColor]];
    [self.tvSearchReference.layer setBorderWidth:0.5];
    
    // регистрируем обработчик появления клавиатуры
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(keyboardOnScreen:) name:UIKeyboardDidShowNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self becomeFirstResponder];
    
    LDShopListEditViewController *parentView = (LDShopListEditViewController *)self.parentListViewController;
    
    // переносим данные на форму
    self.txtListName.text = parentView.listName;
    _shopId = parentView.shopId;
    self.txtShopName.text = parentView.shopName;
}

// для сокрытия клавиатуры
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.txtListName resignFirstResponder];
    [self.txtShopName resignFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self resignFirstResponder];
    
    [self saveListByParentView];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

//////////////////////////
// справочник магазинов //
//////////////////////////

- (IBAction)shopEditingChanged:(id)sender
{
    // сбрасываем имеющееся значение при начале редактирования
    _shopId = @"0";
    
    // предпоследний контрол не должен быть UITableView
    id lastSubview = [self.view.subviews objectAtIndex:(self.view.subviews.count - 2)];
    
    // если таблица для подбора еще не присутсвует на форме, выводим ее
    if (![lastSubview isKindOfClass:[UITableView class]])
    {
        UITextField *txt = (UITextField *)sender;
        
        CGFloat vertGap = self.view.frame.size.height - txt.frame.origin.y - txt.frame.size.height - _keyboardHeight;
        int rowHeightsCount = vertGap / txt.frame.size.height;
        
        // рассчитываем высоту таблицы таким образом, чтобы в ней умещалось целое число строк
        CGRect rect = CGRectMake(txt.frame.origin.x, txt.frame.origin.y + txt.frame.size.height, self.txtListName.frame.size.width, rowHeightsCount * txt.frame.size.height);
        
        [self.tvSearchReference setFrame:rect];
        
        [self.view addSubview:self.tvSearchReference];
    }
    
    [self loadFilteredShops:((UITextField *)sender).text];
}

- (IBAction)shopEditingDidEnd:(id)sender
{
    [self.tvSearchReference removeFromSuperview];    
}

// извлечение данных справочника магазинов из БД
- (void)loadFilteredShops:(NSString *)namesLike
{
    // доступ к глобальному объекту приложения
    LDAppDelegate *appDelegate = (LDAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // необходимо подключение к локальной БД
    FMDatabase *db = appDelegate.localDB.db;
    
    if (db != nil)
    {
        NSString *where = [NSString stringWithFormat:@"Name_lower LIKE '%@%%'", [namesLike lowercaseString]];
        
        FMResultSet *qry = [db executeQuery:[NSString stringWithFormat:@"SELECT DocId, Name \
                                                                         FROM REF_Shops \
                                                                         WHERE %@ \
                                                                         ORDER BY IFNULL(Name_lower, '')", where]];
        [_filteredRefData removeAllObjects];
        _filteredRefData = [[NSMutableArray alloc] init];
        
        while([qry next])
        {
            NSString *docId = [qry stringForColumn:@"DocId"];
            NSString *name = [qry stringForColumn:@"Name"];
            
            NSMutableDictionary *row = [[NSMutableDictionary alloc] init];
            
            [row setObject:docId forKey:@"DocId"];
            [row setObject:name forKey:@"Name"];
            
            [_filteredRefData addObject:row];
        }
    }
    
    [self.tvSearchReference reloadData];
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

/////////////////////////////////////////
// переход к табличной форме магазинов //
/////////////////////////////////////////

- (IBAction)selectShopButton:(id)sender
{
    // возвращаемся в список
    [self.slidingViewController resetTopView];
    
    LDShopListEditViewController *parentView = (LDShopListEditViewController *)self.parentListViewController;
    
    // выполняем переход
    [parentView performSelectShopSegue];
}

/////////////////////////////////////////////
// Реализация делегата UITableViewDelegate //
/////////////////////////////////////////////

// высота ячеек
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.txtShopName.frame.size.height;
}

// отображение ячейки (товары)
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"SearchCellItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        
        [cell.textLabel setFont:self.txtShopName.font];
    }
    
    NSDictionary *row = [_filteredRefData objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [row valueForKey:@"Name"];
    
    return cell;
}

// выбор строки - открытие формы редактирования
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *row = [_filteredRefData objectAtIndex:indexPath.row];
    
    NSString *docId = [row valueForKey:@"DocId"];
    NSString *name = [row valueForKey:@"Name"];
    
    _shopId = docId;
    self.txtShopName.text = name;
    
    // закрываем список подбора
    [self.tvSearchReference removeFromSuperview];
}

// число записей (товаров) в секции (категории)
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
{
    return [_filteredRefData count];
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

//////////////////////////////////////
// кнопки и вспомогательные функции //
//////////////////////////////////////

// сохранение списка с помощью вызова метода родительского view
- (BOOL)saveListByParentView
{
    LDShopListEditViewController *parentView = (LDShopListEditViewController *)self.parentListViewController;
    
    // сохраняем введенные данные
    parentView.listName = self.txtListName.text;
    parentView.shopName = self.txtShopName.text;
    parentView.shopId = _shopId;
    
    return [parentView saveList:NO];
}

// отправка списка по e-mail
- (IBAction)sendByEMailButton:(id)sender
{
    @try
    {
        if ([self saveListByParentView])
        {
            LDShopListEditViewController *parentView = (LDShopListEditViewController *)self.parentListViewController;
            
            // формируем XML-данные
            NSData *xmlData = [LDShopListXML createXMLDataByList:parentView.docId];
            
            if (xmlData != nil)
            {
                NSString *fileName = [NSString stringWithFormat:@"ShopList%@.lsl", parentView.docId];
                
                // сохраняем данные в файл
                if ([LDShopListXML saveXMLDataToFile:xmlData withName:fileName])
                {
                    MFMailComposeViewController *composer = [[MFMailComposeViewController alloc] init];
                    [composer setMailComposeDelegate:self];
                    
                    if ([MFMailComposeViewController canSendMail])
                    {
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
        else
        {
            UIAlertView *info = [[UIAlertView alloc] initWithTitle:@"Ошибка"
                                                           message:@"Не удалось сохранить список"
                                                          delegate:nil
                                                 cancelButtonTitle:@"OK"
                                                 otherButtonTitles:nil];
            [info show];
        }
    }
    @catch (NSException *exception)
    {
        UIAlertView *info = [[UIAlertView alloc] initWithTitle:@"Ошибка"
                                                       message:exception.reason
                                                      delegate:nil
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
        [info show];
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{    
    [controller dismissViewControllerAnimated:YES completion:nil];
    
    LDShopListEditViewController *parentView = (LDShopListEditViewController *)self.parentListViewController;
    
    [parentView.slidingViewController resetTopView];    
}

@end