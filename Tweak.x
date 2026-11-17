// Phone26 v5 - Giao diện app Điện thoại kiểu iOS 26 (MobilePhone)
//  - Chế độ Hợp nhất / Cổ điển (menu ≡ ở màn hình Gần đây), danh bạ, chi tiết liên hệ, bàn phím số
//  - Tab bar nổi: 3 tab + nút tìm kiếm tròn tách rời cùng hàng
//  - Mỗi dòng cuộc gọi: avatar tròn gradient + tên đậm + giờ + nút gọi/video tròn xám bên phải
//  - Nút "Sửa" / "lọc" trên thanh tiêu đề thành viên thuốc kính mờ, tiêu đề nhỏ ở giữa
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <string.h>
#import "Dump.h"

// ===================== CẤU HÌNH =====================
// YES: bấm nút tròn bên phải = gọi lại (giống bấm dòng).  NO: bấm nút = mở chi tiết cuộc gọi (nút "i" cũ)
static const BOOL kButtonCalls = YES;

// Cỡ chữ dòng cuộc gọi (chỉnh nhỏ/lớn tại đây)
static const CGFloat kNameSize = 18.0, kSubSize = 15.5, kTimeSize = 15.5;
static const CGFloat kTextGap = 8.0;   // khoảng cách dọc tên <-> dòng phụ
// Chữ trên thanh tiêu đề (đổi tại đây)
#define kTitleText @"Cuộc gọi"
#define kEditText  @"Sửa"
#define kDoneText  @"Xong"
#define kAllText   @"Tất cả"
#define kMissedText @"Cuộc gọi nhỡ"
#define kRecentsText @"Gần đây"
#define kSearchText @"Tìm kiếm"
#define kContactsTitle @"Liên hệ"
static NSString *const kLayoutKey = @"Phone26.layout";   // 0 = Hợp nhất, 1 = Cổ điển
static const BOOL kStyleNavButtons = NO;   // YES: bo tròn các nút nav gốc ở màn hình khác

static const CGFloat kBarH = 64.0, kSide = 18.0, kGap = 10.0;   // tab bar
static const CGFloat kRowH = 80.0, kAvD = 50.0, kBtnD = 54.0, kRowSide = 16.0;
static const CGFloat kAvGap = 10.0;   // khoảng cách avatar -> tên (nhỏ hơn = gần hơn) // dòng cuộc gọi
static const NSInteger kSearchTag = 26001, kEffectTag = 26002, kCapsuleTag = 26003;
static const NSInteger kAvTag = 26010, kAvLetterTag = 26011, kAvIconTag = 26012, kCallTag = 26013, kNavTag = 26020;
static const NSInteger kHeaderTag = 26030, kMenuTag = 26031;
static char kRowKey, kAllKey, kHdrKey, kDetailKey;

@interface UITabBarController (Phone26)
- (void)tw26_search;
@end
@interface UITableViewCell (Phone26)
- (void)tw26_callTapped;
@end

#pragma mark - Helpers chung

static NSString *tw26_name(UIViewController *vc) {
    NSMutableString *s = [NSMutableString stringWithString:NSStringFromClass(vc.class)];
    if ([vc isKindOfClass:UINavigationController.class])
        for (UIViewController *c in ((UINavigationController *)vc).viewControllers)
            [s appendString:NSStringFromClass(c.class)];
    return s.lowercaseString;
}

static BOOL tw26_classic(void) {
    return [[NSUserDefaults standardUserDefaults] integerForKey:kLayoutKey] == 1;
}

static NSArray *tw26_filter(NSArray *vcs) {
    if (tw26_classic() || vcs.count <= 3) return vcs;
    NSMutableArray *out = [NSMutableArray array];
    for (UIViewController *vc in vcs) {
        NSString *n = tw26_name(vc);
        if ([n containsString:@"favorite"] || [n containsString:@"voicemail"]) continue;
        [out addObject:vc];
    }
    return out.count == 3 ? out : vcs;
}

// nhớ danh sách đầy đủ 5 tab để chuyển qua lại Cổ điển / Hợp nhất
static NSArray *tw26_prep(UITabBarController *tbc, NSArray *vcs) {
    NSArray *all = objc_getAssociatedObject(tbc, &kAllKey);
    if (vcs.count > all.count) objc_setAssociatedObject(tbc, &kAllKey, vcs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return tw26_filter(vcs);
}

static void tw26_collectLabels(UIView *v, NSMutableArray *out) {
    for (UIView *s in v.subviews) {
        if ([s isKindOfClass:UILabel.class]) [out addObject:s];
        tw26_collectLabels(s, out);
    }
}

static UISearchBar *tw26_findSB(UIView *v) {
    if ([v isKindOfClass:UISearchBar.class]) return (UISearchBar *)v;
    for (UIView *s in v.subviews) { UISearchBar *r = tw26_findSB(s); if (r) return r; }
    return nil;
}

static UITableView *tw26_tableOf(UIView *v) {
    UIView *p = v.superview;
    while (p && ![p isKindOfClass:UITableView.class]) p = p.superview;
    return (UITableView *)p;
}

static UITableView *tw26_findTable(UIView *v) {
    if ([v isKindOfClass:UITableView.class]) return (UITableView *)v;
    for (UIView *s in v.subviews) { UITableView *r = tw26_findTable(s); if (r) return r; }
    return nil;
}

static UIViewController *tw26_vcOf(UIView *v) {
    UIResponder *r = v;
    while (r && ![r isKindOfClass:UIViewController.class]) r = r.nextResponder;
    return (UIViewController *)r;
}

static UIColor *tw26_dyn(UIColor *light, UIColor *dark) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light;
    }];
}

// Chữ cái đầu: 1 chữ (Gần đây) hoặc 2 chữ = đầu từ đầu + đầu từ cuối (Danh bạ)
static NSString *tw26_initials(NSString *t, NSInteger maxLetters) {
    NSMutableArray *letters = [NSMutableArray array];
    for (NSString *w in [t componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
        if (!w.length) continue;
        NSString *ch = [[w substringWithRange:[w rangeOfComposedCharacterSequenceAtIndex:0]] uppercaseString];
        if (ch.length && [[NSCharacterSet letterCharacterSet] characterIsMember:[ch characterAtIndex:0]]) [letters addObject:ch];
    }
    if (!letters.count) return @"";
    if (maxLetters <= 1 || letters.count == 1) return letters.firstObject;
    return [letters.firstObject stringByAppendingString:letters.lastObject];
}

static UIView *tw26_makeAvatar(CGFloat d) {
    UIView *av = [UIView new];
    av.tag = kAvTag;
    av.userInteractionEnabled = NO;
    av.clipsToBounds = YES;
    av.layer.cornerRadius = d / 2.0;
    CAGradientLayer *g = [CAGradientLayer layer];
    g.frame = CGRectMake(0, 0, d, d);
    g.colors = @[(id)[UIColor colorWithRed:0.68 green:0.76 blue:0.89 alpha:1].CGColor,
                 (id)[UIColor colorWithRed:0.43 green:0.49 blue:0.72 alpha:1].CGColor];
    [av.layer addSublayer:g];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, d, d)];
    l.tag = kAvLetterTag;
    l.textAlignment = NSTextAlignmentCenter;
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont systemFontOfSize:d * 0.44 weight:UIFontWeightSemibold];
    l.adjustsFontSizeToFitWidth = YES;
    l.minimumScaleFactor = 0.6;
    [av addSubview:l];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(d * 0.24, d * 0.24, d * 0.52, d * 0.52)];
    iv.tag = kAvIconTag;
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.tintColor = [UIColor whiteColor];
    iv.image = [UIImage systemImageNamed:@"person.fill"];
    [av addSubview:iv];
    return av;
}

static void tw26_setAvatar(UIView *av, NSString *name, NSInteger maxLetters) {
    NSString *s2 = tw26_initials(name, maxLetters);
    UILabel *l = (UILabel *)[av viewWithTag:kAvLetterTag];
    UIView *i = [av viewWithTag:kAvIconTag];
    l.text = s2;
    l.hidden = (s2.length == 0);
    i.hidden = (s2.length != 0);
}

#pragma mark - Tab bar

static CGRect tw26_barFrame(UITabBar *bar, CGRect orig) {
    if (tw26_classic()) return orig;   // Cổ điển: giữ thanh tab mặc định
    UIView *sv = bar.superview;
    if (!sv || sv.bounds.size.width < 1) return orig;
    CGRect b = sv.bounds;
    CGFloat margin = sv.safeAreaInsets.bottom > 0 ? 18.0 : 12.0;
    CGFloat w = b.size.width - 2 * kSide - (tw26_classic() ? 0.0 : kGap + kBarH);
    return CGRectMake(kSide, b.size.height - margin - kBarH, w, kBarH);
}

