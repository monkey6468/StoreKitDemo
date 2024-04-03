//
//  ApplePayTool.h
//  Autophix
//
//  Created by autophix on 2023/7/25.
//  Copyright © 2023 ruperthuang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, StoreState) {
    StoreState_success = 100, // 购买成功
    StoreState_noProduct,    // 购买商品不存在
    StoreState_lists,         // 购买商品列表获取失败
    StoreState_noProductTag,  // 商品标识不存在
    StoreState_noNet,         // 无网络
    StoreState_start,
    StoreState_pay,
    StoreState_verifiedServer, // 等待服务器验证
    StoreState_userCancelled,
    StoreState_pending,
    StoreState_unowned,
    // 其它: SKPaymentTransactionState
};

@interface ApplePayTool : NSObject

- (void)requestAppleIAPWithProductID:(NSString *)productID
                         orderNumber:(NSString *)orderNumber
                            payBlock:(void (^)(StoreState status, NSString *receipt))payBlock;

@end

NS_ASSUME_NONNULL_END
