// Purpose: asks jarvisd to change or report modes.
// Lifecycle: retained by root controller.
// Daemon link: sends set_mode requests through JVSCommandClient.
// Mock boundary: mode availability is decided by daemon harness until device tests.
#import "JVSModeController.h"
#import "JVSCommandClient.h"

@implementation JVSModeController {
    NSString *_currentMode;
}
- (instancetype)initWithCommandClient:(JVSCommandClient *)client {
    self = [super init];
    if (self) {
        _commandClient = client;
        _currentMode = @"offline";
    }
    return self;
}
- (NSString *)currentMode { return _currentMode; }
- (void)requestMode:(NSString *)mode completion:(void (^)(NSDictionary *response))completion {
    NSDictionary *request = @{@"type": @"set_mode", @"request_id": [[NSUUID UUID] UUIDString], @"mode": mode ?: @""};
    [self.commandClient sendRequest:request completion:^(NSDictionary *response) {
        NSString *returnedMode = response[@"mode"];
        if ([returnedMode isKindOfClass:[NSString class]]) {
            self->_currentMode = returnedMode;
        }
        if (completion) { completion(response); }
    }];
}
@end
