// Native UIKit skeleton. Not compiled or device-tested.
#import "JVSRootViewController.h"
#import "JVSHomeViewController.h"
#import "JVSTheme.h"

@implementation JVSRootViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [JVSTheme backgroundColor];
    JVSHomeViewController *home = [[JVSHomeViewController alloc] init];
    [self addChildViewController:home];
    home.view.frame = self.view.bounds;
    home.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:home.view];
    [home didMoveToParentViewController:self];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}
@end
