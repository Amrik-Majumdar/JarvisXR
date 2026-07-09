// Generated skeleton for JarvisOS iPhone 6. Do not treat as compiled proof.
#import <Foundation/Foundation.h>

@interface JVSCommandResponse : NSObject
@property (nonatomic, copy) NSString *requestId;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, copy) NSString *spokenResponse;
@property (nonatomic, copy) NSString *displayResponse;
@property (nonatomic, copy) NSString *riskLevel;
@property (nonatomic, assign) BOOLrequiresConfirmation;
@property (nonatomic, copy) NSString *unavailableReason;
@property (nonatomic, copy) NSDictionary *data;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
@end