static void tw26_applyItemColors(UITabBarItemAppearance *it) {
    UIColor *n = [UIColor labelColor], *s = [UIColor systemBlueColor];
    it.normal.iconColor = n;
    it.normal.titleTextAttributes = @{NSForegroundColorAttributeName: n};
    it.selected.iconColor = s;
    it.selected.titleTextAttributes = @{NSForegroundColorAttributeName: s};
}

static UITabBarAppearance *tw26_customAppearance(void) {
    UITabBarAppearance *ap = [UITabBarAppearance new];
    [ap configureWithTransparentBackground];
    tw26_applyItemColors(ap.stackedLayoutAppearance);
    tw26_applyItemColors(ap.inlineLayoutAppearance);
    tw26_applyItemColors(ap.compactInlineLayoutAppearance);
    return ap;
}

static char kBarModeKey;

static void tw26_style(UITabBar *bar, BOOL animated) {
    CGRect bounds = bar.bounds;
    if (bounds.size.width < 1) return;

    NSInteger want = tw26_classic() ? 2 : 1;
    NSInteger have = [objc_getAssociatedObject(bar, &kBarModeKey) integerValue];
    UIView *ev0 = [bar viewWithTag:kEffectTag];
    UIView *cap0 = [bar viewWithTag:kCapsuleTag];

    if (want == 2) {                       // Cổ điển: trả về thanh tab mặc định của iPhone
        if (have != 2) {
            objc_setAssociatedObject(bar, &kBarModeKey, @2, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            UITabBarAppearance *d = [UITabBarAppearance new];
            [d configureWithDefaultBackground];
            bar.standardAppearance = d;
            bar.scrollEdgeAppearance = d;
            ev0.hidden = YES;
            cap0.hidden = YES;
            bar.layer.shadowOpacity = 0;
        }
        return;
    }
    if (have != 1) {                       // Hợp nhất: thanh nổi kiểu iOS 26
        objc_setAssociatedObject(bar, &kBarModeKey, @1, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UITabBarAppearance *ap = tw26_customAppearance();
        bar.standardAppearance = ap;
        bar.scrollEdgeAppearance = ap;
        ev0.hidden = NO;
        cap0.hidden = NO;
        bar.layer.shadowOpacity = 0.12;
    }

    UIVisualEffectView *ev = (UIVisualEffectView *)ev0;
    if (!ev) {
        ev = [[UIVisualEffectView alloc] initWithEffect:
              [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
        ev.tag = kEffectTag;
        ev.userInteractionEnabled = NO;
        ev.clipsToBounds = YES;
        ev.layer.cornerCurve = kCACornerCurveContinuous;
        [bar insertSubview:ev atIndex:0];

        UIView *cap = [UIView new];
        cap.tag = kCapsuleTag;
        cap.userInteractionEnabled = NO;
        cap.backgroundColor = [UIColor tertiarySystemFillColor];
        [bar insertSubview:cap atIndex:1];

        bar.layer.shadowColor = [UIColor blackColor].CGColor;
        bar.layer.shadowOpacity = 0.12;
        bar.layer.shadowRadius = 14;
        bar.layer.shadowOffset = CGSizeMake(0, 4);
    }
    ev.frame = bounds;
    ev.layer.cornerRadius = bounds.size.height / 2.0;
    bar.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                                      cornerRadius:bounds.size.height / 2.0].CGPath;

    UIView *cap = [bar viewWithTag:kCapsuleTag];
    NSMutableArray<UIView *> *btns = [NSMutableArray array];
    for (UIView *s in bar.subviews)
        if ([NSStringFromClass(s.class) isEqualToString:@"UITabBarButton"]) [btns addObject:s];
    [btns sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSUInteger idx = bar.selectedItem ? [bar.items indexOfObject:bar.selectedItem] : NSNotFound;
    if (cap && idx != NSNotFound && idx < btns.count) {
        CGRect f = CGRectInset(btns[idx].frame, 4, 6);
        void (^apply)(void) = ^{ cap.frame = f; cap.layer.cornerRadius = f.size.height / 2.0; };
        if (animated && !CGRectIsEmpty(cap.frame))
            [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.3
                                options:UIViewAnimationOptionBeginFromCurrentState animations:apply completion:nil];
        else apply();
    }
}

%hook UITabBar
- (void)setFrame:(CGRect)f { %orig(tw26_barFrame(self, f)); }
- (void)layoutSubviews {
    %orig;
    CGRect nf = tw26_barFrame(self, self.frame);
    if (!CGRectEqualToRect(nf, self.frame)) self.frame = nf;
    tw26_style(self, NO);
}
- (void)setSelectedItem:(UITabBarItem *)item { %orig; tw26_style(self, YES); }
%end

%hook UITabBarController
- (void)setViewControllers:(NSArray *)vcs animated:(BOOL)animated { %orig(tw26_prep(self, vcs), animated); }
- (void)setViewControllers:(NSArray *)vcs { %orig(tw26_prep(self, vcs)); }

- (void)viewDidLayoutSubviews {
    %orig;
    UIView *host = self.view;
    UIView *box = [host viewWithTag:kSearchTag];
    if (!box) {
        box = [UIView new];
        box.tag = kSearchTag;
        box.layer.shadowColor = [UIColor blackColor].CGColor;
        box.layer.shadowOpacity = 0.12;
        box.layer.shadowRadius = 14;
        box.layer.shadowOffset = CGSizeMake(0, 4);

        UIVisualEffectView *ev = [[UIVisualEffectView alloc] initWithEffect:
                                  [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
        ev.frame = CGRectMake(0, 0, kBarH, kBarH);
        ev.clipsToBounds = YES;
        ev.layer.cornerRadius = kBarH / 2.0;
        [box addSubview:ev];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium];
        [btn setImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:cfg] forState:UIControlStateNormal];
        btn.tintColor = [UIColor labelColor];
        btn.frame = CGRectMake(0, 0, kBarH, kBarH);
        [btn addTarget:self action:@selector(tw26_search) forControlEvents:UIControlEventTouchUpInside];
        [ev.contentView addSubview:btn];
        [host addSubview:box];
    }
    CGRect bf = self.tabBar.frame;
    box.hidden = tw26_classic();
    box.frame = CGRectMake(host.bounds.size.width - kSide - kBarH, bf.origin.y, kBarH, kBarH);
    box.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:box.bounds cornerRadius:kBarH / 2.0].CGPath;
    [host bringSubviewToFront:box];
}

%new
- (void)tw26_search {
    NSUInteger found = NSNotFound, i = 0;
    for (UIViewController *vc in self.viewControllers) {
        if ([tw26_name(vc) containsString:@"contact"]) { found = i; break; }
        i++;
    }
    if (found == NSNotFound) found = 1;
    self.selectedIndex = found;
    __weak UITabBarController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UITabBarController *s = weakSelf;
        UIViewController *vc = s.selectedViewController;
        UIViewController *top = [vc isKindOfClass:UINavigationController.class]
            ? ((UINavigationController *)vc).topViewController : vc;
        UISearchController *sc = top.navigationItem.searchController;
        if (sc) { sc.active = YES; [sc.searchBar becomeFirstResponder]; return; }
        [tw26_findSB(vc.view) becomeFirstResponder];
    });
}
%end

#pragma mark - Thanh tiêu đề (Sửa / lọc thành viên thuốc kính mờ)

static void tw26_findBarButtons(UIView *v, NSMutableArray *out) {
    for (UIView *s in v.subviews) {
        if ([NSStringFromClass(s.class) containsString:@"ButtonBarButton"]) [out addObject:s];
        else tw26_findBarButtons(s, out);
    }
}

%hook UINavigationBar
- (void)layoutSubviews {
    %orig;
    if (self.prefersLargeTitles) self.prefersLargeTitles = NO;
    if (!self.titleTextAttributes)
        self.titleTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:19 weight:UIFontWeightSemibold]};

    if (!kStyleNavButtons) return;
    NSMutableArray<UIView *> *btns = [NSMutableArray array];
    tw26_findBarButtons(self, btns);
    CGFloat barW = self.bounds.size.width;
    for (UIView *b in btns) {
        CGFloat bw = b.bounds.size.width, bh = b.bounds.size.height;
        if (bw < 1 || bh < 1) continue;
        NSMutableArray *ls = [NSMutableArray array];
        tw26_collectLabels(b, ls);
        BOOL hasText = NO;
        for (UILabel *l in ls) if (!l.hidden && l.text.length) { hasText = YES; break; }
        CGFloat h = 40.0;
        CGFloat w = hasText ? MAX(64.0, bw + 8.0) : 40.0;
        CGRect f = CGRectMake((bw - w) / 2.0, (bh - h) / 2.0, w, h);
        // không để viên thuốc tràn ra ngoài màn hình
        CGRect inBar = [b convertRect:f toView:self];
        CGFloat dx = 0;
        if (CGRectGetMaxX(inBar) > barW - 10) dx = (barW - 10) - CGRectGetMaxX(inBar);
        if (inBar.origin.x + dx < 10) dx = 10 - inBar.origin.x;
        f.origin.x += dx;
        b.clipsToBounds = NO;
        UIVisualEffectView *ev = (UIVisualEffectView *)[b viewWithTag:kNavTag];
        if (!ev) {
            ev = [[UIVisualEffectView alloc] initWithEffect:
                  [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
            ev.tag = kNavTag;
            ev.userInteractionEnabled = NO;
            ev.clipsToBounds = YES;
            ev.layer.cornerCurve = kCACornerCurveContinuous;
            [b insertSubview:ev atIndex:0];
        }
        ev.frame = f;
        ev.layer.cornerRadius = h / 2.0;
    }
}
%end


#pragma mark - Màn hình Gần đây: thanh tiêu đề, menu ≡, tiêu đề lớn (Cổ điển)

@interface TW26State : NSObject
@property (nonatomic, strong) UIBarButtonItem *native, *edit, *filter;
@property (nonatomic, strong) UIButton *editBtn;
@property (nonatomic, strong) UISegmentedControl *seg;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *emptyTitle;
@property (nonatomic, weak) UIViewController *vc;
@end
@implementation TW26State
@end

static char kStateKey, kItemStateKey;
static BOOL gApplying = NO;   // YES khi chính tweak đang đổi nút -> không chặn

static void tw26_applyNav(UIViewController *vc);
static void tw26_applyMode(UIViewController *vc);
static void tw26_showMenu(UIView *anchor, UIViewController *vc, TW26State *st);

static UISegmentedControl *tw26_findSeg(UIView *v) {
    if ([v isKindOfClass:UISegmentedControl.class]) return (UISegmentedControl *)v;
    for (UIView *s in v.subviews) { UISegmentedControl *r = tw26_findSeg(s); if (r) return r; }
    return nil;
}

static UIView *tw26_capsule(CGFloat w, CGFloat h, UIView *content) {
    UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    c.translatesAutoresizingMaskIntoConstraints = NO;
    [c.widthAnchor constraintEqualToConstant:w].active = YES;
    [c.heightAnchor constraintEqualToConstant:h].active = YES;
    UIVisualEffectView *ev = [[UIVisualEffectView alloc] initWithEffect:
                              [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
    ev.frame = c.bounds;
    ev.userInteractionEnabled = NO;
    ev.clipsToBounds = YES;
    ev.layer.cornerRadius = h / 2.0;
    ev.layer.cornerCurve = kCACornerCurveContinuous;
    ev.layer.borderWidth = 0.8;
    ev.layer.borderColor = [[UIColor separatorColor] resolvedColorWithTraitCollection:UITraitCollection.currentTraitCollection].CGColor;
    [c addSubview:ev];
    content.frame = c.bounds;
    content.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [c addSubview:content];
    return c;
}

#pragma mark Hình minh họa Cổ điển / Hợp nhất

static UIImage *tw26_phoneIllus(BOOL classic, BOOL selected) {
    CGSize sz = CGSizeMake(46, 88);
    UIGraphicsImageRenderer *rd = [[UIGraphicsImageRenderer alloc] initWithSize:sz];
    return [rd imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        UIColor *main = selected ? [UIColor systemBlueColor] : [UIColor systemGrayColor];
        UIColor *soft = [main colorWithAlphaComponent:0.20];
        UIBezierPath *outer = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(1.5, 1.5, 43, 85) cornerRadius:9];
        outer.lineWidth = 2.5;
        [main setStroke];
        [outer stroke];
        [main setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(16, 6, 14, 4) cornerRadius:2] fill];
        [soft setFill];
        if (classic) {
            for (int i = 0; i < 6; i++)
                [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(5, 16 + i * 9, 36, 6) cornerRadius:2] fill];
            [main setFill];
            for (int i = 0; i < 5; i++)
                [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(7 + i * 8, 76, 4, 4)] fill];
        } else {
            for (int a1 = 0; a1 < 2; a1++)
                for (int b1 = 0; b1 < 4; b1++)
                    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(5 + b1 * 9.5, 15 + a1 * 9.5, 7.5, 7.5) cornerRadius:2] fill];
            for (int i = 0; i < 4; i++)
                [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(5, 38 + i * 9, 36, 6) cornerRadius:2] fill];
            [main setFill];
            for (int i = 0; i < 3; i++)
                [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(8 + i * 8, 76, 4, 4)] fill];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(35, 76, 4, 4)] fill];
        }
    }];
}

