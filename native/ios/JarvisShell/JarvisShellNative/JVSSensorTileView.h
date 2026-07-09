// Native UIKit skeleton. Not compiled or device-tested.
#import <UIKit/UIKit.h>

@interface JVSSensorTileView : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
- (void)applyTitle:(NSString *)title value:(NSString *)value available:(BOOL)available;
@end
