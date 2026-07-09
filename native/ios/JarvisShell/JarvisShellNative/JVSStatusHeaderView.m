// Purpose: compact mode, battery, offline, online, and dock state header.
// Lifecycle: embedded at top of primary screens.
// Daemon link: fed by get_phone_state and response mode fields.
// Mock boundary: values are mock daemon values until device testing.
#import "JVSStatusHeaderView.h"

@implementation JVSStatusHeaderView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _modeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _systemLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [self addSubview:_modeLabel];
        [self addSubview:_systemLabel];
    }
    return self;
}
- (void)applyPhoneState:(NSDictionary *)phoneState mode:(NSString *)mode {
    self.modeLabel.text = [mode uppercaseString] ?: @"OFFLINE";
    self.systemLabel.text = @"Battery, dock, and network state pending layout.";
}
@end
