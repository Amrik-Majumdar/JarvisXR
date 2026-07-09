// Purpose: central native voice and command status indicator.
// Lifecycle: owned by home and command screens.
// Daemon link: state changes when command requests start or finish.
// Mock boundary: no wake word or microphone animation is proven yet.
#import "JVSVoiceOrbView.h"
#import "JVSTheme.h"

@implementation JVSVoiceOrbView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = CGRectGetWidth(frame) / 2.0;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [[JVSTheme accentColor] CGColor];
        _stateName = @"idle";
    }
    return self;
}
- (void)setListening:(BOOL)listening { self.stateName = listening ? @"listening" : @"idle"; }
- (void)setRouting:(BOOL)routing { self.stateName = routing ? @"routing" : self.stateName; }
@end
