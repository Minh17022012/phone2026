// Phone26 v2 - Giao diện app Điện thoại kiểu iOS 26 (MobilePhone)
//  - Tab bar nổi: 3 tab + nút tìm kiếm tròn tách rời cùng hàng
//  - Mỗi dòng cuộc gọi: avatar tròn gradient + tên đậm + giờ + nút gọi/video tròn xám bên phải
//  - Nút "Sửa" / "lọc" trên thanh tiêu đề thành viên thuốc kính mờ, tiêu đề nhỏ ở giữa
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
static const BOOL kStyleNavButtons = NO;   // YES: bo tròn các nút nav gốc ở màn hình khác

static const CGFloat kBarH = 64.0, kSide = 18.0, kGap = 10.0;   // tab bar
static const CGFloat kRowH = 80.0, kAvD = 50.0, kBtnD = 54.0, kRowSide = 16.0;
static const CGFloat kAvGap = 10.0;   // khoảng cách avatar -> tên (nhỏ hơn = gần hơn) // dòng cuộc gọi
static const NSInteger kSearchTag = 26001, kEffectTag = 26002, kCapsuleTag = 26003;
static const NSInteger kAvTag = 26010, kAvLetterTag = 26011, kAvIconTag = 26012, kCallTag = 26013, kNavTag = 26020;
static char kRowKey;

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

static NSArray *tw26_filter(NSArray *vcs) {
    if (vcs.count <= 3) return vcs;
    NSMutableArray *out = [NSMutableArray array];
    for (UIViewController *vc in vcs) {
        NSString *n = tw26_name(vc);
        if ([n containsString:@"favorite"] || [n containsString:@"voicemail"]) continue;
        [out addObject:vc];
    }
    return out.count == 3 ? out : vcs;
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

#pragma mark - Tab bar

static CGRect tw26_barFrame(UITabBar *bar, CGRect orig) {
    UIView *sv = bar.superview;
    if (!sv || sv.bounds.size.width < 1) return orig;
    CGRect b = sv.bounds;
    CGFloat margin = sv.safeAreaInsets.bottom > 0 ? 18.0 : 12.0;
    CGFloat w = b.size.width - 2 * kSide - kGap - kBarH;
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
- (void)setViewControllers:(NSArray *)vcs animated:(BOOL)animated { %orig(tw26_filter(vcs), animated); }
- (void)setViewControllers:(NSArray *)vcs { %orig(tw26_filter(vcs)); }

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


#pragma mark - Thanh tiêu đề màn hình Cuộc gọi: "Sửa" bên trái, tiêu đề giữa, nút lọc bên phải

@interface TW26State : NSObject
@property (nonatomic, strong) UIBarButtonItem *native, *edit, *filter;
@property (nonatomic, strong) UIButton *editBtn;
@property (nonatomic, strong) UISegmentedControl *seg;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, weak) UIViewController *vc;
@end
@implementation TW26State
@end

static char kStateKey, kItemStateKey;
static BOOL gApplying = NO;   // YES khi chính tweak đang đổi nút -> không chặn

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

static UIMenu *tw26_menu(TW26State *st, UIButton *btn) {
    __weak TW26State *ws = st;
    __weak UIButton *wb = btn;
    NSArray *titles = @[kAllText, kMissedText];
    NSMutableArray *acts = [NSMutableArray array];
    for (NSInteger i = 0; i < 2; i++) {
        UIAction *a = [UIAction actionWithTitle:titles[i] image:nil identifier:nil handler:^(UIAction *x) {
            TW26State *s2 = ws; UIButton *b2 = wb;
            if (!s2 || !s2.seg) return;
            if (s2.seg.numberOfSegments > i) {
                s2.seg.selectedSegmentIndex = i;
                [s2.seg sendActionsForControlEvents:UIControlEventValueChanged];
            }
            if (b2) b2.menu = tw26_menu(s2, b2);
        }];
        a.state = (st.seg.selectedSegmentIndex == i) ? UIMenuElementStateOn : UIMenuElementStateOff;
        [acts addObject:a];
    }
    return [UIMenu menuWithChildren:acts];
}

static void tw26_ensureFilter(TW26State *st) {
    if (st.filter || !st.seg) return;
    UIButton *fb = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    [fb setImage:[UIImage systemImageNamed:@"line.3.horizontal.decrease" withConfiguration:cfg]
        forState:UIControlStateNormal];
    fb.tintColor = [UIColor labelColor];
    fb.showsMenuAsPrimaryAction = YES;
    fb.menu = tw26_menu(st, fb);
    st.filter = [[UIBarButtonItem alloc] initWithCustomView:tw26_capsule(40, 40, fb)];
}

static void tw26_applyNav(UIViewController *vc) {
    if (![vc.parentViewController isKindOfClass:UINavigationController.class]) return;
    if ([NSStringFromClass(vc.class) rangeOfString:@"Recents" options:NSCaseInsensitiveSearch].location == NSNotFound) return;
    UINavigationItem *ni = vc.navigationItem;
    TW26State *st = objc_getAssociatedObject(vc, &kStateKey);

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

    // tiêu đề: luôn là "Cuộc gọi"; nhớ lại thanh All/Missed gốc để điều khiển bằng menu
    if (ni.titleView != st.titleLabel) {
        UIView *tv = ni.titleView;
        UISegmentedControl *sg = tv ? tw26_findSeg(tv) : nil;
        if (sg) st.seg = sg;
        ni.titleView = st.titleLabel;
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
}

// App gốc hay đặt lại nút "Edit" ở bên phải sau khi tweak đã đổi -> chặn lại, ghi nhớ nút gốc, áp dụng lại bố cục của tweak
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
        if (st && st.vc && v != st.titleLabel) {
            UISegmentedControl *sg = v ? tw26_findSeg(v) : nil;
            if (sg) { st.seg = sg; tw26_ensureFilter(st); }
            tw26_applyNav(st.vc);
            return;
        }
    }
    %orig;
}
%end