#pragma mark Tiêu đề lớn + ô tìm kiếm (chế độ Cổ điển)

static UIView *tw26_makeHeader(CGFloat width) {
    UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 124)];
    h.tag = kHeaderTag;
    h.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(kRowSide + 2, 2, width - 2 * kRowSide, 46)];
    t.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    t.text = kRecentsText;
    t.font = [UIFont systemFontOfSize:36 weight:UIFontWeightHeavy];
    t.textColor = [UIColor labelColor];
    [h addSubview:t];

    UIButton *sb = [UIButton buttonWithType:UIButtonTypeCustom];
    sb.frame = CGRectMake(kRowSide, 60, width - 2 * kRowSide, 50);
    sb.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    sb.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.14];
    sb.layer.cornerRadius = 25;
    sb.layer.cornerCurve = kCACornerCurveContinuous;
    UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
    cfg.image = [UIImage systemImageNamed:@"magnifyingglass"
                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightBold]];
    cfg.imagePadding = 10;
    cfg.baseForegroundColor = [UIColor labelColor];
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(0, 16, 0, 16);
    cfg.attributedTitle = [[NSAttributedString alloc] initWithString:kSearchText attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    sb.configuration = cfg;
    sb.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    __weak UIView *wh = h;
    [sb addAction:[UIAction actionWithHandler:^(UIAction *a) {
        UIViewController *v = tw26_vcOf(wh);
        [v.tabBarController tw26_search];
    }] forControlEvents:UIControlEventTouchUpInside];
    [h addSubview:sb];
    return h;
}

