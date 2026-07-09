// Native UIKit skeleton. Not compiled or device-tested.
#import "JVSLocalDaemonTransport.h"

@implementation JVSLocalDaemonTransport
- (void)sendDictionary:(NSDictionary *)request completion:(JVSLocalDaemonCompletion)completion {
    // Future transport: local Unix socket or loopback daemon channel after jailbreak testing.
    if (completion) {
        completion(@{@"status": @"unavailable", @"display_response": @"Daemon transport not implemented in skeleton."});
    }
}
@end
