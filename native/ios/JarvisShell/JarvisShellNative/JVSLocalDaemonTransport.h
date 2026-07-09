// Native UIKit skeleton. Not compiled or device-tested.
#import <Foundation/Foundation.h>

typedef void (^JVSLocalDaemonCompletion)(NSDictionary *response);

@interface JVSLocalDaemonTransport : NSObject
- (void)sendDictionary:(NSDictionary *)request completion:(JVSLocalDaemonCompletion)completion;
@end
