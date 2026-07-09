// Purpose: stable native tile for compass, level, pressure, motion, and GPS summaries.
// Lifecycle: reused by sensor screen.
// Daemon link: populated from sensor adapter results.
// Mock boundary: values are mock until hardware tests.
#import "JVSSensorTileView.h"

@implementation JVSSensorTileView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _valueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [self addSubview:_titleLabel];
        [self addSubview:_valueLabel];
    }
    return self;
}
- (void)applyTitle:(NSString *)title value:(NSString *)value available:(BOOL)available {
    self.titleLabel.text = title;
    self.valueLabel.text = available ? value : @"Unavailable";
}
@end
