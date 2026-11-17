// Phone26InCall - màn hình đang gọi kiểu iOS 26 (chạy trong tiến trình InCallService)
//  - nền chuyển màu xanh ngọc -> xanh navy
//  - các nút tròn có viền kính mờ
// Tweak này tách riêng để lỡ lỗi thì chỉ cần xóa Phone26InCall.* mà không ảnh hưởng tweak chính.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <string.h>
#import "Dump.h"

static const BOOL kEnable = YES;   // NO = tắt hoàn toàn

%hook UIViewController
- (void)viewDidLayoutSubviews {
    %orig;
    if (!kEnable) return;
    const char *n = class_getName(object_getClass(self));
    if (!strstr(n, "InCallRoot")) return;

    UIView *root = self.view;
    CAGradientLayer *g = nil;
    for (CALayer *l in root.layer.sublayers)
        if ([l.name isEqualToString:@"tw26grad"]) { g = (CAGradientLayer *)l; break; }
    if (!g) {
        g = [CAGradientLayer layer];
        g.name = @"tw26grad";
        g.colors = @[(id)[UIColor colorWithRed:0.20 green:0.42 blue:0.47 alpha:1].CGColor,
                     (id)[UIColor colorWithRed:0.00 green:0.27 blue:0.36 alpha:1].CGColor,
                     (id)[UIColor colorWithRed:0.00 green:0.16 blue:0.29 alpha:1].CGColor];
        g.startPoint = CGPointMake(0, 0);
        g.endPoint = CGPointMake(1, 1);
        [root.layer insertSublayer:g atIndex:0];
    }
    g.frame = root.bounds;

    // làm trong suốt lớp nền/blur gốc phủ toàn màn hình để thấy nền mới
    for (UIView *s in root.subviews) {
        const char *sn = class_getName(object_getClass(s));
        if ((strcasestr(sn, "Background") || strcasestr(sn, "Backdrop")) &&
            s.bounds.size.width >= root.bounds.size.width * 0.9)
            s.alpha = 0;
    }
}
%end

%hook UIView
- (void)layoutSubviews {
    %orig;
    if (!kEnable || ![self isKindOfClass:UIControl.class]) return;
    CGSize z = self.bounds.size;
    if (z.width < 54 || z.width > 110 || fabs(z.width - z.height) > 4) return;
    const char *n = class_getName(object_getClass(self));
    if (!strcasestr(n, "Button")) return;
    self.layer.cornerRadius = z.width / 2.0;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.28].CGColor;
}
%end

%ctor {
    %init;
    tw26_dumpInstall();
}
