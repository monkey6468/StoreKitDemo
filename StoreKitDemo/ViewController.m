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
                              payBlock:^(StoreState status, NSString * _Nonnull receipt) {
        if (@available(iOS 15.0, *)) {
            NSLog(@"onActionPurchase1 :%ld - %@", status, receipt);
        } else {
            NSLog(@"onActionPurchase2 :%ld - %@", status, receipt);
        }
    }];
}

@end
