//
//  ApplePayTool.m
//  Autophix
//
//  Created by autophix on 2023/7/25.
//  Copyright © 2023 ruperthuang. All rights reserved.
//

#import "ApplePayTool.h"
#import "KKApplePayManner.h"
#import "StoreKitDemo-Swift.h"

@interface ApplePayTool ()

@property (nonatomic, copy) void (^payStatusBlock)(StoreState status, NSString *receipt);

@property (nonatomic, strong) NSDictionary *payDictTemp;
@property (nonatomic, copy) NSString *productID; // 商品标识，苹果内购需提供（开发者网站设置时必须为大写）
@property (nonatomic, copy) NSString *receipt;  // 苹果支付成功的凭证
@property (nonatomic, copy) NSString *orderNumber;

@end

@implementation ApplePayTool

- (void)requestAppleIAPWithProductID:(NSString *)productID
                         orderNumber:(nonnull NSString *)orderNumber
                            payBlock:(nonnull void (^)(StoreState, NSString *_Nonnull))payBlock {
    self.productID = productID;
    self.orderNumber = orderNumber;
    self.payStatusBlock = payBlock;
    
    [self payGoodsWithStoreKit];
}

- (void)payGoodsWithStoreKit {
    if (self.productID.length == 0) {
        [self returnResultWithStatus:StoreState_noProductTag];
        return;
    }
    
    if (@available(iOS 15.0, *)) {
        NSLog(@"Apple购买StoreKit2");
        [self payGoodsWithStoreKit2];
    } else {
        NSLog(@"Apple购买StoreKit1");
        [self payGoodsWithStoreKit1];
    }
}

- (void)payGoodsWithStoreKit2 {
    ApplePay2Manger *manger = [[ApplePay2Manger alloc]init];
    [manger storeKitLaunch];
    [manger storeKitPayWithProductId:self.productID orderID:self.orderNumber];
    __strong typeof(self) sself = self;
    manger.payClosure = ^(StoreState status) {
        [sself returnResultWithStatus:status];
    };
}

- (void)payGoodsWithStoreKit1 {
    // 验证本地是否存在
    [[KKApplePayManner sharedInstance] checkInternalPurchasePayment:^(NSArray *items, NSError *error) {
        if (items.count) {
            NSString *currentKey = [self getPayId];
            NSString *receipt = nil;
            NSMutableArray *list = [NSMutableArray array];
            for (NSDictionary *payDict in items) {
                if (payDict.allKeys.count) {
                    [list addObjectsFromArray:payDict.allKeys];
                }
                receipt = payDict[currentKey];
                if (receipt.length) {
                    self.payDictTemp = payDict;
                }
            }
            // LOG_D(@"Apple已购买成功商品列表: %@", list);
            if (receipt.length) {
                self.receipt = receipt;
                [self returnResultWithStatus:StoreState_success];
            } else {
                [self payGoodsWithApple];
            }
        } else {
            [self payGoodsWithApple];
        }
    }];
}

- (void)payGoodsWithApple {
    [self returnResultWithStatus:StoreState_start];
    [[KKApplePayManner sharedInstance] requestProducts:@[ self.productID ]
                                        withCompletion:^(SKProductsRequest *request, SKProductsResponse *response, NSError *error) {
        if (!error) {
            NSArray *products = [KKApplePayManner sharedInstance].products;
            if (products.count <= 0) {
                [self returnResultWithStatus:StoreState_noProduct];
            } else {
                [self requestPayGood];
            }
        } else {
            [self returnResultWithStatus:StoreState_lists];
        }
    }];
}

- (void)requestPayGood {
    [self returnResultWithStatus:StoreState_pay];
    NSArray *products = [KKApplePayManner sharedInstance].products;
    [[KKApplePayManner sharedInstance] buyProduct:products.firstObject
                                     onCompletion:^(SKPaymentTransaction *transaction, NSError *error) {
        if (!error) {
            NSString *receipt = [KKApplePayManner sharedInstance].appStoreReceiptbase64EncodedString ?: @"";
            //            NSString *transactionIdentifier = transaction.transactionIdentifier ?: @"";
            //            NSString *productIdentifier = transaction.payment.productIdentifier;
            //            NSDictionary *dicInfo = @{
            //                @"receiptData" : receipt,
            //                @"orderNumber" : self.orderNumber,
            //                @"transactionId" : transactionIdentifier,
            //                @"productId" : self.goodsTag,
            //                @"sn" : self.sn,
            //            };
            NSString *key = [self getPayId];
            NSMutableDictionary *payDict = [NSMutableDictionary dictionary];
            payDict[key] = receipt;
            [[KKApplePayManner sharedInstance] savePaymentVoucher:payDict];
            self.receipt = receipt;
            [self returnResultWithStatus:StoreState_success];
        } else {
            [self returnResultWithStatus:(StoreState)transaction.transactionState];
        }
    }];
}

- (void)returnResultWithStatus:(StoreState)status {
    //    LOG_D(@"Apple购买商品状态:%@, %ld",[self getPayId], status);
    NSLog(@"Apple购买商品状态:%ld, key: %@", status, [self getPayId]);
    if (status == 1) {
        [[KKApplePayManner sharedInstance] deleteByPaymentVoucher:self.payDictTemp];
    }
    if (self.payStatusBlock) {
        self.payStatusBlock(status, self.receipt);
    }
}

#pragma mark - Getter
- (NSString *)productID {
    NSString *tag = _productID.uppercaseString;
    return tag;
}

- (NSString *)getPayId {
    // key: orderNumber
    NSString *key = self.orderNumber;
    return key;
}
@end
