// Native UIKit skeleton. Not compiled or device-tested.
#import <Foundation/Foundation.h>

typedef void (^JVSCommandCompletion)(NSDictionary *response);

@interface JVSCommandClient : NSObject
- (void)sendRequest:(NSDictionary *)request completion:(JVSCommandCompletion)completion;
@end
