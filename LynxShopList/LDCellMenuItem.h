//
//  LDCellMenuItem.h
//  LynxShopList
//
//  Created by Денис Ломанов on 15/04/14.
//  Copyright (c) 2014 Денис Ломанов. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LDCellMenuItem : UIMenuItem

@property (nonatomic) NSIndexPath *indexPath;   // индекс ячейки таблицы, для которой вызван пункт меню

@end
