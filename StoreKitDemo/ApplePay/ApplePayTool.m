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

#define WeakSelf __weak typeof(self) weakSelf = self;

@implementation ApplePayResponse
@end

@interface ApplePayTool ()

@property (nonatomic, copy) NSString *productID; // 商品标识，苹果内购需提供（开发者网站设置时必须为大写）
@property (nonatomic, copy) NSString *orderNumber;

@property (nonatomic, strong) ApplePayResponse *reponseModel;

@end

@implementation ApplePayTool

- (void)requestAppleIAPWithProductID:(NSString *)productID
                         orderNumber:(nonnull NSString *)orderNumber
                            payBlock:(ApplePayBlock)payBlock {
    self.productID = productID;
    self.orderNumber = orderNumber;
    self.payBlock = payBlock;
    self.reponseModel = [[ApplePayResponse alloc] init];
    
    [self payGoodsWithStoreKit];
}

- (void)requestRefundWithtransactionId:(NSString *)transactionId {
    if (@available(iOS 15.0, *)) {
        NSLog(@"Apple退款方式 V2");
        ApplePay2Manger *manger = [[ApplePay2Manger alloc] init];
        [manger storeKitRefundWithId:transactionId];
    } else {
        NSLog(@"Apple退款方式 V1 不支持");
    }
}

- (void)payGoodsWithStoreKit {
    if (self.productID.length == 0) {
        [self returnResultV1WithStatus:StoreState_noProductTag];
        return;
    }
    
    if (@available(iOS 15.0, *)) {
        NSLog(@"Apple购买方式 V2");
        ApplePay2Manger *manger = [[ApplePay2Manger alloc] init];
        [manger storeKitPayWithProductId:self.productID orderID:self.orderNumber];
        __strong typeof(self) sself = self;
        manger.payClosure = ^(StoreState status, NSString *_Nullable transactionId, NSString *_Nullable originalID) {
            sself.reponseModel.transactionId = transactionId;
            sself.reponseModel.originalID = originalID;
            [sself returnResultV2WithStatus:status];
        };
    } else {
        NSLog(@"Apple购买方式 V1");
        [self payGoodsWithStoreKit1];
    }
}

- (void)payGoodsWithStoreKit1 {
    // 验证本地是否存在
    [[KKApplePayManner sharedInstance] checkInternalPurchasePayment:^(NSArray *items, NSError *error) {
        if (items.count) {
            NSString *currentKey = [self getPayId];
            NSDictionary *payDictT = nil;
            for (NSDictionary *payDict in items) {
                NSDictionary *dict = payDict[currentKey];
                if (dict) {
                    payDictT = payDict;
                    break;
                }
            }
            if (payDictT) {
                self.reponseModel.payDict = payDictT;
                [self returnResultV1WithStatus:StoreState_success];
            } else {
                [self payGoodsWithApple];
            }
        } else {
            [self payGoodsWithApple];
        }
    }];
}

// 获取Apple商品标识列表
- (void)requestGoodsListWithCompletion:(void (^)(SKProduct *product))completion {
    [[KKApplePayManner sharedInstance] requestProducts:@[ self.productID ]
                                        withCompletion:^(SKProductsRequest *request, SKProductsResponse *response, NSError *error) {
        if (!error) {
            NSArray *products = [KKApplePayManner sharedInstance].products;
            if (products.count <= 0) {
                [self returnResultV1WithStatus:StoreState_noProduct];
            } else {
                completion(products.firstObject);
            }
        } else {
            [self returnResultV1WithStatus:StoreState_lists];
        }
    }];
}

- (void)payGoodsWithApple {
    [self returnResultV1WithStatus:StoreState_start];
    WeakSelf
    [self requestGoodsListWithCompletion:^(SKProduct *product) {
        [weakSelf requestPayGood];
    }];
}

