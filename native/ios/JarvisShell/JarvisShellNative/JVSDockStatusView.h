// Native UIKit skeleton. Not compiled or device-tested.
#import <UIKit/UIKit.h>

@interface JVSDockStatusView : UIView
@property (nonatomic, strong) UILabel *statusLabel;
- (void)applyDockState:(NSDictionary *)dockState;
@end
