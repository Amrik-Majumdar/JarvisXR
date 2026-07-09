// Native UIKit skeleton. Not compiled or device-tested.
#import <Foundation/Foundation.h>

@interface JVSAppState : NSObject
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, copy) NSDictionary *phoneState;
@property (nonatomic, copy) NSDictionary *lastCommandResponse;
@property (nonatomic, assign) BOOL daemonReachable;
- (void)applyDaemonResponse:(NSDictionary *)response;
@end
