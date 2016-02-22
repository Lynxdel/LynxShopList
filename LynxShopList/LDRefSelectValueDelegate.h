//
//  LDRefSelectValueDelegate.h
//  LynxShopList
//
//  Created by Денис Ломанов on 23/11/13.
//  Copyright (c) 2013 Денис Ломанов. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol LDRefSelectValueDelegate <NSObject>

@required
- (void)setSelectedValue:(id)sender element:(NSString *)name key:(NSString *)value fromRef:(NSString *)tableName allValues:(NSDictionary *)values;

@end
