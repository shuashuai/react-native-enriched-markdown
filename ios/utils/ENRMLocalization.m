#import "ENRMLocalization.h"

@interface ENRMBundleAnchor : NSObject
@end

@implementation ENRMBundleAnchor
@end

static NSBundle *ENRMLocalizationBundle(void)
{
  static NSBundle *bundle = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSBundle *podBundle = [NSBundle bundleForClass:[ENRMBundleAnchor class]];
    NSString *path = [podBundle pathForResource:@"ReactNativeEnrichedMarkdown" ofType:@"bundle"];
    bundle = path != nil ? [NSBundle bundleWithPath:path] : podBundle;
  });
  return bundle;
}

NSString *ENRMLocalizedString(NSString *key)
{
  NSString *value = NSLocalizedStringFromTableInBundle(key, nil, ENRMLocalizationBundle(), nil);
  return value.length > 0 ? value : key;
}
