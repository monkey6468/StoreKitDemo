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
    ApplePayTool *tool = [[ApplePayTool alloc]init];
    [tool requestAppleIAPWithProductID:@"VW"
                           orderNumber:@"123456789"
                            payV1Block:^(StoreState status, NSString * _Nonnull receipt, NSDictionary * _Nonnull payDict) {        
        NSLog(@"onActionPurchase v1 :%ld - %@", status, receipt);
    } payV2Block:^(StoreState status, NSString * _Nonnull transactionId, NSString * _Nonnull originalID) {
        NSLog(@"onActionPurchase v2 :%ld - %@ - %@", status, transactionId, originalID);
    }];
}

@end
