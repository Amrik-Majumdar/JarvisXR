// Native UIKit skeleton. Not compiled or device-tested.
#import "JVSHomeViewController.h"
#import "JVSDesignTokens.h"
#import "JVSTheme.h"

@implementation JVSHomeViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [JVSTheme backgroundColor];
    UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(24, 44, 327, 28)];
    status.text = @"JARVIS OFFLINE";
    status.textColor = [JVSTheme primaryTextColor];
    status.font = [UIFont systemFontOfSize:[JVSDesignTokens statusFontSize] weight:UIFontWeightSemibold];
    [self.view addSubview:status];
}
@end
