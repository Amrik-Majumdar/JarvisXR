// Native UIKit skeleton. Not compiled or device-tested.
#import "JVSCommandClient.h"
#import "JVSLocalDaemonTransport.h"

@implementation JVSCommandClient
- (void)sendRequest:(NSDictionary *)request completion:(JVSCommandCompletion)completion {
    JVSLocalDaemonTransport *transport = [[JVSLocalDaemonTransport alloc] init];
    [transport sendDictionary:request completion:completion];
}
@end
