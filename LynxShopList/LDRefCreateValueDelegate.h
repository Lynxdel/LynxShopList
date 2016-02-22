//
//  LDRefCreateValueDelegate.h
//  LynxShopList
//
//  Created by Денис Ломанов on 27/04/14.
//  Copyright (c) 2014 Денис Ломанов. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol LDRefCreateValueDelegate <NSObject>

@required
- (void)setCreatedValue:(id)sender element:(NSString *)name key:(NSString *)value fromRef:(NSString *)tableName allValues:(NSDictionary *)values;

@end
