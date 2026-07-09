// Native UIKit skeleton. Not compiled or device-tested.
#import <UIKit/UIKit.h>

@interface JVSResponseRenderer : NSObject
- (void)renderResponse:(NSDictionary *)response intoLabel:(UILabel *)label;
- (BOOL)responseRequiresConfirmation:(NSDictionary *)response;
@end
