// Native UIKit skeleton. Not compiled or device-tested.
#import <UIKit/UIKit.h>

@interface JVSCapabilityListView : UIView <UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<NSDictionary *> *capabilities;
- (void)showCapabilities:(NSArray<NSDictionary *> *)capabilities;
@end