%hook UIViewController
- (void)viewWillAppear:(BOOL)animated { %orig; tw26_applyNav(self); }
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

    if (tv && !objc_getAssociatedObject(tv, &kRowKey)) {
        objc_setAssociatedObject(tv, &kRowKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        tv.rowHeight = kRowH;
        dispatch_async(dispatch_get_main_queue(), ^{ [tv beginUpdates]; [tv endUpdates]; });
    }

    if (cell.accessoryType != UITableViewCellAccessoryNone) cell.accessoryType = UITableViewCellAccessoryNone;
    if (cell.accessoryView) cell.accessoryView = nil;
    for (UIView *s in cell.contentView.subviews)
        if ([s isKindOfClass:UIButton.class] && s.tag != kCallTag) s.hidden = YES;

    UIView *av = [cell viewWithTag:kAvTag];
    UIButton *cb = (UIButton *)[cell viewWithTag:kCallTag];

    if (!av) {
        av = [UIView new];
        av.tag = kAvTag;
        av.userInteractionEnabled = NO;
        av.clipsToBounds = YES;
        av.layer.cornerRadius = kAvD / 2.0;
        CAGradientLayer *g = [CAGradientLayer layer];
        g.frame = CGRectMake(0, 0, kAvD, kAvD);
        g.colors = @[(id)[UIColor colorWithRed:0.68 green:0.76 blue:0.89 alpha:1].CGColor,
                     (id)[UIColor colorWithRed:0.43 green:0.49 blue:0.72 alpha:1].CGColor];
        [av.layer addSublayer:g];
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kAvD, kAvD)];
        l.tag = kAvLetterTag;
        l.textAlignment = NSTextAlignmentCenter;
        l.textColor = [UIColor whiteColor];
        l.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
        [av addSubview:l];
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(12, 12, kAvD - 24, kAvD - 24)];
        iv.tag = kAvIconTag;
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.tintColor = [UIColor whiteColor];
        iv.image = [UIImage systemImageNamed:@"person.fill"];
        [av addSubview:iv];
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

    // --- tìm label: tên (trái nhất, trên cùng)
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

    // --- dời contentView để tên nằm sát avatar (bù khoảng trống dành cho icon gốc)
    CGFloat off = name ? [name convertRect:name.bounds toView:cell.contentView].origin.x : 47.0;
    CGFloat cx = left - off;
    CGRect cf = CGRectMake(cx, 0, W - cx - right, H);
    if (!CGRectEqualToRect(cell.contentView.frame, cf)) {
        cell.contentView.frame = cf;
        [cell.contentView layoutIfNeeded];
    }

    // --- phân vai & đặt font
    UILabel *sub = nil, *timeL = nil; CGRect sr = CGRectZero;
    NSMutableArray<UILabel *> *sameRow = [NSMutableArray array];
    for (UILabel *l in ls) {
        if (l.hidden || l.text.length == 0 || l == name) continue;
        CGRect r = [l convertRect:l.bounds toView:cell];
        if (CGRectGetMidX(r) > W * 0.5) { if (!timeL) timeL = l; }
        else if (name && fabs(CGRectGetMidY(r) - CGRectGetMidY(nr)) < nr.size.height * 0.5 && r.origin.x > nr.origin.x) {
            [sameRow addObject:l];            // nhãn đếm "(4)" cùng hàng với tên
        }
        else if (!sub || r.origin.y < sr.origin.y) { sub = l; sr = r; }
    }
    UIFont *nf = [UIFont systemFontOfSize:kNameSize weight:UIFontWeightSemibold];
    UIFont *sf = [UIFont systemFontOfSize:kSubSize weight:UIFontWeightRegular];
    UIFont *tf = [UIFont systemFontOfSize:kTimeSize weight:UIFontWeightRegular];
    if (name && ![name.font isEqual:nf]) name.font = nf;
    if (sub && ![sub.font isEqual:sf]) sub.font = sf;
    if (timeL && ![timeL.font isEqual:tf]) timeL.font = tf;

    // --- căn giữa dọc khối (tên + dòng phụ) và giờ
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

    // --- mũi tên hướng cuộc gọi: ↗ gọi đi, ↙ gọi đến / nhỡ (thay icon gốc)
    UIImageView *icon = tw26_findIcon(cell.contentView);
    BOOL outgoing = (icon != nil);
    if (icon) icon.alpha = 0;
    if (sub) tw26_prefixArrow(sub, outgoing);

    // --- avatar chữ cái
    if (name) {
        NSString *t = name.text;
        NSString *ch = @"";
        if (t.length) ch = [[t substringWithRange:[t rangeOfComposedCharacterSequenceAtIndex:0]] uppercaseString];
        BOOL isLetter = ch.length && [[NSCharacterSet letterCharacterSet] characterIsMember:[ch characterAtIndex:0]];
        UILabel *al = (UILabel *)[av viewWithTag:kAvLetterTag];
        UIView *ai = [av viewWithTag:kAvIconTag];
        al.text = isLetter ? ch : @"";
        al.hidden = !isLetter;
        ai.hidden = isLetter;
    }

    // --- icon nút gọi / video
    NSString *kind = video ? @"video" : @"phone";
    if (![cb.accessibilityIdentifier isEqualToString:kind]) {
        cb.accessibilityIdentifier = kind;
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:21 weight:UIImageSymbolWeightMedium];
        [cb setImage:[UIImage systemImageNamed:(video ? @"video.fill" : @"phone.fill") withConfiguration:cfg]
            forState:UIControlStateNormal];
    }
}

%hook UITableViewCell
- (void)layoutSubviews {
    %orig;
    if (tw26_isRecentsCell(self)) tw26_cell(self);
}

%new
- (void)tw26_callTapped {
    UITableView *tv = tw26_tableOf(self);
    NSIndexPath *ip = [tv indexPathForCell:self];
    if (!tv || !ip) return;
    id<UITableViewDelegate> d = tv.delegate;
    if (kButtonCalls) {
        if ([d respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
            [d tableView:tv didSelectRowAtIndexPath:ip];
    } else {
        if ([d respondsToSelector:@selector(tableView:accessoryButtonTappedForRowWithIndexPath:)])
            [d tableView:tv accessoryButtonTappedForRowWithIndexPath:ip];
    }
}
%end
