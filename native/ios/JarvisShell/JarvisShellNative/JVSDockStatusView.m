// Purpose: displays Pi or PC dock availability, sync state, and refusal reasons.
// Lifecycle: used by home and dock screens.
// Daemon link: consumes phone state and dock adapter results.
// Mock boundary: dock sync is mocked until Pi or PC dock tests.
#import "JVSDockStatusView.h"

@implementation JVSDockStatusView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _statusLabel = [[UILabel alloc] initWithFrame:self.bounds];
        [self addSubview:_statusLabel];
    }
    return self;
}
- (void)applyDockState:(NSDictionary *)dockState {
    BOOL docked = [dockState[@"dock"] boolValue];
    self.statusLabel.text = docked ? @"DOCK AVAILABLE" : @"NO DOCK";
}
@end
