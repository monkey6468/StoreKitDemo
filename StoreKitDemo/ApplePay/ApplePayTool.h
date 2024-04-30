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
    StoreState_success = 100,  // 购买成功
    StoreState_verifiedServer, // 等待服务器验证
    StoreState_userCancelled,  // 用户取消支付
    StoreState_verifiedFailed, // 校验失败
    StoreState_noProduct,      // 购买商品不存在
    StoreState_lists,          // 购买商品列表获取失败
    StoreState_noProductTag,   // 商品标识不存在
    StoreState_start,
    StoreState_pay,
    StoreState_pending,
    StoreState_unowned,
    // 其它: SKPaymentTransactionState
};

typedef NS_ENUM(NSInteger, ApplePayType) {
    ApplePayType_V1,
    ApplePayType_V2,
};

@interface ApplePayResponse : NSObject

@property (nonatomic, assign) ApplePayType type;
@property (nonatomic, assign) StoreState status;

// payDict 「[self getPayId]:{receipt，currency，price}」，因为内部有存储，但v1版本自己服务器验证成功后，需要移除 [[KKApplePayManner sharedInstance] deleteByPaymentVoucher:self.payDict];
@property (nonatomic, strong) NSDictionary *payDict;
@property (nonatomic, strong) NSString *transactionId;
@property (nonatomic, strong) NSString *originalID;

@end

@interface ApplePayTool : NSObject

typedef void(^ApplePayBlock)(ApplePayResponse *response);

@property (copy, nonatomic) ApplePayBlock payBlock;

- (void)requestAppleIAPWithProductID:(NSString *)productID
                         orderNumber:(nonnull NSString *)orderNumber
                            payBlock:(ApplePayBlock)payBlock;

@end

NS_ASSUME_NONNULL_END
