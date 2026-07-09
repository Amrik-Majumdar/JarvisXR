// Purpose: native overlay controls for inspection, OCR, object detection, flashlight, and freeze frame.
// Lifecycle: placed above native camera preview by inspection screen.
// Daemon link: buttons send execute_command requests.
// Mock boundary: no real AVCapture preview is proven yet.
#import "JVSCameraOverlayView.h"

@implementation JVSCameraOverlayView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _scanButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _ocrButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _objectButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_scanButton setTitle:@"Scan" forState:UIControlStateNormal];
        [_ocrButton setTitle:@"OCR" forState:UIControlStateNormal];
        [_objectButton setTitle:@"Object" forState:UIControlStateNormal];
        [self addSubview:_scanButton];
        [self addSubview:_ocrButton];
        [self addSubview:_objectButton];
    }
    return self;
}
- (void)applyInspectionState:(NSDictionary *)state {}
@end
