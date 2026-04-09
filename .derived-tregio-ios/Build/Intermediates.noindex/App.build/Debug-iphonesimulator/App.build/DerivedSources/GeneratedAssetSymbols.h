#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "LaunchBrand" asset catalog image resource.
static NSString * const ACImageNameLaunchBrand AC_SWIFT_PRIVATE = @"LaunchBrand";

/// The "PromoSpringMan" asset catalog image resource.
static NSString * const ACImageNamePromoSpringMan AC_SWIFT_PRIVATE = @"PromoSpringMan";

/// The "PromoSpringShoes" asset catalog image resource.
static NSString * const ACImageNamePromoSpringShoes AC_SWIFT_PRIVATE = @"PromoSpringShoes";

/// The "Splash" asset catalog image resource.
static NSString * const ACImageNameSplash AC_SWIFT_PRIVATE = @"Splash";

#undef AC_SWIFT_PRIVATE
