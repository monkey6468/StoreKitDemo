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

@property (nonatomic, strong) NSDictionary *payDictTemp;
@property (nonatomic, copy) NSString *productID; // 商品标识，苹果内购需提供（开发者网站设置时必须为大写）
@property (nonatomic, copy) NSString *receipt;   // 苹果支付成功的凭证
@property (nonatomic, copy) NSString *orderNumber;

@end

@implementation ApplePayTool

- (void)requestAppleIAPWithProductID:(NSString *)productID
                         orderNumber:(nonnull NSString *)orderNumber
                          payV1Block:(AppleV1Block)payV1Block
                          payV2Block:(AppleV2Block)payV2Block {
    self.productID = productID;
    self.orderNumber = orderNumber;
    self.payV1StatusBlock = payV1Block;
    self.payV2StatusBlock = payV2Block;

    [self payGoodsWithStoreKit];
}

- (void)payGoodsWithStoreKit {
    if (self.productID.length == 0) {
        [self returnResultV1WithStatus:StoreState_noProductTag];
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
    manger.payClosure = ^(StoreState status, NSString * _Nullable transactionId, NSString * _Nullable originalID) {
        [sself returnResultV2WithStatus:status
                          transactionId:transactionId
                             originalID:originalID];
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
                [self returnResultV1WithStatus:StoreState_success];
            } else {
                [self payGoodsWithApple];
            }
        } else {
            [self payGoodsWithApple];
        }
    }];
}

- (void)payGoodsWithApple {
    [self returnResultV1WithStatus:StoreState_start];
    [[KKApplePayManner sharedInstance] requestProducts:@[ self.productID ]
                                        withCompletion:^(SKProductsRequest *request, SKProductsResponse *response, NSError *error) {
        if (!error) {
            NSArray *products = [KKApplePayManner sharedInstance].products;
            if (products.count <= 0) {
                [self returnResultV1WithStatus:StoreState_noProduct];
            } else {
                [self requestPayGood];
            }
        } else {
            [self returnResultV1WithStatus:StoreState_lists];
        }
    }];
}

- (void)requestPayGood {
    [self returnResultV1WithStatus:StoreState_pay];
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
            [self returnResultV1WithStatus:StoreState_success];
        } else {
            [self returnResultV1WithStatus:(StoreState)transaction.transactionState];
        }
    }];
}

- (void)returnResultV1WithStatus:(StoreState)status {
//    NSLog(@"Apple V1购买商品状态:%ld, orderID: %@", status, [self getPayId]);
    if (status == 1) {
        [[KKApplePayManner sharedInstance] deleteByPaymentVoucher:self.payDictTemp];
    }
    if (self.payV1StatusBlock) {
        self.payV1StatusBlock(status, self.receipt);
    }
}

- (void)returnResultV2WithStatus:(StoreState)status
                   transactionId:(NSString *)transactionId
                      originalID:(NSString *)originalID {
//    NSLog(@"Apple V2购买商品状态:%ld, orderID: %@", status, [self getPayId]);
    if (status == 1) {
        [[KKApplePayManner sharedInstance] deleteByPaymentVoucher:self.payDictTemp];
    }
    if (self.payV2StatusBlock) {
        self.payV2StatusBlock(status, transactionId, originalID);
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
