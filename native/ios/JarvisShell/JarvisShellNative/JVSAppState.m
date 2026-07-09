// Purpose: central native shell state shared by view controllers.
// Lifecycle: owned by the root controller after app launch.
// Daemon link: updated from JVSCommandClient responses.
// Mock boundary: all values remain daemon or mock-driven until device testing.
#import "JVSAppState.h"

@implementation JVSAppState
- (instancetype)init {
    self = [super init];
    if (self) {
        _mode = @"offline";
        _phoneState = @{};
        _lastCommandResponse = @{};
        _daemonReachable = NO;
    }
    return self;
}

- (void)applyDaemonResponse:(NSDictionary *)response {
    self.lastCommandResponse = response;
    NSString *mode = response[@"mode"];
    if ([mode isKindOfClass:[NSString class]]) {
        self.mode = mode;
    }
}
@end
