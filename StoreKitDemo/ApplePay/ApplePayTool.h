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
    StoreState_success = 100,        // 购买成功
    StoreState_verifiedServer = 101, // 等待服务器验证
    StoreState_userCancelled = 102,  // 用户取消支付
    StoreState_verifiedFailed = 103, // 校验失败
    StoreState_noProduct = 104,      // 购买商品不存在
    StoreState_lists = 105,          // 购买商品列表获取失败
    StoreState_noProductTag = 106,   // 商品标识不存在
    StoreState_start = 107,
    StoreState_pay = 108,
    StoreState_pending = 109,
    StoreState_noLogin = 110, // 没有登录
    StoreState_unowned = 111,
    //    StoreState_finish = 112,
    StoreState_refundSuccess = 200,
    StoreState_refundFailed = 201,
    // 其它: SKPaymentTransactionState
};
typedef NS_ENUM(NSInteger, ApplePayType) {
    ApplePayType_V1,
    ApplePayType_V2,
};

@interface PayResponse : NSObject

@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *receipt;

@property (nonatomic, strong) NSString *transactionId;
@property (nonatomic, strong) NSDate *purchaseDate;
@property (nonatomic, strong) NSString *inAppOwnershipType;
@property (nonatomic, strong) NSString *currency;
@property (nonatomic, strong) NSString *price;

@end

@interface ApplePayResponse : NSObject

@property (nonatomic, assign) ApplePayType type;
@property (nonatomic, assign) StoreState status;

@property (nonatomic, strong) PayResponse *response;

@end

@interface ApplePayTool : NSObject

typedef void(^ApplePayBlock)(ApplePayResponse *response);

@property (copy, nonatomic) ApplePayBlock payBlock;

- (void)requestAppleIAPWithProductID:(NSString *)productID
                                uuid:(nonnull NSString *)uuid
                            payBlock:(ApplePayBlock)payBlock;

- (void)requestRefundWithTransactionId:(NSString *)transactionId
                                 block:(ApplePayBlock)payBlock;
@end

NS_ASSUME_NONNULL_END
