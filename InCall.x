// Phone26InCall - màn hình đang gọi kiểu iOS 26 (chạy trong tiến trình InCallService)
//  - nền chuyển màu (xanh olive -> xanh dương -> tím than) giống iOS 26
//  - nút tròn có viền kính mờ, bấm có hiệu ứng nảy
//  - xếp lại các nút: hàng 1 = Loa ngoài | FaceTime | Tắt tiếng ; hàng 2 = Thêm | Kết thúc | Bàn phím
// Tweak này tách riêng để lỡ lỗi thì chỉ cần xóa Phone26InCall.* mà không ảnh hưởng tweak chính.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <string.h>
#import "Dump.h"

static const BOOL kEnable = YES;      // NO = tắt hoàn toàn
static const BOOL kRearrange = YES;   // NO = giữ vị trí các nút như iPhone gốc
static char kSlotsKey, kIconKey;

static void tw26_ctl(UIView *v, NSMutableArray *out) {
    for (UIView *s in v.subviews) {
        if ([s isKindOfClass:UIControl.class]) [out addObject:s];
        tw26_ctl(s, out);
    }
}

static void tw26_lbl(UIView *v, NSMutableArray *out) {
    for (UIView *s in v.subviews) {
        if ([s isKindOfClass:UILabel.class]) [out addObject:s];
        tw26_lbl(s, out);
    }
}

// nhận diện nút theo nhãn trợ năng / chữ trong nút
static NSString *tw26_typeOf(UIControl *c) {
    NSString *lab = (c.accessibilityLabel ?: @"").lowercaseString;
    if (lab.length == 0) lab = (c.accessibilityIdentifier ?: @"").lowercaseString;
    if (lab.length == 0) {
        NSMutableArray *ls = [NSMutableArray array];
        tw26_lbl(c, ls);
        for (UILabel *l in ls) if (l.text.length) { lab = l.text.lowercaseString; break; }
    }
    if (lab.length == 0) return nil;
    if ([lab containsString:@"facetime"]) return @"facetime";
    if ([lab containsString:@"mute"]) return @"mute";
    if ([lab containsString:@"keypad"]) return @"keypad";
    if ([lab containsString:@"speaker"] || [lab containsString:@"audio"]) return @"speaker";
    if ([lab containsString:@"add"]) return @"add";
    if ([lab containsString:@"contact"]) return @"contacts";
    if ([lab containsString:@"end"] || [lab containsString:@"hang"]) return @"end";
    return nil;
}

static void tw26_setTitle(UIControl *c, NSString *title) {
    NSMutableArray *ls = [NSMutableArray array];
    tw26_lbl(c, ls);
    for (UILabel *l in ls) {
        if (l.text.length == 0) continue;
        if (![l.text isEqualToString:title]) l.text = title;
        break;
    }
}

