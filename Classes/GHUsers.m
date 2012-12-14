#import "GHUsers.h"
#import "GHUser.h"
#import "iOctocat.h"


@implementation GHUsers

- (id)initWithPath:(NSString *)path {
	self = [super init];
	if (self) {
		self.resourcePath = path;
	}
	return self;
}

- (void)setValues:(id)values {
	self.items = [NSMutableArray array];
	for (NSDictionary *dict in values) {
		NSString *login = dict[@"login"];
		GHUser *user = [[iOctocat sharedInstance] userWithLogin:login];
		[user setValues:dict];
		[self addObject:user];
	}
	[self.items sortUsingSelector:@selector(compareByName:)];
}

@end