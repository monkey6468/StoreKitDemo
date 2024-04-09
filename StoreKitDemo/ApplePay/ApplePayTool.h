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
@interface ApplePayTool : NSObject
// payDict，因为内部有存储，但v1版本自己服务器验证成功后，需要移除 [[KKApplePayManner sharedInstance] deleteByPaymentVoucher:self.payDict];
typedef void(^AppleV1Block)(StoreState status, NSString *receipt, NSDictionary *payDict);
typedef void(^AppleV2Block)(StoreState status, NSString *transactionId, NSString *originalID);

@property (copy, nonatomic) AppleV1Block payV1StatusBlock;
@property (copy, nonatomic) AppleV2Block payV2StatusBlock;

- (void)requestAppleIAPWithProductID:(NSString *)productID
                         orderNumber:(nonnull NSString *)orderNumber
                          payV1Block:(AppleV1Block)payV1Block
                          payV2Block:(AppleV2Block)payV2Block;

@end

NS_ASSUME_NONNULL_END
