// Generated skeleton for JarvisOS iPhone 6. Do not treat as compiled proof.
#import "JVSCapability.h"

@implementation JVSCapability
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _identifier = [dictionary[@"id"] copy];
        _family = [dictionary[@"family"] copy];
        _name = [dictionary[@"name"] copy];
        _mode = [dictionary[@"mode"] copy];
        _riskLevel = [dictionary[@"riskLevel"] copy];
        _requiredHardware = [dictionary[@"requiredHardware"] copy];
    }
    return self;
}
@end