static void tw26_setEllipsis(UIControl *c) {
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightMedium];
    UIImage *img = [UIImage systemImageNamed:@"ellipsis" withConfiguration:cfg];
    NSMutableArray *ivs = [NSMutableArray array];
    for (UIView *s in c.subviews) if ([s isKindOfClass:UIImageView.class]) [ivs addObject:s];
    if (ivs.count == 0) {
        for (UIView *s in c.subviews)
            for (UIView *s2 in s.subviews) if ([s2 isKindOfClass:UIImageView.class]) [ivs addObject:s2];
    }
    for (UIImageView *iv in ivs) {
        CGSize z = iv.bounds.size;
        if (z.width > 46 || z.width < 10) continue;                   // bỏ ảnh nền tròn lớn
        if ([objc_getAssociatedObject(iv, &kIconKey) boolValue]) return;
        iv.image = img;
        iv.tintColor = [UIColor whiteColor];
        objc_setAssociatedObject(iv, &kIconKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
}

static void tw26_rearrange(UIViewController *vc) {
    UIView *root = vc.view;
    NSMutableArray *cs = [NSMutableArray array];
    tw26_ctl(root, cs);
    NSMutableDictionary<NSString *, UIControl *> *m = [NSMutableDictionary dictionary];
    for (UIControl *c in cs) {
        CGSize z = c.bounds.size;
        if (z.width < 55 || z.width > 130 || z.height < 55 || z.height > 160) continue;
        NSString *t = tw26_typeOf(c);
        if (t && !m[t]) m[t] = c;
    }
    for (NSString *k in @[@"mute", @"keypad", @"speaker", @"add", @"facetime", @"end"])
        if (!m[k]) return;                                            // thiếu nút (vd. cuộc gọi đến) -> không đổi gì

    NSDictionary *slots = objc_getAssociatedObject(vc, &kSlotsKey);
    if (!slots) {                                                     // vị trí gốc, tính 1 lần khi nút chưa bị dời
        CGRect (^fr)(UIControl *) = ^CGRect(UIControl *c) { return [c convertRect:c.bounds toView:root]; };
        NSMutableArray *row1 = [@[m[@"mute"], m[@"keypad"], m[@"speaker"]] mutableCopy];
        [row1 sortUsingComparator:^NSComparisonResult(UIControl *a, UIControl *b) {
            return CGRectGetMidX(fr(a)) < CGRectGetMidX(fr(b)) ? NSOrderedAscending : NSOrderedDescending;
        }];
        CGFloat x0 = CGRectGetMidX(fr(row1[0])), x1 = CGRectGetMidX(fr(row1[1])), x2 = CGRectGetMidX(fr(row1[2]));
        CGFloat y1 = CGRectGetMinY(fr(row1[0]));
        CGFloat y2 = (CGRectGetMinY(fr(m[@"add"])) + CGRectGetMinY(fr(m[@"facetime"]))) / 2.0;
        CGFloat y3 = CGRectGetMinY(fr(m[@"end"]));
        if (!(x0 < x1 && x1 < x2 && y2 > y1 && y3 > y2 && (y3 - y2) < 240 && (y2 - y1) < 240)) return;   // bố cục lạ -> bỏ qua
        slots = @{@"x0": @(x0), @"x1": @(x1), @"x2": @(x2), @"y2": @(y2), @"y3": @(y3)};
        objc_setAssociatedObject(vc, &kSlotsKey, slots, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGFloat x0 = [slots[@"x0"] doubleValue], x1 = [slots[@"x1"] doubleValue], x2 = [slots[@"x2"] doubleValue];
    CGFloat y2 = [slots[@"y2"] doubleValue], y3 = [slots[@"y3"] doubleValue];
    NSDictionary *pos = @{@"speaker": @[@(x0), @(y2)], @"facetime": @[@(x1), @(y2)], @"mute": @[@(x2), @(y2)],
                          @"add": @[@(x0), @(y3)], @"end": @[@(x1), @(y3)], @"keypad": @[@(x2), @(y3)]};
    NSDictionary *titles = @{@"speaker": @"Loa ngoài", @"facetime": @"FaceTime", @"mute": @"Tắt tiếng",
                             @"add": @"Thêm", @"end": @"Kết thúc", @"keypad": @"Bàn phím"};
    for (NSString *k in pos) {
        UIControl *c = m[k];
        NSArray *xy = pos[k];
        CGPoint desired = CGPointMake([xy[0] doubleValue], [xy[1] doubleValue] + c.bounds.size.height / 2.0);
        CGPoint p = [c.superview convertPoint:desired fromView:root];
        if (fabs(c.center.x - p.x) > 0.5 || fabs(c.center.y - p.y) > 0.5) c.center = p;
        tw26_setTitle(c, titles[k]);
    }
    tw26_setEllipsis(m[@"add"]);
    UIControl *contacts = m[@"contacts"];                             // iOS 26 không có nút Danh bạ trong lưới
    if (contacts) { if (contacts.alpha != 0) contacts.alpha = 0; contacts.userInteractionEnabled = NO; }
}

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
        g.colors = @[(id)[UIColor colorWithRed:0.31 green:0.34 blue:0.20 alpha:1].CGColor,
                     (id)[UIColor colorWithRed:0.14 green:0.24 blue:0.56 alpha:1].CGColor,
                     (id)[UIColor colorWithRed:0.24 green:0.18 blue:0.24 alpha:1].CGColor];
        g.locations = @[@0.0, @0.55, @1.0];
        g.startPoint = CGPointMake(0.5, 0);
        g.endPoint = CGPointMake(0.5, 1);
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
    if (kRearrange) tw26_rearrange(self);
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

// hiệu ứng nhấn: nút co lại rồi nảy về
%hook UIControl
- (void)setHighlighted:(BOOL)h {
    BOOL was = self.isHighlighted;
    %orig;
    if (!kEnable || was == h) return;
    CGSize z = self.bounds.size;
    if (z.width < 54 || z.width > 130 || z.height < 54 || z.height > 160) return;
    CGAffineTransform t = h ? CGAffineTransformMakeScale(0.90, 0.90) : CGAffineTransformIdentity;
    [UIView animateWithDuration:(h ? 0.16 : 0.55) delay:0
         usingSpringWithDamping:(h ? 1.0 : 0.5) initialSpringVelocity:(h ? 0 : 10)
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{ self.transform = t; } completion:nil];
}
%end

%ctor {
    %init;
    tw26_dumpInstall();
}