static void tw26_ensureHeader(UITableView *tv) {
    if (!tv) return;
    BOOL has = (tv.tableHeaderView.tag == kHeaderTag);
    if (tw26_classic() == has) return;
    if ([objc_getAssociatedObject(tv, &kHdrKey) boolValue]) return;
    objc_setAssociatedObject(tv, &kHdrKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_async(dispatch_get_main_queue(), ^{
        objc_setAssociatedObject(tv, &kHdrKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        BOOL has2 = (tv.tableHeaderView.tag == kHeaderTag);
        if (tw26_classic() && !has2) tv.tableHeaderView = tw26_makeHeader(tv.bounds.size.width);
        else if (!tw26_classic() && has2) tv.tableHeaderView = nil;
    });
}

#pragma mark Menu ≡ (popover tùy biến giống iOS 26)

static UIView *tw26_divider(CGFloat y, CGFloat w) {
    UIView *d = [[UIView alloc] initWithFrame:CGRectMake(16, y, w - 32, 0.5)];
    d.backgroundColor = [UIColor separatorColor];
    return d;
}

static UIButton *tw26_rowButton(CGRect f, void (^handler)(void)) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = f;
    [b addAction:[UIAction actionWithHandler:^(UIAction *a) { handler(); }] forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static UILabel *tw26_label(CGRect f, NSString *t, NSTextAlignment al) {
    UILabel *l = [[UILabel alloc] initWithFrame:f];
    l.text = t;
    l.textAlignment = al;
    l.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    l.textColor = [UIColor labelColor];
    return l;
}

static void tw26_showMenu(UIView *anchor, UIViewController *vc, TW26State *st) {
    UIWindow *win = anchor.window ?: vc.view.window;
    if (!win || [win viewWithTag:kMenuTag]) return;

    UIView *overlay = [[UIView alloc] initWithFrame:win.bounds];
    overlay.tag = kMenuTag;
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    __weak UIView *wo = overlay;
    void (^dismiss)(void) = ^{
        UIView *o = wo;
        if (!o) return;
        [UIView animateWithDuration:0.18 animations:^{ o.alpha = 0; } completion:^(BOOL f) { [o removeFromSuperview]; }];
    };
    UIButton *backdrop = tw26_rowButton(overlay.bounds, dismiss);
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [overlay addSubview:backdrop];

    const CGFloat W = 252, secH = 200, rowH = 54;
    CGFloat H = secH + 1 + rowH * 2 + 1 + rowH;
    CGRect ar = [anchor convertRect:anchor.bounds toView:win];
    CGFloat x = MIN(win.bounds.size.width - W - 14, MAX(14, CGRectGetMaxX(ar) - W));
    CGFloat y = CGRectGetMaxY(ar) + 10;

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(x, y, W, H)];
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.18;
    card.layer.shadowRadius = 28;
    card.layer.shadowOffset = CGSizeMake(0, 10);
    card.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:card.bounds cornerRadius:30].CGPath;
    UIVisualEffectView *ev = [[UIVisualEffectView alloc] initWithEffect:
                              [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
    ev.frame = card.bounds;
    ev.clipsToBounds = YES;
    ev.layer.cornerRadius = 30;
    ev.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:ev];
    UIView *ct = ev.contentView;

    // --- Cổ điển / Hợp nhất
    BOOL classicNow = tw26_classic();
    __weak UIViewController *wvc = vc;
    for (int i = 0; i < 2; i++) {
        BOOL isClassicOpt = (i == 0);
        BOOL sel = (isClassicOpt == classicNow);
        CGFloat colW = W / 2.0, cx = colW * i + colW / 2.0;

        UIImageView *iv = [[UIImageView alloc] initWithImage:tw26_phoneIllus(isClassicOpt, sel)];
        iv.frame = CGRectMake(cx - 23, 16, 46, 88);
        [ct addSubview:iv];
        [ct addSubview:tw26_label(CGRectMake(colW * i, 112, colW, 24), isClassicOpt ? @"Cổ điển" : @"Hợp nhất", NSTextAlignmentCenter)];

        UIView *radio = [[UIView alloc] initWithFrame:CGRectMake(cx - 15, 148, 30, 30)];
        radio.layer.cornerRadius = 15;
        if (sel) {
            radio.backgroundColor = [UIColor systemBlueColor];
            UIImageView *ck = [[UIImageView alloc] initWithImage:
                               [UIImage systemImageNamed:@"checkmark"
                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]]];
            ck.tintColor = [UIColor whiteColor];
            ck.contentMode = UIViewContentModeCenter;
            ck.frame = radio.bounds;
            [radio addSubview:ck];
        } else {
            radio.layer.borderWidth = 2.5;
            radio.layer.borderColor = [UIColor systemGrayColor].CGColor;
        }
        [ct addSubview:radio];

        [ct addSubview:tw26_rowButton(CGRectMake(colW * i, 0, colW, secH), ^{
            UIViewController *v = wvc;
            if (v && isClassicOpt != tw26_classic()) {
                [wo removeFromSuperview];      // bỏ menu ngay để ảnh chụp chuyển cảnh không dính menu
                [[NSUserDefaults standardUserDefaults] setInteger:(isClassicOpt ? 1 : 0) forKey:kLayoutKey];
                tw26_applyMode(v);
            } else {
                dismiss();
            }
        })];
    }

    // --- Bộ lọc: Cuộc gọi / Cuộc gọi nhỡ
    [ct addSubview:tw26_divider(secH, W)];
    NSArray *rowTitles = @[kTitleText, kMissedText];
    NSArray *rowIcons = @[@"phone", @"phone.arrow.down.left"];
    NSInteger cur = st.seg ? st.seg.selectedSegmentIndex : 0;
    __weak TW26State *wst = st;
    void (^setFilter)(NSInteger) = ^(NSInteger idx) {
        TW26State *s2 = wst;
        if (s2.seg && s2.seg.numberOfSegments > idx) {
            s2.seg.selectedSegmentIndex = idx;
            [s2.seg sendActionsForControlEvents:UIControlEventValueChanged];
        }
    };
    UIImageSymbolConfiguration *sc = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightRegular];
    for (int i = 0; i < 2; i++) {
        CGFloat ry = secH + 1 + rowH * i;
        if (cur == i) {
            UIImageView *ck = [[UIImageView alloc] initWithImage:
                               [UIImage systemImageNamed:@"checkmark"
                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold]]];
            ck.tintColor = [UIColor labelColor];
            ck.contentMode = UIViewContentModeCenter;
            ck.frame = CGRectMake(14, ry + 14, 26, 26);
            [ct addSubview:ck];
        }
        UIImageView *ic = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:rowIcons[i] withConfiguration:sc]];
        ic.tintColor = [UIColor labelColor];
        ic.contentMode = UIViewContentModeCenter;
        ic.frame = CGRectMake(48, ry + 14, 28, 26);
        [ct addSubview:ic];
        [ct addSubview:tw26_label(CGRectMake(90, ry + 15, W - 100, 24), rowTitles[i], NSTextAlignmentLeft)];
        [ct addSubview:tw26_rowButton(CGRectMake(0, ry, W, rowH), ^{ dismiss(); setFilter(i); })];
    }

    // --- Quản lý bộ lọc
    CGFloat dy = secH + 1 + rowH * 2;
    [ct addSubview:tw26_divider(dy, W)];
    [ct addSubview:tw26_label(CGRectMake(0, dy + 1 + 15, W, 24), @"Quản lý bộ lọc", NSTextAlignmentCenter)];
    [ct addSubview:tw26_rowButton(CGRectMake(0, dy + 1, W, rowH), ^{
        dismiss();
        UIViewController *v = wvc;
        if (!v) return;
        UIAlertController *al = [UIAlertController alertControllerWithTitle:@"Quản lý bộ lọc"
                                                                    message:@"Chọn bộ lọc cuộc gọi muốn hiển thị"
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
        [al addAction:[UIAlertAction actionWithTitle:kTitleText style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *a) { setFilter(0); }]];
        [al addAction:[UIAlertAction actionWithTitle:kMissedText style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *a) { setFilter(1); }]];
        [al addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
        [v presentViewController:al animated:YES completion:nil];
    })];

    [overlay addSubview:card];
    [win addSubview:overlay];
    card.alpha = 0;
    card.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.2 options:0
                     animations:^{ card.alpha = 1; card.transform = CGAffineTransformIdentity; } completion:nil];
}

#pragma mark Nút Sửa (trái) + nút lọc ≡ (phải)

static void tw26_ensureFilter(TW26State *st) {
    if (st.filter) return;
    UIButton *fb = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    [fb setImage:[UIImage systemImageNamed:@"line.3.horizontal.decrease" withConfiguration:cfg]
        forState:UIControlStateNormal];
    fb.tintColor = [UIColor labelColor];
    __weak UIViewController *wvc = st.vc;
    __weak TW26State *wst = st;
    __weak UIButton *wfb = fb;
    [fb addAction:[UIAction actionWithHandler:^(UIAction *a) {
        UIViewController *v = wvc; TW26State *s2 = wst; UIButton *b2 = wfb;
        if (v && s2 && b2) tw26_showMenu(b2, v, s2);
    }] forControlEvents:UIControlEventTouchUpInside];
    st.filter = [[UIBarButtonItem alloc] initWithCustomView:tw26_capsule(40, 40, fb)];
}

