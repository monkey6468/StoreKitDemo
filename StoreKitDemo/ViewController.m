//
//  ViewController.m
//  StoreKitDemo
//
//  Created by autophix on 2024/4/2.
//

#import "ViewController.h"

#import "ApplePayTool.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self onActionPurchase:nil];
}

- (IBAction)onActionPurchase:(UIButton *)sender {
//    ApplePayTool *tool = [[ApplePayTool alloc]init];
//    [tool requestAppleIAPWithProductID:@"VW"
//                           orderNumber:@"123456789"
//                            payV1Block:^(StoreState status, NSString * _Nonnull receipt, NSDictionary * _Nonnull payDict) {        
//        NSLog(@"onActionPurchase v1 :%ld - %@", status, receipt);
//    } payV2Block:^(StoreState status, NSString * _Nonnull transactionId, NSString * _Nonnull originalID) {
//        NSLog(@"onActionPurchase v2 :%ld - %@ - %@", status, transactionId, originalID);
//    }];
    ApplePayTool *tool = [[ApplePayTool alloc]init];
    __strong typeof(self) sself = self;
    [tool requestAppleIAPWithProductID:@"VW"
                           orderNumber:@"123456789"
                              payBlock:^(ApplePayResponse * _Nonnull response) {
        StoreState status = response.status;
        NSLog(@"onActionPurchase v1 :%ld - %@", status, response.payDict);
        if (response.type == ApplePayType_V1) {
            if (status == StoreState_success) {

            } else {
                if (status == StoreState_start
                    ||status == StoreState_pay) {
                } else {

                }
            }
        } else {
#warning V2 后台未开发
            // to do
            if (status == StoreState_verifiedServer) {
                
            } else {
                if (status == StoreState_start
                    ||status == StoreState_pay) {
                } else {

                }
            }
        }
    }];
}

@end
