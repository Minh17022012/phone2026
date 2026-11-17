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

static void tw26_style(UITabBar *bar, BOOL animated) {
    CGRect bounds = bar.bounds;
    if (bounds.size.width < 1) return;

    UIVisualEffectView *ev = (UIVisualEffectView *)[bar viewWithTag:kEffectTag];
    if (!ev) {
        UITabBarAppearance *ap = [UITabBarAppearance new];
        [ap configureWithTransparentBackground];
        tw26_applyItemColors(ap.stackedLayoutAppearance);
        tw26_applyItemColors(ap.inlineLayoutAppearance);
        tw26_applyItemColors(ap.compactInlineLayoutAppearance);
        bar.standardAppearance = ap;
        bar.scrollEdgeAppearance = ap;

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
            dismiss();
            UIViewController *v = wvc;
            if (v && isClassicOpt != tw26_classic()) {
                [[NSUserDefaults standardUserDefaults] setInteger:(isClassicOpt ? 1 : 0) forKey:kLayoutKey];
                tw26_applyMode(v);
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
    UITabBarController *tbc = vc.tabBarController;
    NSArray *all = tbc ? objc_getAssociatedObject(tbc, &kAllKey) : nil;
    if (tbc && all.count) {
        UIViewController *sel = tbc.selectedViewController;
        NSArray *target = tw26_filter(all);
        [tbc setViewControllers:target animated:NO];
        if (sel && [target containsObject:sel]) tbc.selectedViewController = sel;
        [tbc.tabBar setNeedsLayout];
        [tbc.view setNeedsLayout];
    }
    tw26_applyNav(vc);
    UITableView *tv = tw26_findTable(vc.view);
    tw26_ensureHeader(tv);
    [tv reloadData];
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

static BOOL tw26_isContactListCell(UITableViewCell *c) {
    const char *n = class_getName(object_getClass(c));
    return strstr(n, "Contact") && strstr(n, "Cell") && !strstr(n, "Property") && !strstr(n, "Action") &&
           !strstr(n, "Group") && !strstr(n, "Header") && !strstr(n, "Recents");
}

static void tw26_contactCell(UITableViewCell *cell) {
    CGFloat W = cell.bounds.size.width, H = cell.bounds.size.height;
    if (W < 1 || H < 1) return;
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
    UIView *av = [cell viewWithTag:kAvTag];
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
    cell.separatorInset = UIEdgeInsetsMake(0, avL + d + gap, 0, 0);
    tw26_setAvatar(av, name.text, 2);
}

static UIColor *tw26_detailBg(void) {
    return tw26_dyn([UIColor colorWithRed:0.58 green:0.60 blue:0.66 alpha:1],
                    [UIColor colorWithRed:0.20 green:0.21 blue:0.25 alpha:1]);
}
static UIColor *tw26_detailCard(void) {
    return tw26_dyn([UIColor colorWithWhite:0 alpha:0.13], [UIColor colorWithWhite:1 alpha:0.08]);
}

static BOOL tw26_isDetailVC(UIViewController *vc) {
    if (!vc) return NO;
    const char *n = class_getName(object_getClass(vc));
    return strstr(n, "CNContact") && !strstr(n, "List") && !strstr(n, "Picker") && !strstr(n, "Group");
}

static char kSegKey;

static void tw26_collectControls(UIView *v, NSMutableArray *out) {
    for (UIView *s in v.subviews) {
        if ([s isKindOfClass:UIControl.class] && ![s isKindOfClass:UISegmentedControl.class]) [out addObject:s];
        else tw26_collectControls(s, out);
    }
}

// Nút hành động (nhắn tin / gọi / video / mail) -> dạng viên tròn mờ, chỉ còn icon
static void tw26_styleDetailHeader(UITableView *tv) {
    UIView *h = tv.tableHeaderView;
    if (!h) return;
    NSMutableArray *cs = [NSMutableArray array];
    tw26_collectControls(h, cs);
    for (UIControl *c in cs) {
        CGSize z = c.bounds.size;
        if (z.width < 50 || z.width > 140 || z.height < 40 || z.height > 100) continue;
        const char *cn = class_getName(object_getClass(c));
        if (!strcasestr(cn, "Action") && !strcasestr(cn, "Button")) continue;
        c.backgroundColor = [UIColor colorWithWhite:0 alpha:0.12];
        c.layer.cornerRadius = z.height / 2.0;
        c.clipsToBounds = YES;
        c.tintColor = [UIColor whiteColor];
        NSMutableArray *ls = [NSMutableArray array];
        tw26_collectLabels(c, ls);
        for (UILabel *l in ls) l.hidden = YES;
    }
}

static void tw26_detailCell(UITableViewCell *cell) {
    UITableView *tv = tw26_tableOf(cell);
    if (!tv) return;
    NSNumber *k = objc_getAssociatedObject(tv, &kDetailKey);
    if (!k) {
        k = @(tw26_isDetailVC(tw26_vcOf(tv)) ? 1 : 2);
        objc_setAssociatedObject(tv, &kDetailKey, k, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (k.integerValue != 1) return;
    tv.backgroundColor = tw26_detailBg();
    tv.superview.backgroundColor = tw26_detailBg();
    tv.separatorColor = [UIColor colorWithWhite:1 alpha:0.25];
    cell.backgroundColor = tw26_detailCard();
    cell.tintColor = [UIColor whiteColor];
    NSMutableArray *ls = [NSMutableArray array];
    tw26_collectLabels(cell.contentView, ls);
    for (UILabel *l in ls) {
        BOOL big = l.font.pointSize >= 16.5;
        l.textColor = [UIColor colorWithWhite:1 alpha:(big ? 0.96 : 0.72)];
    }
    if (tv.tableHeaderView) {
        NSMutableArray *hl = [NSMutableArray array];
        tw26_collectLabels(tv.tableHeaderView, hl);
        for (UILabel *l in hl) l.textColor = [UIColor whiteColor];
    }
    tw26_styleDetailHeader(tv);
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
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.10];
}
%end

%hook UITableViewCell
- (void)layoutSubviews {
    %orig;
    if (tw26_isRecentsCell(self)) tw26_cell(self);
    else if (tw26_isContactListCell(self)) tw26_contactCell(self);
    else tw26_detailCell(self);
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

static const BOOL kHideKeypadBg = YES;   // NO nếu sau khi cài số trên phím biến mất

static void tw26_styleKeypadButton(UIView *b) {
    CGSize z = b.bounds.size;
    CGFloat d = MIN(z.width, z.height);
    if (d < 40) return;
    b.backgroundColor = tw26_dyn([UIColor colorWithWhite:0.985 alpha:1], [UIColor colorWithWhite:0.17 alpha:1]);
    b.layer.cornerRadius = d / 2.0;
    b.layer.masksToBounds = NO;
    b.layer.shadowColor = [UIColor blackColor].CGColor;
    b.layer.shadowOpacity = 0.10;
    b.layer.shadowRadius = 14;
    b.layer.shadowOffset = CGSizeMake(0, 6);
    b.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:
                          CGRectMake((z.width - d) / 2.0, (z.height - d) / 2.0, d, d)].CGPath;
    if (!kHideKeypadBg) return;
    for (UIView *s in b.subviews) {
        if ([s isKindOfClass:UILabel.class]) continue;
        if (s.bounds.size.width >= d * 0.85 && s.bounds.size.height >= d * 0.85) s.hidden = YES;
    }
}

%hook UIView
- (void)layoutSubviews {
    %orig;
    if (tw26_kind(object_getClass(self)) == 1) tw26_styleKeypadButton(self);
}
%end

#pragma mark - Ô tìm kiếm bo tròn có bóng (Danh bạ...)

%hook UISearchBar
- (void)layoutSubviews {
    %orig;
    UITextField *tf = self.searchTextField;
    if (!tf || tf.bounds.size.height < 20) return;
    if (self.searchBarStyle != UISearchBarStyleMinimal) self.searchBarStyle = UISearchBarStyleMinimal;
    CGFloat h = tf.bounds.size.height;
    tf.backgroundColor = tw26_dyn([UIColor whiteColor], [UIColor colorWithWhite:0.17 alpha:1]);
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

%ctor {
    %init;
    tw26_dumpInstall();
    @autoreleasepool {
        UIImage *img = tw26_pillImage();
        UIBarButtonItem *a = [UIBarButtonItem appearance];
        [a setBackgroundImage:img forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [a setBackButtonBackgroundImage:img forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    }
}
