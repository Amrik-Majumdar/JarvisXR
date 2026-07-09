// Purpose: presents explicit confirmation for risky daemon responses.
// Lifecycle: shown by command screen when response requires confirmation.
// Daemon link: sends confirmation token back through JVSCommandSession.
// Mock boundary: no device action is executed until daemon confirms.
#import "JVSConfirmationView.h"

@implementation JVSConfirmationView
- (void)showForResponse:(NSDictionary *)response {
    self.confirmationToken = response[@"data"][@"handler_data"][@"confirmation_token"] ?: response[@"data"][@"confirmation_token"];
    self.hidden = NO;
}
- (void)clear {
    self.confirmationToken = nil;
    self.hidden = YES;
}
@end
