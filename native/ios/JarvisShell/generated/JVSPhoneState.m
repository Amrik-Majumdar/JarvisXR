// Generated skeleton for JarvisOS iPhone 6. Do not treat as compiled proof.
#import "JVSPhoneState.h"

@implementation JVSPhoneState
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _profile = [dictionary[@"profile"] copy];
        _network = [dictionary[@"network"] copy];
        _battery = [dictionary[@"battery"] copy];
        _storage = [dictionary[@"storage"] copy];
        _camera = [dictionary[@"camera"] copy];
        _microphone = [dictionary[@"microphone"] copy];
        _sensors = [dictionary[@"sensors"] copy];
        _privacy = [dictionary[@"privacy"] copy];
        _jailbreak = [dictionary[@"jailbreak"] copy];
    }
    return self;
}
@end
