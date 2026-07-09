// Purpose: clear offline-first status without implying online dependence.
// Lifecycle: appears on home, command, and capability screens.
// Daemon link: fed by phone_state network fields.
// Mock boundary: network state is mock until device testing.
#import "JVSOfflineBannerView.h"

@implementation JVSOfflineBannerView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _label = [[UILabel alloc] initWithFrame:self.bounds];
        [self addSubview:_label];
    }
    return self;
}
- (void)setOffline:(BOOL)offline {
    self.label.text = offline ? @"OFFLINE CORE ACTIVE" : @"NETWORK AVAILABLE";
}
@end
