// Purpose: displays local note, observation, or command history item.
// Lifecycle: used by JVSMemoryViewController table.
// Daemon link: consumes get_recent_history and search_memory responses.
// Mock boundary: memory comes from daemon SQLite harness until device storage is proven.
#import "JVSMemoryLogCell.h"

@implementation JVSMemoryLogCell
- (void)configureWithMemoryItem:(NSDictionary *)item {
    self.textLabel.text = item[@"text"] ?: @"Memory item";
    self.detailTextLabel.text = item[@"kind"] ?: @"local";
}
@end
