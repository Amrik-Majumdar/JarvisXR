// Native UIKit skeleton. Not compiled or device-tested.
#import <UIKit/UIKit.h>

@interface JVSConfirmationView : UIView
@property (nonatomic, copy) NSString *confirmationToken;
- (void)showForResponse:(NSDictionary *)response;
- (void)clear;
@end
