//
//  ApplePayTool.m
//  Autophix
//
//  Created by autophix on 2023/7/25.
//  Copyright © 2023 ruperthuang. All rights reserved.
//

#import "ApplePayTool.h"
#import "KKApplePayManner.h"
#import "NSObject+YYModel.h"

#import "StoreKitDemo-Swift.h"

#define WeakSelf __weak typeof(self) weakSelf = self;

@implementation ApplePayResponse
@end

@implementation PayResponse
@end

@interface ApplePayTool ()

@property (nonatomic, copy) NSString *productID; // 商品标识，苹果内购需提供（开发者网站设置时必须为大写）
@property (nonatomic, copy) NSString *uuid;

@property (nonatomic, strong) ApplePayResponse *reponseModel;

@end

@implementation ApplePayTool

- (void)requestAppleIAPWithProductID:(NSString *)productID
                                uuid:(nonnull NSString *)uuid
                            payBlock:(ApplePayBlock)payBlock {
    self.productID = productID;
    self.uuid = uuid;
    self.payBlock = payBlock;
    self.reponseModel = [[ApplePayResponse alloc] init];
    
    [self payGoodsWithStoreKit];
}

- (void)requestRefundWithTransactionId:(NSString *)transactionId
                                 block:(ApplePayBlock)payBlock {
    self.payBlock = payBlock;
    if (@available(iOS 15.0, *)) {
        NSLog(@"Apple退款方式 V2");
        ApplePay2Manger *manger = [[ApplePay2Manger alloc] init];
        [manger storeKitRefundWithId:transactionId];
        __strong typeof(self) sself = self;
        manger.payClosure = ^(StoreState status, PayResponse *_Nullable response) {
            [sself returnResultV2WithStatus:status];
        };
    } else {
        NSLog(@"Apple退款方式 V1 不支持");
    }
}

- (void)payGoodsWithStoreKit {
    if (self.productID.length == 0) {
        [self returnResultV1WithStatus:StoreState_noProductTag];
        return;
    }
    
    [self checkLocalPayRecord:^(PayResponse *response) {
        if (response) {
            self.reponseModel.response = response;
            if (@available(iOS 15.0, *)) {
                NSLog(@"Apple购买方式 V2");
                [self returnResultV2WithStatus:StoreState_success];
            } else {
                NSLog(@"Apple购买方式 V1");
                [self returnResultV1WithStatus:StoreState_success];
            }
        } else {
            if (@available(iOS 15.0, *)) {
                NSLog(@"Apple购买方式 V2");
                ApplePay2Manger *manger = [[ApplePay2Manger alloc] init];
                [manger storeKitPayWithProductId:self.productID uuid:self.uuid];
                __strong typeof(self) sself = self;
                manger.payClosure = ^(StoreState status, PayResponse *_Nullable response) {
                    sself.reponseModel.response = response;
                    if (status == StoreState_success) {
                        response.uuid = sself.uuid;
                        NSMutableDictionary *payDict = response.yy_modelToJSONObject;
                        [[KKApplePayManner sharedInstance] savePaymentVoucher:payDict];
                    }
                    [sself returnResultV2WithStatus:status];
                };
            } else {
                NSLog(@"Apple购买方式 V1");
                [self payGoodsWithAppleV1];
            }
        }
    }];
}

- (void)checkLocalPayRecord:(void (^)(PayResponse *response))completed {
    // 验证本地是否存在
    [[KKApplePayManner sharedInstance] checkInternalPurchasePayment:^(NSArray *items, NSError *error) {
        if (items.count) {
            NSArray *results = [NSArray yy_modelArrayWithClass:PayResponse.class json:items];
            PayResponse *modelT = nil;
            for (PayResponse *model in results) {
                if ([model.uuid isEqualToString:self.uuid]) {
                    modelT = model;
                    break;
                }
            }
            completed(modelT);
        } else {
            completed(nil);
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

- (void)payGoodsWithAppleV1 {
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
                NSString *transactionIdentifier = transaction.transactionIdentifier ?: @"";
                NSString *productIdentifier = transaction.payment.productIdentifier;
                NSLog(@"Apple v1支付：%@ - %@", transactionIdentifier, productIdentifier);
                
                if (receipt.length) {
                    NSString *price = [NSString stringWithFormat:@"%0.2lf", product.price.floatValue];
                    
                    PayResponse *response = [[PayResponse alloc]init];
                    response.uuid = weakSelf.uuid;
                    response.receipt = receipt;
                    response.currency = currencyCode;
                    response.price = price;

                    NSMutableDictionary *payDict = response.yy_modelToJSONObject;
                    [[KKApplePayManner sharedInstance] savePaymentVoucher:payDict];
                    
                    weakSelf.reponseModel.response = response;
                    [weakSelf returnResultV1WithStatus:StoreState_success];
                } else {
                    NSLog(@"支付成功有异常⚠️⚠️⚠️：%@", transaction.yy_modelToJSONString);
                    [weakSelf returnResultV1WithStatus:StoreState_unowned];
                }
            }];
        } else {
            [weakSelf returnResultV1WithStatus:(StoreState)transaction.transactionState];
        }
    }];
}

- (void)returnResultV1WithStatus:(StoreState)status {
    NSLog(@"Apple V1购买商品状态:%ld, uuid: %@", status, self.uuid);
    self.reponseModel.type = ApplePayType_V1;
    self.reponseModel.status = status;
    [self returnResult];
}

- (void)returnResultV2WithStatus:(StoreState)status {
    NSLog(@"Apple V2购买商品状态:%ld, uuid: %@", status, self.uuid);
    self.reponseModel.type = ApplePayType_V2;
    self.reponseModel.status = status;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self returnResult];
    });
}

- (void)returnResult {
#ifdef AUTOPHIX_DEV
    if (self.reponseModel.status == StoreState_noProduct) {
        [SVProgressHUD showInfoWithStatus:@"该商品Apple后台没有上架,请联系开发人员!"];
    }
#endif
    if (self.payBlock) {
        self.payBlock(self.reponseModel);
    }
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

@end
