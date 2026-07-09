// Purpose: reusable native capability list for browser and related-tool results.
// Lifecycle: owned by capability browser or command result panels.
// Daemon link: consumes list_capabilities and related capability responses.
// Mock boundary: capability content is registry data, not live iPhone control.
#import "JVSCapabilityListView.h"

@implementation JVSCapabilityListView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
        _tableView.dataSource = self;
        [self addSubview:_tableView];
        _capabilities = @[];
    }
    return self;
}
- (void)showCapabilities:(NSArray<NSDictionary *> *)capabilities {
    self.capabilities = capabilities ?: @[];
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.capabilities.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Capability"];
    NSDictionary *cap = self.capabilities[indexPath.row];
    cell.textLabel.text = cap[@"name"];
    cell.detailTextLabel.text = cap[@"mode"];
    return cell;
}
@end
