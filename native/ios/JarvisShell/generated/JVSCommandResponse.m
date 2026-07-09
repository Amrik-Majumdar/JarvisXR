// Generated skeleton for JarvisOS iPhone 6. Do not treat as compiled proof.
#import "JVSCommandResponse.h"

@implementation JVSCommandResponse
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _requestId = [dictionary[@"requestId"] copy];
        _status = [dictionary[@"status"] copy];
        _mode = [dictionary[@"mode"] copy];
        _spokenResponse = [dictionary[@"spokenResponse"] copy];
        _displayResponse = [dictionary[@"displayResponse"] copy];
        _riskLevel = [dictionary[@"riskLevel"] copy];
        _requiresConfirmation = [dictionary[@"requiresConfirmation"] boolValue];
        _unavailableReason = [dictionary[@"unavailableReason"] copy];
        _data = [dictionary[@"data"] copy];
    }
    return self;
}
@end
