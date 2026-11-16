// Phone26 v2 - Giao diện app Điện thoại kiểu iOS 26 (MobilePhone)
//  - Tab bar nổi: 3 tab + nút tìm kiếm tròn tách rời cùng hàng
//  - Mỗi dòng cuộc gọi: avatar tròn gradient + tên đậm + giờ + nút gọi/video tròn xám bên phải
//  - Nút "Sửa" / "lọc" trên thanh tiêu đề thành viên thuốc kính mờ, tiêu đề nhỏ ở giữa
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ===================== CẤU HÌNH =====================
// YES: bấm nút tròn bên phải = gọi lại (giống bấm dòng).  NO: bấm nút = mở chi tiết cuộc gọi (nút "i" cũ)
static const BOOL kButtonCalls = YES;

static const CGFloat kBarH = 64.0, kSide = 18.0, kGap = 10.0;   // tab bar
static const CGFloat kRowH = 82.0, kAvD = 50.0, kBtnD = 56.0, kRowSide = 16.0; // dòng cuộc gọi
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

    NSMutableArray<UIView *> *btns = [NSMutableArray array];
    tw26_findBarButtons(self, btns);
    for (UIView *b in btns) {
        CGFloat bw = b.bounds.size.width, bh = b.bounds.size.height;
        if (bw < 1) continue;
        NSMutableArray *ls = [NSMutableArray array];
        tw26_collectLabels(b, ls);
        CGFloat h = 44.0, w = ls.count ? MAX(68.0, bw + 24.0) : 44.0;
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
        ev.frame = CGRectMake((bw - w) / 2.0, (bh - h) / 2.0, w, h);
        ev.layer.cornerRadius = h / 2.0;
    }
}
%end

#pragma mark - Dòng cuộc gọi (avatar + giờ + nút gọi tròn)

static BOOL tw26_isRecentsCell(UITableViewCell *c) {
    NSString *n = NSStringFromClass(c.class);
    return [n rangeOfString:@"Recents" options:NSCaseInsensitiveSearch].location != NSNotFound ||
           [n rangeOfString:@"RecentCall" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static void tw26_cell(UITableViewCell *cell) {
    UITableView *tv = tw26_tableOf(cell);
    CGFloat W = cell.bounds.size.width, H = cell.bounds.size.height;
    if (W < 1 || H < 1) return;

    // Chiều cao dòng
    if (tv && !objc_getAssociatedObject(tv, &kRowKey)) {
        objc_setAssociatedObject(tv, &kRowKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        tv.rowHeight = kRowH;
        dispatch_async(dispatch_get_main_queue(), ^{ [tv beginUpdates]; [tv endUpdates]; });
    }

    // Bỏ nút "i" gốc
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
        l.font = [UIFont systemFontOfSize:24 weight:UIFontWeightSemibold];
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

    CGFloat left = kRowSide + kAvD + 12.0, right = kRowSide + kBtnD + 6.0;
    CGRect cf = CGRectMake(left, 0, W - left - right, H);
    if (!CGRectEqualToRect(cell.contentView.frame, cf)) cell.contentView.frame = cf;
    cell.separatorInset = UIEdgeInsetsMake(0, left, 0, kRowSide);
    av.frame = CGRectMake(kRowSide, (H - kAvD) / 2.0, kAvD, kAvD);
    cb.frame = CGRectMake(W - kRowSide - kBtnD, (H - kBtnD) / 2.0, kBtnD, kBtnD);
    [cell bringSubviewToFront:cb];

    // Tìm label tên (trái nhất, trên cùng) & phát hiện cuộc gọi video
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
    if (name) {
        UIFont *f = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
        if (fabs(name.font.pointSize - 18) > 0.1 || name.font.fontDescriptor.symbolicTraits != f.fontDescriptor.symbolicTraits)
            name.font = f;
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

    // Icon điện thoại / video
    NSString *kind = video ? @"video" : @"phone";
    if (![cb.accessibilityIdentifier isEqualToString:kind]) {
        cb.accessibilityIdentifier = kind;
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
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
