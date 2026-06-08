#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** 从 Pod resource bundle 读取菜单文案，支持系统语言（en / zh-Hans 等） */
FOUNDATION_EXPORT NSString *ENRMLocalizedString(NSString *key);

NS_ASSUME_NONNULL_END
