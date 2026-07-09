// Native UIKit skeleton. Not compiled or device-tested.
#import "AppDelegate.h"
#import "JVSRootViewController.h"

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[JVSRootViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end
