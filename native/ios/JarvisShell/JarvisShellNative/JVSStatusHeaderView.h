// Native UIKit skeleton. Not compiled or device-tested.
#import <UIKit/UIKit.h>

@interface JVSStatusHeaderView : UIView
@property (nonatomic, strong) UILabel *modeLabel;
@property (nonatomic, strong) UILabel *systemLabel;
- (void)applyPhoneState:(NSDictionary *)phoneState mode:(NSString *)mode;
@end