static void tw26_applyNav(UIViewController *vc) {
    if (![vc.parentViewController isKindOfClass:UINavigationController.class]) return;
    if ([NSStringFromClass(vc.class) rangeOfString:@"Recents" options:NSCaseInsensitiveSearch].location == NSNotFound) return;
    UINavigationItem *ni = vc.navigationItem;
    TW26State *st = objc_getAssociatedObject(vc, &kStateKey);
    BOOL classic = tw26_classic();

    BOOL was = gApplying;
    gApplying = YES;

    if (!st) {
        st = [TW26State new];
        st.vc = vc;
        objc_setAssociatedObject(vc, &kStateKey, st, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(ni, &kItemStateKey, st, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIViewController *wvc = vc;
        __weak TW26State *wst = st;

        UIView *tv = ni.titleView;
        st.seg = tv ? tw26_findSeg(tv) : nil;
        st.native = ni.leftBarButtonItem ?: ni.rightBarButtonItem;

        UILabel *tl = [UILabel new];
        tl.text = kTitleText;
        tl.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
        tl.textColor = [UIColor labelColor];
        [tl sizeToFit];
        st.titleLabel = tl;
        st.emptyTitle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];

        UIButton *eb = [UIButton buttonWithType:UIButtonTypeSystem];
        [eb setTitle:kEditText forState:UIControlStateNormal];
        eb.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
        [eb setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        [eb addAction:[UIAction actionWithHandler:^(UIAction *a) {
            UIViewController *v = wvc; TW26State *s2 = wst;
            if (!v || !s2) return;
            UIBarButtonItem *n = s2.native;
            if (n && n.action) [[UIApplication sharedApplication] sendAction:n.action to:n.target from:n forEvent:nil];
            else [v setEditing:!v.isEditing animated:YES];
        }] forControlEvents:UIControlEventTouchUpInside];
        st.editBtn = eb;
        st.edit = [[UIBarButtonItem alloc] initWithCustomView:tw26_capsule(68, 40, eb)];
    }

    // tiêu đề: Hợp nhất = "Cuộc gọi" nhỏ ở giữa; Cổ điển = trống (tiêu đề lớn nằm trong danh sách)
    UIView *want = classic ? st.emptyTitle : st.titleLabel;
    if (ni.titleView != want) {
        UIView *tv = ni.titleView;
        if (tv && tv != st.titleLabel && tv != st.emptyTitle) {
            UISegmentedControl *sg = tw26_findSeg(tv);
            if (sg) st.seg = sg;
        }
        ni.titleView = want;
    }
    tw26_ensureFilter(st);

    if (vc.isEditing) {
        [st.editBtn setTitle:kDoneText forState:UIControlStateNormal];
        if (ni.leftBarButtonItem == st.edit) [ni setLeftBarButtonItem:nil animated:NO];
        if (ni.rightBarButtonItem != st.edit) [ni setRightBarButtonItem:st.edit animated:NO];
    } else {
        [st.editBtn setTitle:kEditText forState:UIControlStateNormal];
        if (ni.rightBarButtonItem != st.filter) [ni setRightBarButtonItem:st.filter animated:NO];
        if (ni.leftBarButtonItem != st.edit) [ni setLeftBarButtonItem:st.edit animated:NO];
    }
    gApplying = was;

    tw26_ensureHeader(tw26_findTable(vc.view));
}

// Chuyển Hợp nhất <-> Cổ điển
static void tw26_applyMode(UIViewController *vc) {
    UIWindow *win = vc.view.window;
    UIView *snap = win ? [win snapshotViewAfterScreenUpdates:NO] : nil;   // ảnh chụp trước khi đổi -> làm mờ dần
    if (snap) { snap.userInteractionEnabled = NO; [win addSubview:snap]; }
    UITabBarController *tbc = vc.tabBarController;
    NSArray *all = tbc ? objc_getAssociatedObject(tbc, &kAllKey) : nil;
    if (tbc && all.count) {
        UIViewController *sel = tbc.selectedViewController;
        NSArray *target = tw26_filter(all);
        [tbc setViewControllers:target animated:NO];
        if (sel && [target containsObject:sel]) tbc.selectedViewController = sel;
        [tbc.tabBar setNeedsLayout];
        [tbc.view setNeedsLayout];
        [tbc.view layoutIfNeeded];
    }
    tw26_applyNav(vc);
    UITableView *tv = tw26_findTable(vc.view);
    tw26_ensureHeader(tv);
    [tv reloadData];
    if (snap) {
        [win layoutIfNeeded];
        [UIView animateWithDuration:0.5 delay:0.1 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            snap.alpha = 0;
            snap.transform = CGAffineTransformMakeScale(1.04, 1.04);
        } completion:^(BOOL f) { [snap removeFromSuperview]; }];
    }
}

// App gốc hay đặt lại nút "Edit" sau khi tweak đã đổi -> chặn lại, ghi nhớ nút gốc, áp dụng lại bố cục của tweak
static BOOL tw26_swallow(UINavigationItem *ni, NSArray *items, BOOL right) {
    if (gApplying) return NO;
    TW26State *st = objc_getAssociatedObject(ni, &kItemStateKey);
    UIViewController *vc = st.vc;
    if (!st || !vc) return NO;
    UIBarButtonItem *first = items.firstObject;
    if (first && (first == st.edit || first == st.filter)) return NO;
    if (!right && vc.isEditing) return NO;       // để nút "Xóa/Clear" của chế độ sửa đi qua
    if (first) st.native = first;
    tw26_applyNav(vc);
    return YES;
}

%hook UINavigationItem
- (void)setRightBarButtonItems:(NSArray *)items animated:(BOOL)a { if (tw26_swallow(self, items, YES)) return; %orig; }
- (void)setRightBarButtonItems:(NSArray *)items                  { if (tw26_swallow(self, items, YES)) return; %orig; }
- (void)setRightBarButtonItem:(UIBarButtonItem *)i animated:(BOOL)a { if (tw26_swallow(self, i ? @[i] : @[], YES)) return; %orig; }
- (void)setRightBarButtonItem:(UIBarButtonItem *)i                  { if (tw26_swallow(self, i ? @[i] : @[], YES)) return; %orig; }
- (void)setLeftBarButtonItems:(NSArray *)items animated:(BOOL)a  { if (tw26_swallow(self, items, NO)) return; %orig; }
- (void)setLeftBarButtonItems:(NSArray *)items                   { if (tw26_swallow(self, items, NO)) return; %orig; }
- (void)setLeftBarButtonItem:(UIBarButtonItem *)i animated:(BOOL)a { if (tw26_swallow(self, i ? @[i] : @[], NO)) return; %orig; }
- (void)setLeftBarButtonItem:(UIBarButtonItem *)i                  { if (tw26_swallow(self, i ? @[i] : @[], NO)) return; %orig; }
- (void)setTitleView:(UIView *)v {
    if (!gApplying) {
        TW26State *st = objc_getAssociatedObject(self, &kItemStateKey);
        if (st && st.vc && v != st.titleLabel && v != st.emptyTitle) {
            UISegmentedControl *sg = v ? tw26_findSeg(v) : nil;
            if (sg) st.seg = sg;
            tw26_applyNav(st.vc);
            return;
        }
    }
    %orig;
}
%end

// Tiêu đề "Liên hệ" cho danh bạ + nút quay lại chỉ còn dấu < (giống iOS 26)
static void tw26_applyGeneric(UIViewController *vc) {
    UINavigationController *nav = vc.navigationController;
    for (UIViewController *c in nav.viewControllers)
        if (c.navigationItem.backButtonDisplayMode != UINavigationItemBackButtonDisplayModeMinimal)
            c.navigationItem.backButtonDisplayMode = UINavigationItemBackButtonDisplayModeMinimal;
    if ([vc.parentViewController isKindOfClass:UINavigationController.class]) {
        const char *n = class_getName(object_getClass(vc));
        if ((strstr(n, "ContactList") || strstr(n, "PHContacts")) &&
            ![vc.navigationItem.title isEqualToString:kContactsTitle])
            vc.navigationItem.title = kContactsTitle;
    }
}

%hook UIViewController
- (void)viewWillAppear:(BOOL)animated { %orig; tw26_applyNav(self); tw26_applyGeneric(self); }
- (void)viewDidAppear:(BOOL)animated  { %orig; tw26_applyNav(self); }
- (void)setEditing:(BOOL)editing animated:(BOOL)animated { %orig; tw26_applyNav(self); }
%end

#pragma mark - Dòng cuộc gọi (avatar + giờ + nút gọi tròn)

static BOOL tw26_isRecentsCell(UITableViewCell *c) {
    NSString *n = NSStringFromClass(c.class);
    return [n rangeOfString:@"Recents" options:NSCaseInsensitiveSearch].location != NSNotFound ||
           [n rangeOfString:@"RecentCall" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static void tw26_setY(UIView *v, UIView *cell, CGFloat yCell, CGFloat h) {
    CGPoint p = [cell convertPoint:CGPointMake(0, yCell) toView:v.superview];
    CGRect f = v.frame; f.origin.y = p.y; f.size.height = h; v.frame = f;
}

static UIImageView *tw26_findIcon(UIView *v) {
    for (UIView *s in v.subviews) {
        if ([s isKindOfClass:UIImageView.class]) {
            UIImageView *iv = (UIImageView *)s;
            if (!iv.hidden && iv.image && iv.bounds.size.width <= 34 && iv.bounds.size.height <= 34) return iv;
        }
        UIImageView *r = tw26_findIcon(s);
        if (r) return r;
    }
    return nil;
}

static char kArrowKey;

static void tw26_prefixArrow(UILabel *sub, BOOL outgoing) {
    NSAttributedString *cur = sub.attributedText;
    if (cur.length == 0) return;
    NSString *want = outgoing ? @"up" : @"down";
    BOOL has = [cur.string hasPrefix:@"\uFFFC"];
    if (has && [objc_getAssociatedObject(sub, &kArrowKey) isEqualToString:want]) return;

    NSAttributedString *base = cur;
    if (has && cur.length > 2) base = [cur attributedSubstringFromRange:NSMakeRange(2, cur.length - 2)];

    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:sub.font.pointSize - 1 weight:UIImageSymbolWeightMedium];
    UIImage *img = [[UIImage systemImageNamed:(outgoing ? @"arrow.up.right" : @"arrow.down.left") withConfiguration:cfg]
                    imageWithTintColor:[UIColor systemGrayColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    NSTextAttachment *att = [NSTextAttachment new];
    att.image = img;
    att.bounds = CGRectMake(0, -1.5, img.size.width, img.size.height);
    NSMutableAttributedString *m = [[NSMutableAttributedString alloc]
                                    initWithAttributedString:[NSAttributedString attributedStringWithAttachment:att]];
    [m appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:@{NSFontAttributeName: sub.font}]];
    [m appendAttributedString:base];
    sub.attributedText = m;
    objc_setAssociatedObject(sub, &kArrowKey, want, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void tw26_cell(UITableViewCell *cell) {
    UITableView *tv = tw26_tableOf(cell);
    CGFloat W = cell.bounds.size.width, H = cell.bounds.size.height;
    if (W < 1 || H < 1) return;
    BOOL classic = tw26_classic();

    if (tv && !objc_getAssociatedObject(tv, &kRowKey)) {
        objc_setAssociatedObject(tv, &kRowKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        tv.rowHeight = kRowH;
        dispatch_async(dispatch_get_main_queue(), ^{ [tv beginUpdates]; [tv endUpdates]; });
    }
    tw26_ensureHeader(tv);

    if (cell.accessoryType != UITableViewCellAccessoryNone) cell.accessoryType = UITableViewCellAccessoryNone;
    if (cell.accessoryView) cell.accessoryView = nil;
    for (UIView *s in cell.contentView.subviews)
        if ([s isKindOfClass:UIButton.class] && s.tag != kCallTag) s.hidden = YES;

    UIView *av = [cell viewWithTag:kAvTag];
    UIButton *cb = (UIButton *)[cell viewWithTag:kCallTag];
    if (!av) {
        av = tw26_makeAvatar(kAvD);
        [cell addSubview:av];
    }
    if (!cb) {
        cb = [UIButton buttonWithType:UIButtonTypeCustom];
        cb.tag = kCallTag;
        cb.backgroundColor = [UIColor secondarySystemBackgroundColor];
        cb.layer.cornerRadius = kBtnD / 2.0;
        cb.tintColor = [UIColor systemBlueColor];
        [cb addTarget:cell action:@selector(tw26_callTapped) forControlEvents:UIControlEventTouchUpInside];
        [cell addSubview:cb];
    }

    BOOL editing = cell.isEditing || tv.isEditing;
    av.hidden = editing;
    cb.hidden = editing;
    if (editing) return;

    CGFloat left = kRowSide + kAvD + kAvGap, right = kRowSide + kBtnD + 4.0;
    av.frame = CGRectMake(kRowSide, (H - kAvD) / 2.0, kAvD, kAvD);
    cb.frame = CGRectMake(W - kRowSide - kBtnD, (H - kBtnD) / 2.0, kBtnD, kBtnD);
    [cell bringSubviewToFront:cb];
    cell.separatorInset = UIEdgeInsetsMake(0, left, 0, kRowSide);

    NSMutableArray *ls = [NSMutableArray array];
    tw26_collectLabels(cell.contentView, ls);
    UILabel *name = nil; CGRect nr = CGRectZero; BOOL video = NO;
    for (UILabel *l in ls) {
        if (l.hidden || l.text.length == 0) continue;
        if ([l.text rangeOfString:@"video" options:NSCaseInsensitiveSearch].location != NSNotFound) video = YES;
        CGRect r = [l convertRect:l.bounds toView:cell];
        if (!name || r.origin.x < nr.origin.x - 3 || (fabs(r.origin.x - nr.origin.x) <= 3 && r.origin.y < nr.origin.y)) {
            name = l; nr = r;
        }
    }

    CGFloat off = name ? [name convertRect:name.bounds toView:cell.contentView].origin.x : 47.0;
    CGFloat cx = left - off;
    CGRect cf = CGRectMake(cx, 0, W - cx - right, H);
    if (!CGRectEqualToRect(cell.contentView.frame, cf)) {
        cell.contentView.frame = cf;
        [cell.contentView layoutIfNeeded];
    }

    UILabel *sub = nil, *timeL = nil; CGRect sr = CGRectZero;
    NSMutableArray<UILabel *> *sameRow = [NSMutableArray array];
    for (UILabel *l in ls) {
        if (l.hidden || l.text.length == 0 || l == name) continue;
        CGRect r = [l convertRect:l.bounds toView:cell];
        if (CGRectGetMidX(r) > W * 0.5) { if (!timeL) timeL = l; }
        else if (name && fabs(CGRectGetMidY(r) - CGRectGetMidY(nr)) < nr.size.height * 0.5 && r.origin.x > nr.origin.x) {
            [sameRow addObject:l];
        }
        else if (!sub || r.origin.y < sr.origin.y) { sub = l; sr = r; }
    }
    UIFont *nf = [UIFont systemFontOfSize:kNameSize weight:UIFontWeightSemibold];
    UIFont *sf = [UIFont systemFontOfSize:kSubSize weight:UIFontWeightRegular];
    UIFont *tf = [UIFont systemFontOfSize:kTimeSize weight:UIFontWeightRegular];
    if (name && ![name.font isEqual:nf]) name.font = nf;
    if (sub && ![sub.font isEqual:sf]) sub.font = sf;
    if (timeL && ![timeL.font isEqual:tf]) timeL.font = tf;

    CGFloat nh = ceil(nf.lineHeight), sh = ceil(sf.lineHeight), th = ceil(tf.lineHeight), gap = kTextGap;
    CGFloat total = nh + (sub ? gap + sh : 0);
    CGFloat y0 = (H - total) / 2.0;
    if (name) tw26_setY(name, cell, y0, nh);
    for (UILabel *l in sameRow) {
        UIFont *cf2 = [UIFont systemFontOfSize:kNameSize weight:UIFontWeightRegular];
        if (![l.font isEqual:cf2]) l.font = cf2;
        tw26_setY(l, cell, y0, nh);
    }
    if (sub)  tw26_setY(sub, cell, y0 + nh + gap, sh);
    if (timeL) tw26_setY(timeL, cell, (H - th) / 2.0, th);

    UIImageView *icon = tw26_findIcon(cell.contentView);
    BOOL outgoing = (icon != nil);
    if (icon) icon.alpha = 0;
    if (sub) tw26_prefixArrow(sub, outgoing);

    if (name) tw26_setAvatar(av, name.text, 1);

    // nút bên phải: Hợp nhất = gọi / video ; Cổ điển = (i) thông tin liên hệ
    NSString *kind = classic ? @"info" : (video ? @"video" : @"phone");
    if (![cb.accessibilityIdentifier isEqualToString:kind]) {
        cb.accessibilityIdentifier = kind;
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:(classic ? 25 : 21)
                                                            weight:(classic ? UIImageSymbolWeightRegular : UIImageSymbolWeightMedium)];
        NSString *sym = classic ? @"info.circle" : (video ? @"video.fill" : @"phone.fill");
        [cb setImage:[UIImage systemImageNamed:sym withConfiguration:cfg] forState:UIControlStateNormal];
    }
}

#pragma mark - Danh bạ (avatar trước tên) & chi tiết liên hệ

static BOOL tw26_hasNativeAvatar(UIView *v) {
    for (UIView *s2 in v.subviews) {
        if (strstr(class_getName(object_getClass(s2)), "Avatar")) return YES;
        if ([s2 isKindOfClass:UIImageView.class] && !s2.hidden && s2.bounds.size.width >= 36) return YES;
        if (tw26_hasNativeAvatar(s2)) return YES;
    }
    return NO;
}

static void tw26_contactCell(UITableViewCell *cell) {
    CGFloat W = cell.bounds.size.width, H = cell.bounds.size.height;
    if (W < 1 || H < 1) return;
    UIView *av = [cell viewWithTag:kAvTag];
    if (tw26_hasNativeAvatar(cell.contentView)) { av.hidden = YES; return; }   // dòng đã có avatar gốc (Thẻ của tôi)
    NSMutableArray *ls = [NSMutableArray array];
    tw26_collectLabels(cell.contentView, ls);
    UILabel *name = nil; CGRect nr = CGRectZero;
    for (UILabel *l in ls) {
        if (l.hidden || l.text.length == 0) continue;
        CGRect r = [l convertRect:l.bounds toView:cell];
        if (!name || r.origin.x < nr.origin.x - 3 || (fabs(r.origin.x - nr.origin.x) <= 3 && r.origin.y < nr.origin.y)) {
            name = l; nr = r;
        }
    }
    if (!name) { av.hidden = YES; return; }
    const CGFloat d = 40, avL = 18, gap = 10;
    if (!av) { av = tw26_makeAvatar(d); [cell addSubview:av]; }
    av.hidden = NO;
    av.frame = CGRectMake(avL, (H - d) / 2.0, d, d);
    CGFloat off = [name convertRect:name.bounds toView:cell.contentView].origin.x;
    CGFloat cx = avL + d + gap - off;
    CGRect cf = CGRectMake(cx, 0, W - cx, H);
    if (!CGRectEqualToRect(cell.contentView.frame, cf)) {
        cell.contentView.frame = cf;
        [cell.contentView layoutIfNeeded];
    }
    UIEdgeInsets si = UIEdgeInsetsMake(0, avL + d + gap, 0, 0);
    if (!UIEdgeInsetsEqualToEdgeInsets(cell.separatorInset, si)) cell.separatorInset = si;
    tw26_setAvatar(av, name.text, 2);
}

// ---- chi tiết liên hệ: mọi thao tác đều có kiểm tra "đã đúng thì thôi" để không gây vòng lặp layout (treo máy)
static UIColor *tw26_detailBg(void) {
    static UIColor *c; static dispatch_once_t o;
    dispatch_once(&o, ^{ c = tw26_dyn([UIColor colorWithRed:0.58 green:0.60 blue:0.66 alpha:1],
                                      [UIColor colorWithRed:0.20 green:0.21 blue:0.25 alpha:1]); });
    return c;
}
static UIColor *tw26_detailCard(void) {
    static UIColor *c; static dispatch_once_t o;
    dispatch_once(&o, ^{ c = tw26_dyn([UIColor colorWithWhite:0 alpha:0.13], [UIColor colorWithWhite:1 alpha:0.08]); });
    return c;
}
static UIColor *tw26_detailSep(void) {
    static UIColor *c; static dispatch_once_t o;
    dispatch_once(&o, ^{ c = [UIColor colorWithWhite:1 alpha:0.25]; });
    return c;
}
static UIColor *tw26_txtBig(void) {
    static UIColor *c; static dispatch_once_t o;
    dispatch_once(&o, ^{ c = [UIColor colorWithWhite:1 alpha:0.96]; });
    return c;
}
static UIColor *tw26_txtSmall(void) {
    static UIColor *c; static dispatch_once_t o;
    dispatch_once(&o, ^{ c = [UIColor colorWithWhite:1 alpha:0.72]; });
    return c;
}
static UIColor *tw26_pillBg(void) {
    static UIColor *c; static dispatch_once_t o;
    dispatch_once(&o, ^{ c = [UIColor colorWithWhite:0 alpha:0.12]; });
    return c;
}

static void tw26_setBg(UIView *v, UIColor *c) {
    if (v && ![v.backgroundColor isEqual:c]) v.backgroundColor = c;
}
static void tw26_setTxt(UILabel *l, UIColor *c) {
    if (![l.textColor isEqual:c]) l.textColor = c;
}

static BOOL tw26_isDetailVC(UIViewController *vc) {
    if (!vc) return NO;
    const char *n = class_getName(object_getClass(vc));
    return strstr(n, "CNContact") && !strstr(n, "List") && !strstr(n, "Picker") && !strstr(n, "Group");
}

static char kSegKey, kThrottleKey, kPendingKey;

static void tw26_collectControls(UIView *v, NSMutableArray *out) {
    for (UIView *s2 in v.subviews) {
        if ([s2 isKindOfClass:UIControl.class] && ![s2 isKindOfClass:UISegmentedControl.class]) [out addObject:s2];
        else tw26_collectControls(s2, out);
    }
}

// Nút hành động (nhắn tin / gọi / video / mail) -> viên tròn mờ, chỉ còn icon
static void tw26_styleDetailHeader(UITableView *tv) {
    UIView *h = tv.tableHeaderView;
    if (!h) return;
    NSMutableArray *hl = [NSMutableArray array];
    tw26_collectLabels(h, hl);
    NSMutableArray *cs = [NSMutableArray array];
    tw26_collectControls(h, cs);
    for (UIControl *c in cs) {
        CGSize z = c.bounds.size;
        if (z.width < 50 || z.width > 140 || z.height < 40 || z.height > 100) continue;
        const char *cn = class_getName(object_getClass(c));
        if (!strcasestr(cn, "Action") && !strcasestr(cn, "Button")) continue;
        tw26_setBg(c, tw26_pillBg());
        if (fabs(c.layer.cornerRadius - z.height / 2.0) > 0.5) c.layer.cornerRadius = z.height / 2.0;
        if (!c.clipsToBounds) c.clipsToBounds = YES;
        NSMutableArray *ls = [NSMutableArray array];
        tw26_collectLabels(c, ls);
        for (UILabel *l in ls) { if (!l.hidden) l.hidden = YES; [hl removeObject:l]; }
    }
    for (UILabel *l in hl) tw26_setTxt(l, [UIColor whiteColor]);
}

static void tw26_styleDetailTable(UITableView *tv) {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    NSNumber *last = objc_getAssociatedObject(tv, &kThrottleKey);
    if (last && now - last.doubleValue < 0.3) {
        if (![objc_getAssociatedObject(tv, &kPendingKey) boolValue]) {     // đảm bảo có một lần áp dụng cuối
            objc_setAssociatedObject(tv, &kPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            __weak UITableView *wtv = tv;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UITableView *t2 = wtv;
                if (!t2) return;
                objc_setAssociatedObject(t2, &kPendingKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                tw26_styleDetailTable(t2);
            });
        }
        return;
    }
    objc_setAssociatedObject(tv, &kThrottleKey, @(now), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    tw26_setBg(tv, tw26_detailBg());
    if (tv.superview) tw26_setBg(tv.superview, tw26_detailBg());
    if (![tv.separatorColor isEqual:tw26_detailSep()]) tv.separatorColor = tw26_detailSep();
    tw26_styleDetailHeader(tv);
}

static void tw26_detailCell(UITableViewCell *cell, UITableView *tv) {
    tw26_setBg(cell, tw26_detailCard());
    if (![cell.tintColor isEqual:[UIColor whiteColor]]) cell.tintColor = [UIColor whiteColor];
    NSMutableArray *ls = [NSMutableArray array];
    tw26_collectLabels(cell.contentView, ls);
    for (UILabel *l in ls) tw26_setTxt(l, l.font.pointSize >= 16.5 ? tw26_txtBig() : tw26_txtSmall());
    tw26_styleDetailTable(tv);
}

// Phân loại bảng theo màn hình chứa nó: 1 = chi tiết liên hệ, 3 = danh sách danh bạ, 2 = khác
static void tw26_otherCell(UITableViewCell *cell) {
    UITableView *tv = tw26_tableOf(cell);
    if (!tv) return;
    NSNumber *k = objc_getAssociatedObject(tv, &kDetailKey);
    if (!k) {
        UIViewController *vc = tw26_vcOf(tv);
        if (!vc) return;                       // chưa gắn vào màn hình -> thử lại lần sau
        const char *n = class_getName(object_getClass(vc));
        int kind = 2;
        if (tw26_isDetailVC(vc)) kind = 1;
        else if (strstr(n, "Contact") && !strstr(n, "Picker") && !strstr(n, "Group")) kind = 3;
        k = @(kind);
        objc_setAssociatedObject(tv, &kDetailKey, k, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (k.integerValue == 1) tw26_detailCell(cell, tv);
    else if (k.integerValue == 3) tw26_contactCell(cell);
}

%hook UISegmentedControl
- (void)layoutSubviews {
    %orig;
    if (!tw26_isDetailVC(tw26_vcOf(self))) return;
    if (![objc_getAssociatedObject(self, &kSegKey) boolValue]) {
        objc_setAssociatedObject(self, &kSegKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSDictionary *a = @{NSForegroundColorAttributeName: [UIColor whiteColor],
                            NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]};
        [self setTitleTextAttributes:a forState:UIControlStateNormal];
        [self setTitleTextAttributes:a forState:UIControlStateSelected];
        self.selectedSegmentTintColor = [UIColor colorWithWhite:1 alpha:0.35];
    }
    tw26_setBg(self, tw26_pillBg());
}
%end

%hook UITableViewCell
- (void)layoutSubviews {
    %orig;
    if (tw26_isRecentsCell(self)) tw26_cell(self);
    else tw26_otherCell(self);
}

%new
- (void)tw26_callTapped {
    UITableView *tv = tw26_tableOf(self);
    NSIndexPath *ip = [tv indexPathForCell:self];
    if (!tv || !ip) return;
    id<UITableViewDelegate> d = tv.delegate;
    if (!tw26_classic()) {
        if ([d respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
            [d tableView:tv didSelectRowAtIndexPath:ip];
        return;
    }
    if ([d respondsToSelector:@selector(tableView:accessoryButtonTappedForRowWithIndexPath:)]) {
        [d tableView:tv accessoryButtonTappedForRowWithIndexPath:ip];
        return;
    }
    for (UIView *s in self.contentView.subviews) {
        if ([s isKindOfClass:UIButton.class] && s.tag != kCallTag && [(UIButton *)s allTargets].count) {
            [(UIButton *)s sendActionsForControlEvents:UIControlEventTouchUpInside];
            return;
        }
    }
}
%end

#pragma mark - Bàn phím số kiểu iOS 26 (nút tròn trắng + bóng mềm)

static int tw26_kind(Class c) {
    static CFMutableDictionaryRef cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = CFDictionaryCreateMutable(NULL, 0, NULL, NULL); });
    const void *v = CFDictionaryGetValue(cache, (__bridge const void *)c);
    if (v) return (int)((intptr_t)v) - 1;
    const char *n = class_getName(c);
    int k = (strstr(n, "NumberPad") && strstr(n, "Button")) ? 1 : 0;
    CFDictionarySetValue(cache, (__bridge const void *)c, (const void *)(intptr_t)(k + 1));
    return k;
}

static const BOOL kStyleKeypad = YES;      // NO = trả bàn phím về mặc định của iPhone
static const CGFloat kKeyD = 78.0;           // đường kính vòng tròn phím
static const NSInteger kKeyCircleTag = 26040;

static UIColor *tw26_keyFill(BOOL pressed) {
    static UIColor *n, *p; static dispatch_once_t o;
    dispatch_once(&o, ^{
        n = tw26_dyn([UIColor colorWithWhite:0.985 alpha:1], [UIColor colorWithWhite:0.17 alpha:1]);
        p = tw26_dyn([UIColor colorWithWhite:0.86 alpha:1], [UIColor colorWithWhite:0.32 alpha:1]);
    });
    return pressed ? p : n;
}

static void tw26_styleKeypadButton(UIView *b) {
    if (!kStyleKeypad) return;
    CGSize z = b.bounds.size;
    CGFloat m = MIN(z.width, z.height);
    if (m < 40) return;
    CGFloat d = MIN(kKeyD, m);

    UIView *c = [b viewWithTag:kKeyCircleTag];
    if (!c) {
        c = [UIView new];
        c.tag = kKeyCircleTag;
        c.userInteractionEnabled = NO;
        c.layer.shadowColor = [UIColor blackColor].CGColor;
        c.layer.shadowOpacity = 0.10;
        c.layer.shadowRadius = 14;
        c.layer.shadowOffset = CGSizeMake(0, 6);
        [b insertSubview:c atIndex:0];
    }
    CGRect cf = CGRectMake((z.width - d) / 2.0, (z.height - d) / 2.0, d, d);
    if (!CGRectEqualToRect(c.frame, cf)) {
        c.frame = cf;
        c.layer.cornerRadius = d / 2.0;
        c.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:c.bounds].CGPath;
    }
    BOOL pressed = [b isKindOfClass:UIControl.class] && ((UIControl *)b).isHighlighted;
    UIColor *f = tw26_keyFill(pressed);
    if (![c.backgroundColor isEqual:f]) c.backgroundColor = f;

    // ẩn vòng tròn xám gốc (view hoặc layer lớn), giữ lại số và chữ
    if (b.backgroundColor && ![b.backgroundColor isEqual:[UIColor clearColor]]) b.backgroundColor = [UIColor clearColor];
    for (UIView *s2 in b.subviews) {
        if (s2 == c || [s2 isKindOfClass:UILabel.class]) continue;
        if (s2.bounds.size.width >= 55 && !s2.hidden) s2.hidden = YES;
    }
    for (CALayer *l in b.layer.sublayers) {
        if (l == c.layer) continue;
        if (l.bounds.size.width >= 55 && !l.hidden) l.hidden = YES;
    }
}

%hook UIView
- (void)layoutSubviews {
    %orig;
    if (tw26_kind(object_getClass(self)) == 1) tw26_styleKeypadButton(self);
}
%end

%hook UIControl
- (void)setHighlighted:(BOOL)h {
    %orig;
    if (kStyleKeypad && tw26_kind(object_getClass(self)) == 1) {
        UIView *c = [self viewWithTag:kKeyCircleTag];
        if (c) c.backgroundColor = tw26_keyFill(h);
    }
}
%end

#pragma mark - Ô tìm kiếm bo tròn có bóng (Danh bạ...)

static void tw26_hideSearchBg(UIView *v) {
    for (UIView *s2 in v.subviews) {
        const char *n = class_getName(object_getClass(s2));
        if (strstr(n, "SearchFieldBackground") || strstr(n, "SearchBarBackground")) {
            if (s2.alpha != 0) s2.alpha = 0;
        } else {
            tw26_hideSearchBg(s2);
        }
    }
}

%hook UISearchBar
- (void)layoutSubviews {
    %orig;
    UITextField *tf = self.searchTextField;
    if (!tf || tf.bounds.size.height < 20) return;
    if (self.searchBarStyle != UISearchBarStyleMinimal) self.searchBarStyle = UISearchBarStyleMinimal;
    tw26_hideSearchBg(self);
    CGFloat h = tf.bounds.size.height;
    UIColor *bg = tw26_dyn([UIColor whiteColor], [UIColor colorWithWhite:0.17 alpha:1]);
    tw26_setBg(tf, bg);
    tf.layer.cornerRadius = h / 2.0;
    tf.layer.masksToBounds = NO;
    tf.layer.shadowColor = [UIColor blackColor].CGColor;
    tf.layer.shadowOpacity = 0.08;
    tf.layer.shadowRadius = 12;
    tf.layer.shadowOffset = CGSizeMake(0, 4);
    tf.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:tf.bounds cornerRadius:h / 2.0].CGPath;
}
%end

#pragma mark - Nút thanh tiêu đề dạng viên thuốc (Sửa, +, <) cho các màn hình khác

static UIImage *tw26_drawPill(UIColor *fill, UIColor *stroke) {
    CGSize sz = CGSizeMake(60, 40);
    UIGraphicsImageRenderer *rd = [[UIGraphicsImageRenderer alloc] initWithSize:sz];
    return [rd imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.5, 0.5, 59, 39) cornerRadius:19.5];
        [fill setFill];
        [p fill];
        p.lineWidth = 0.8;
        [stroke setStroke];
        [p stroke];
    }];
}

static UIImage *tw26_pillImage(void) {
    UIImage *l = tw26_drawPill([UIColor colorWithWhite:1 alpha:0.92], [UIColor colorWithWhite:0 alpha:0.08]);
    UIImage *d = tw26_drawPill([UIColor colorWithWhite:0.22 alpha:0.92], [UIColor colorWithWhite:1 alpha:0.12]);
    [l.imageAsset registerImage:d withTraitCollection:
     [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark]];
    UIImage *rs = [l resizableImageWithCapInsets:UIEdgeInsetsMake(20, 20, 20, 20) resizingMode:UIImageResizingModeStretch];
    return [rs imageWithAlignmentRectInsets:UIEdgeInsetsMake(-8, -12, -8, -12)];
}

static const BOOL kPillBarButtons = NO;   // YES = bo viên thuốc các nút thanh tiêu đề gốc (có thể bị viền đôi)

%ctor {
    %init;
    tw26_dumpInstall();
    if (kPillBarButtons) @autoreleasepool {
        UIImage *img = tw26_pillImage();
        UIBarButtonItem *a = [UIBarButtonItem appearance];
        [a setBackgroundImage:img forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [a setBackButtonBackgroundImage:img forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    }
}
