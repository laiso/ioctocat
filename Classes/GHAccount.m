#import "GHAccount.h"
#import "GHOAuthClient.h"
#import "GHUser.h"
#import "GHGists.h"
#import "GHEvents.h"
#import "GHRepositories.h"
#import "GHOrganization.h"
#import "GHOrganizations.h"
#import "GHNotifications.h"
#import "iOctocat.h"
#import "NSURL+Extensions.h"
#import "NSString+Extensions.h"
#import "NSDictionary+Extensions.h"
#import "AFOAuth2Client.h"


@implementation GHAccount

static NSString *const LoginKeyPath = @"login";
static NSString *const OrgsLoadingKeyPath = @"organizations.resourceStatus";

- (id)initWithDict:(NSDictionary *)dict {
	self = [super init];
	if (self) {
		self.login = [dict safeStringForKey:kLoginDefaultsKey];
		self.endpoint = [dict safeStringForKey:kEndpointDefaultsKey];
		self.authToken = [dict safeStringForKey:kAuthTokenDefaultsKey];
		self.pushToken = [dict safeStringForKey:kPushTokenDefaultsKey];
	}
	return self;
}

- (void)dealloc {
	[self.user removeObserver:self forKeyPath:OrgsLoadingKeyPath];
	[self.user removeObserver:self forKeyPath:LoginKeyPath];
}

- (void)setLogin:(NSString *)login {
    if ([login isEqualToString:_login]) return;
    _login = login;
    [self.user removeObserver:self forKeyPath:OrgsLoadingKeyPath];
	[self.user removeObserver:self forKeyPath:LoginKeyPath];
    // user with authenticated URLs
    NSString *receivedEventsPath = [NSString stringWithFormat:kUserAuthenticatedReceivedEventsFormat, self.login];
    NSString *eventsPath = [NSString stringWithFormat:kUserAuthenticatedEventsFormat, self.login];
    self.user = [[iOctocat sharedInstance] userWithLogin:self.login];
    self.user.resourcePath = kUserAuthenticatedFormat;
    self.user.repositories.resourcePath = kUserAuthenticatedReposFormat;
    self.user.organizations.resourcePath = kUserAuthenticatedOrgsFormat;
    self.user.gists.resourcePath = kUserAuthenticatedGistsFormat;
    self.user.starredGists.resourcePath = kUserAuthenticatedGistsStarredFormat;
    self.user.starredRepositories.resourcePath = kUserAuthenticatedStarredReposFormat;
    self.user.watchedRepositories.resourcePath = kUserAuthenticatedWatchedReposFormat;
    self.user.notifications = [[GHNotifications alloc] initWithPath:kNotificationsFormat];
    self.user.receivedEvents = [[GHEvents alloc] initWithPath:receivedEventsPath account:self];
    self.user.events = [[GHEvents alloc] initWithPath:eventsPath account:self];
    [self.user addObserver:self forKeyPath:LoginKeyPath options:NSKeyValueObservingOptionNew context:nil];
    [self.user addObserver:self forKeyPath:OrgsLoadingKeyPath options:NSKeyValueObservingOptionNew context:nil];
}

- (NSString *)accountId {
    NSURL *url = [NSURL smartURLFromString:self.endpoint];
	if (!url) url = [NSURL URLWithString:kGitHubEndpointURL];
    return [NSString stringWithFormat:@"%@/%@", url.host, self.login];
}

// constructs endpoint URL and sets up API client
- (GHOAuthClient *)apiClient {
    if (!_apiClient) {
        NSURL *apiURL = [NSURL URLWithString:kGitHubApiURL];
        if (!self.endpoint.isEmpty) {
            apiURL = [[NSURL URLWithString:self.endpoint] URLByAppendingPathComponent:kEnterpriseApiPath];
        }
        self.apiClient = [[GHOAuthClient alloc] initWithBaseURL:apiURL];
        [_apiClient setAuthorizationHeaderWithToken:self.authToken];
    }
    return _apiClient;
}

- (void)updateUserResourcePaths {
	self.user.receivedEvents.resourcePath = [NSString stringWithFormat:kUserAuthenticatedReceivedEventsFormat, self.user.login];
	self.user.events.resourcePath = [NSString stringWithFormat:kUserAuthenticatedEventsFormat, self.user.login];
	for (GHOrganization *org in self.user.organizations.items) {
		org.events.resourcePath = [NSString stringWithFormat:kUserAuthenticatedOrgEventsFormat, self.user.login, org.login];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:LoginKeyPath] || ([keyPath isEqualToString:OrgsLoadingKeyPath] && self.user.organizations.isLoaded)) {
		[self updateUserResourcePaths];
	}
	if ([keyPath isEqualToString:LoginKeyPath]) {
		self.login = self.user.login;
	}
}

#pragma mark Coding

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject:self.login forKey:kLoginDefaultsKey];
	[encoder encodeObject:self.endpoint forKey:kEndpointDefaultsKey];
	[encoder encodeObject:self.authToken forKey:kAuthTokenDefaultsKey];
	[encoder encodeObject:self.pushToken forKey:kPushTokenDefaultsKey];
}

- (id)initWithCoder:(NSCoder *)decoder {
	NSString *login = [decoder decodeObjectForKey:kLoginDefaultsKey];
	NSString *endpoint = [decoder decodeObjectForKey:kEndpointDefaultsKey];
	NSString *authToken = [decoder decodeObjectForKey:kAuthTokenDefaultsKey];
	NSString *pushToken = [decoder decodeObjectForKey:kPushTokenDefaultsKey];
	self = [self initWithDict:@{
			kLoginDefaultsKey: login ? login : @"",
		 kEndpointDefaultsKey: endpoint ? endpoint : @"",
		kAuthTokenDefaultsKey: authToken ? authToken : @"",
		kPushTokenDefaultsKey: pushToken ? pushToken : @"" }];
	return self;
}

@end