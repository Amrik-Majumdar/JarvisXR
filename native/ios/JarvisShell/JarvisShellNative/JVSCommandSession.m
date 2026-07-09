// Purpose: owns a single command lifecycle from transcript to daemon response.
// Lifecycle: created by command screen or home command affordance.
// Daemon link: sends execute_command and confirm_and_execute requests.
// Mock boundary: voice capture and real speech recognition are not implemented here.
#import "JVSCommandSession.h"
#import "JVSCommandClient.h"

@implementation JVSCommandSession
- (instancetype)initWithCommandClient:(JVSCommandClient *)client {
    self = [super init];
    if (self) {
        _commandClient = client;
        _transcript = @"";
        _lastResponse = @{};
    }
    return self;
}
- (void)executeTranscript:(NSString *)transcript completion:(void (^)(NSDictionary *response))completion {
    self.transcript = transcript ?: @"";
    NSDictionary *request = @{@"type": @"execute_command", @"request_id": [[NSUUID UUID] UUIDString], @"command": self.transcript};
    [self.commandClient sendRequest:request completion:^(NSDictionary *response) {
        self.lastResponse = response;
        if (completion) { completion(response); }
    }];
}
- (void)confirmWithToken:(NSString *)token completion:(void (^)(NSDictionary *response))completion {
    NSDictionary *request = @{@"type": @"confirm_and_execute", @"request_id": [[NSUUID UUID] UUIDString], @"confirmation_token": token ?: @""};
    [self.commandClient sendRequest:request completion:completion];
}
@end
