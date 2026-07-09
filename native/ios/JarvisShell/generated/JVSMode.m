// Generated skeleton for JarvisOS iPhone 6. Do not treat as compiled proof.
#import "JVSMode.h"

@implementation JVSMode
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _name = [dictionary[@"name"] copy];
        _available = [dictionary[@"available"] boolValue];
        _unavailableReason = [dictionary[@"unavailableReason"] copy];
    }
    return self;
}
@end
