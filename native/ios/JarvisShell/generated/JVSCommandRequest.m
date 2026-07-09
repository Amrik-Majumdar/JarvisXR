// Generated skeleton for JarvisOS iPhone 6. Do not treat as compiled proof.
#import "JVSCommandRequest.h"

@implementation JVSCommandRequest
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _requestId = [dictionary[@"requestId"] copy];
        _type = [dictionary[@"type"] copy];
        _command = [dictionary[@"command"] copy];
        _mode = [dictionary[@"mode"] copy];
        _confirmationToken = [dictionary[@"confirmationToken"] copy];
    }
    return self;
}
@end
