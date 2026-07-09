// Generated skeleton for JarvisOS iPhone 6. Do not treat as compiled proof.
#import "JVSConfirmation.h"

@implementation JVSConfirmation
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _token = [dictionary[@"token"] copy];
        _riskLevel = [dictionary[@"riskLevel"] copy];
        _createdAt = [dictionary[@"createdAt"] doubleValue];
        _expiresAt = [dictionary[@"expiresAt"] doubleValue];
        _used = [dictionary[@"used"] boolValue];
    }
    return self;
}
@end
