// Purpose: converts daemon response dictionaries into native display state.
// Lifecycle: stateless helper retained by command and home screens.
// Daemon link: expects jarvis_response.schema.json shape.
// Mock boundary: spoken response handoff is delegated elsewhere until TTS is real.
#import "JVSResponseRenderer.h"

@implementation JVSResponseRenderer
- (void)renderResponse:(NSDictionary *)response intoLabel:(UILabel *)label {
    label.text = response[@"display_response"] ?: @"No response.";
}
- (BOOL)responseRequiresConfirmation:(NSDictionary *)response {
    return [response[@"requires_confirmation"] boolValue];
}
@end
