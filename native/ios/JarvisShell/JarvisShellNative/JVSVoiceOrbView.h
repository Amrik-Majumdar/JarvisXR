// Native UIKit skeleton. Not compiled or device-tested.
#import <UIKit/UIKit.h>

@interface JVSVoiceOrbView : UIView
@property (nonatomic, copy) NSString *stateName;
- (void)setListening:(BOOL)listening;
- (void)setRouting:(BOOL)routing;
@end
