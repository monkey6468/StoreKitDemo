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
                              payBlock:^(ApplePayResponse * _Nonnull response) {
        StoreState status = response.status;
        if (response.type == ApplePayType_V1) {
            NSLog(@"onActionPurchase v1 :%ld - %@", status, response.payDict);
        } else {
            NSLog(@"onActionPurchase v2 :%ld - %@ - %@", status, response.transactionId, response.originalID);
        }
    }];
}

@end
