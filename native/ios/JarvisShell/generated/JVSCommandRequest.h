// Generated skeleton for JarvisOS iPhone 6. Do not treat as compiled proof.
#import <Foundation/Foundation.h>

@interface JVSCommandRequest : NSObject
@property (nonatomic, copy) NSString *requestId;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *command;
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, copy) NSString *confirmationToken;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
@end