- (void)requestPayGood {
    [self returnResultV1WithStatus:StoreState_pay];
    NSArray *products = [KKApplePayManner sharedInstance].products;
    SKProduct *product1 = products.firstObject;
    NSLog(@"开始支付：%@, %@", product1.priceLocale.localeIdentifier, [product1.priceLocale objectForKey:NSLocaleCurrencySymbol]);
    
    WeakSelf
    [[KKApplePayManner sharedInstance] buyProduct:products.firstObject
                                     onCompletion:^(SKPaymentTransaction *transaction, NSError *error) {
        if (!error) {
            [weakSelf requestGoodsListWithCompletion:^(SKProduct *product) {
                // 实际支付的价格
                NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                NSLocale *locale = product.priceLocale;
                numberFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
                numberFormatter.locale = locale;
                NSString *formattedPriceString = [numberFormatter stringFromNumber:product.price];
                NSLog(@"完成支付：%@, %@", formattedPriceString, [product.priceLocale objectForKey:NSLocaleCurrencySymbol]);
                // 获取货币代码
                NSString *currencyCode = [product.priceLocale.localeIdentifier componentsSeparatedByString:@"="].lastObject;
                NSString *receipt = [KKApplePayManner sharedInstance].appStoreReceiptbase64EncodedString ?: @"";
                //                NSString *transactionIdentifier = transaction.transactionIdentifier ?: @"";
                //                NSString *productIdentifier = transaction.payment.productIdentifier;
                //                NSDictionary *dicInfo = @{
                //                    @"receiptData" : receipt,
                //                    @"orderNumber" : self.orderNumber,
                //                    @"transactionId" : transactionIdentifier,
                //                    @"productId" : self.goodsTag,
                //                    @"sn" : self.sn,
                //                };
                if (receipt.length) {
                    NSMutableDictionary *dictInfo = [NSMutableDictionary dictionary];
                    dictInfo[@"receipt"] = receipt;
                    dictInfo[@"currency"] = currencyCode;
                    dictInfo[@"price"] = [NSString stringWithFormat:@"%0.2lf", product.price.floatValue];
                    
                    NSString *key = [weakSelf getPayId];
                    NSMutableDictionary *payDict = [NSMutableDictionary dictionary];
                    payDict[key] = dictInfo;
                    [[KKApplePayManner sharedInstance] savePaymentVoucher:payDict];
                    
                    weakSelf.reponseModel.payDict = payDict;
                    [weakSelf returnResultV1WithStatus:StoreState_success];
                } else {
                    NSLog(@"支付成功有异常⚠️⚠️⚠️：%@", transaction);
                    [weakSelf returnResultV1WithStatus:StoreState_unowned];
                }
            }];
        } else {
            [weakSelf returnResultV1WithStatus:(StoreState)transaction.transactionState];
        }
    }];
}

- (void)returnResultV1WithStatus:(StoreState)status {
    NSLog(@"Apple V1购买商品状态:%ld, orderID: %@", status, [self getPayId]);
    self.reponseModel.type = ApplePayType_V1;
    self.reponseModel.status = status;
    if (self.payBlock) {
        self.payBlock(self.reponseModel);
    }
}

- (void)returnResultV2WithStatus:(StoreState)status {
    NSLog(@"Apple V2购买商品状态:%ld, orderID: %@", status, [self getPayId]);
    self.reponseModel.type = ApplePayType_V2;
    self.reponseModel.status = status;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.payBlock) {
            self.payBlock(self.reponseModel);
        }
    });
}

#pragma mark - Getter
- (NSString *)productID {
    NSString *tagStr = @"Diagnosis";
    if ([_productID containsString:tagStr]) {
        return _productID;
    } else {
        NSString *resultStr = [NSString stringWithFormat:@"%@%@", _productID.uppercaseString, tagStr];
        return resultStr;
    }
}

- (NSString *)getPayId {
    // key: orderNumber
    NSString *key = self.orderNumber;
    return key;
}
@end
