// Native UIKit skeleton. Not compiled or device-tested.
#import <Foundation/Foundation.h>

@class JVSCommandClient;

@interface JVSModeController : NSObject
@property (nonatomic, copy, readonly) NSString *currentMode;
@property (nonatomic, strong) JVSCommandClient *commandClient;
- (instancetype)initWithCommandClient:(JVSCommandClient *)client;
- (void)requestMode:(NSString *)mode completion:(void (^)(NSDictionary *response))completion;
@end
