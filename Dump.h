// Công cụ chẩn đoán: giữ 3 ngón tay 1 giây trên màn hình -> sao chép cấu trúc màn hình vào clipboard
// (chỉ tên class, kích thước; KHÔNG chứa nội dung chữ như tên/số điện thoại).
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void tw26_dumpView(UIView *v, int depth, NSMutableString *out, int *count) {
    if (depth > 11 || *count > 800) return;
    (*count)++;
    [out appendFormat:@"%*s%s %@", depth * 2, "", class_getName(object_getClass(v)), NSStringFromCGRect(v.frame)];
    if (v.hidden) [out appendString:@" hidden"];
    if (v.alpha < 0.99) [out appendFormat:@" a=%.2f", v.alpha];
    if ([v isKindOfClass:UILabel.class]) [out appendFormat:@" label(len=%lu)", (unsigned long)((UILabel *)v).text.length];
    if (v.tag) [out appendFormat:@" tag=%ld", (long)v.tag];
    [out appendString:@"\n"];
    for (UIView *s in v.subviews) tw26_dumpView(s, depth + 1, out, count);
}

static void tw26_dumpVC(UIViewController *vc, int depth, NSMutableString *out) {
    if (!vc || depth > 12) return;
    [out appendFormat:@"%*sVC %s\n", depth * 2, "", class_getName(object_getClass(vc))];
    for (UIViewController *c in vc.childViewControllers) tw26_dumpVC(c, depth + 1, out);
    if (vc.presentedViewController) tw26_dumpVC(vc.presentedViewController, depth + 1, out);
}

static NSString *tw26_dump(void) {
    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"== Phone26 dump | %@ | iOS %@ ==\n", [NSBundle mainBundle].bundleIdentifier, UIDevice.currentDevice.systemVersion];
    UIWindow *key = nil;
    for (UIWindow *w in UIApplication.sharedApplication.windows) if (w.isKeyWindow) { key = w; break; }
    if (!key) key = UIApplication.sharedApplication.windows.firstObject;
    [out appendString:@"-- Controllers --\n"];
    tw26_dumpVC(key.rootViewController, 0, out);
    [out appendString:@"-- Views --\n"];
    int count = 0;
    if (key) tw26_dumpView(key, 0, out, &count);
    return out;
}

@interface TW26Dumper : NSObject
- (void)fire:(UILongPressGestureRecognizer *)g;
@end
@implementation TW26Dumper
- (void)fire:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    [UIPasteboard generalPasteboard].string = tw26_dump();
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy] impactOccurred];
}
@end

static void tw26_attachDumpGesture(UIWindow *w) {
    static char kKey;
    static TW26Dumper *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [TW26Dumper new]; });
    if (objc_getAssociatedObject(w, &kKey)) return;
    UILongPressGestureRecognizer *g = [[UILongPressGestureRecognizer alloc] initWithTarget:d action:@selector(fire:)];
    g.numberOfTouchesRequired = 3;
    g.minimumPressDuration = 1.0;
    g.cancelsTouchesInView = NO;
    [w addGestureRecognizer:g];
    objc_setAssociatedObject(w, &kKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void tw26_dumpInstall(void) {
    void (^attach)(NSNotification *) = ^(NSNotification *n) {
        for (UIWindow *w in UIApplication.sharedApplication.windows) tw26_attachDumpGesture(w);
    };
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:attach];
    [nc addObserverForName:UIWindowDidBecomeKeyNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:attach];
}
