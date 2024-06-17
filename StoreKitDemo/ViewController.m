//
//  ViewController.m
//  StoreKitDemo
//
//  Created by autophix on 2024/4/2.
//

#import "ViewController.h"
#import "NSObject+YYModel.h"

#import "ApplePayTool.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *productIDTF;
@property (weak, nonatomic) IBOutlet UITextField *transactionIDTF;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
//    [self onActionPurchase:nil];
}

- (IBAction)onActionPurchase:(UIButton *)sender {
    ApplePayTool *tool = [[ApplePayTool alloc]init];
    __weak typeof(self) sself = self;
    [tool requestAppleIAPWithProductID:self.productIDTF.text
                                  uuid:@"c001735d-56f6-4a77-a7d8-d9576068b3c1"
                              payBlock:^(ApplePayResponse * _Nonnull response) {
        StoreState status = response.status;
        if (response.type == ApplePayType_V1) {
            NSLog(@"onActionPurchase v1 :%ld - %@", status, response.response.yy_modelToJSONString);
        } else {
            if (status == StoreState_success) {
                sself.transactionIDTF.text = response.response.transactionId;
            }
            NSLog(@"onActionPurchase v2 :%ld - %@", status, response.response.yy_modelToJSONString);
        }
    }];
}

- (IBAction)onActionRefund:(UIButton *)sender {
    ApplePayTool *tool = [[ApplePayTool alloc]init];
    [tool requestRefundWithTransactionId:self.transactionIDTF.text block:^(ApplePayResponse * _Nonnull response) {
        StoreState status = response.status;
        NSLog(@"onActionRefund v2 :%ld", status);
    }];
}
@end
