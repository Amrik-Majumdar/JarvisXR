// Native UIKit skeleton. Not compiled or device-tested.
#import <UIKit/UIKit.h>

@interface JVSCameraOverlayView : UIView
@property (nonatomic, strong) UIButton *scanButton;
@property (nonatomic, strong) UIButton *ocrButton;
@property (nonatomic, strong) UIButton *objectButton;
- (void)applyInspectionState:(NSDictionary *)state;
@end
