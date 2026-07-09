// Native UIKit skeleton. Not compiled or device-tested.
#import <Foundation/Foundation.h>

@class JVSCommandClient;

@interface JVSCommandSession : NSObject
@property (nonatomic, copy) NSString *transcript;
@property (nonatomic, copy) NSDictionary *lastResponse;
@property (nonatomic, strong) JVSCommandClient *commandClient;
- (instancetype)initWithCommandClient:(JVSCommandClient *)client;
- (void)executeTranscript:(NSString *)transcript completion:(void (^)(NSDictionary *response))completion;
- (void)confirmWithToken:(NSString *)token completion:(void (^)(NSDictionary *response))completion;
@end
