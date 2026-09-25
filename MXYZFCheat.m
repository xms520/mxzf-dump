// MXYZFUikit.m — 冒险与征途 悬浮助手（纯 UI 壳，无任何游戏功能/无 il2cpp 依赖）
// 悬浮球 = 头像 + 抖音同款彩虹环（CAGradientLayer 环形遮罩）；拖动；点开面板
// 面板：标题「昆哥儿科技」+ 左上角同款头像；面板外点击关闭
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static FILE *g_log = NULL;
static void mlog(NSString *fmt, ...) NS_FORMAT_FUNCTION(1,2);
static void mlog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[MXZF] %@", s);
    if (!g_log) {
        NSString *p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/mxzf.log"];
        g_log = fopen(p.UTF8String, "a");
    }
    if (g_log) { fprintf(g_log, "[MXZF] %s\n", s.UTF8String); fflush(g_log); }
}

#pragma mark - 内嵌头像（base64 JPEG）
static NSString * const kAvatarB64 =
    @"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"
    @"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"
    @"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"
    @"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"
    ;

static UIImage *mx_avatar(void) {
    static UIImage *img = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSData *d = [[NSData alloc] initWithBase64EncodedString:kAvatarB64 options:0];
        img = [UIImage imageWithData:d];
    });
    return img;
}

static UIColor *mx_c(int r, int g, int b, CGFloat a) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}

#pragma mark - 悬浮球（渐变环 + 圆头像）
#define TAG_BALL  978001
#define TAG_PANEL 978002
#define TAG_AV    978003

// 构建彩虹环 view（抖音同款：青→紫→红→橙 渐变环 + 头像圆形居中）
static UIView *mx_rainbow_ball(CGFloat size) {
    UIView *wrap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    wrap.userInteractionEnabled = NO;   // 手势加在外层 UIButton 上
    wrap.backgroundColor = nil;

    // 外层彩虹渐变圆
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = wrap.bounds;
    grad.colors = @[
        (id)[UIColor colorWithRed:0.10 green:0.85 blue:1.00 alpha:1].CGColor,  // 青
        (id)[UIColor colorWithRed:0.45 green:0.30 blue:1.00 alpha:1].CGColor,  // 紫蓝
        (id)[UIColor colorWithRed:1.00 green:0.15 blue:0.35 alpha:1].CGColor,  // 红
        (id)[UIColor colorWithRed:1.00 green:0.55 blue:0.10 alpha:1].CGColor,  // 橙
        (id)[UIColor colorWithRed:0.10 green:0.85 blue:1.00 alpha:1].CGColor,  // 青（闭环）
    ];
    grad.startPoint = CGPointMake(0.5, 0.0);
    grad.endPoint   = CGPointMake(0.5, 1.0);
    grad.cornerRadius = size / 2.0;
    [wrap.layer addSublayer:grad];

    // 内圆挖空（环效果）：mask = 外圆 - 内圆
    CGFloat hole = size * 0.84;                        // 内圆直径（留 8% 环宽）
    CAShapeLayer *mask = [CAShapeLayer layer];
    CGMutablePathRef p = CGPathCreateMutable();
    CGPathAddEllipseInRect(p, NULL, CGRectMake(0, 0, size, size));
    CGPathAddEllipseInRect(p, NULL, CGRectMake((size-hole)/2, (size-hole)/2, hole, hole));
    mask.path = p;
    mask.fillRule = (CAFillRule)1; // kCAFillRuleEvenOdd
    CGPathRelease(p);
    grad.mask = mask;

    // 头像（圆形，居中，略微小于内圆）
    UIImageView *av = [[UIImageView alloc] initWithFrame:CGRectMake((size-hole)/2 + 1, (size-hole)/2 + 1, hole - 2, hole - 2)];
    av.image = mx_avatar();
    av.contentMode = UIViewContentModeScaleAspectFill;
    av.clipsToBounds = YES;
    av.layer.cornerRadius = (hole - 2) / 2.0;
    av.tag = TAG_AV;
    [wrap addSubview:av];
    return wrap;
}

#pragma mark - UI
static void ui_toggle_panel(void);
static void mx_make_ui(void);

@interface MXBox : NSObject
+ (instancetype)shared;
- (void)noop;
- (void)tapMask;
- (void)tapBall;
- (void)dragBall:(UIPanGestureRecognizer *)g;
@end
@implementation MXBox
+ (instancetype)shared { static MXBox *b; static dispatch_once_t o; dispatch_once(&o, ^{ b = [self new]; }); return b; }
- (void)noop {}
- (void)tapMask { ui_toggle_panel(); }
- (void)tapBall { ui_toggle_panel(); }
- (void)dragBall:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    CGPoint t = [g translationInView:v.superview];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [g setTranslation:CGPointZero inView:v.superview];
}
@end

static void ui_toggle_panel(void) {
    UIWindow *w = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    UIView *p = [w viewWithTag:TAG_PANEL];
    if (p) {                      // 已开 → 收起（含遮罩）
        [[w viewWithTag:978004] removeFromSuperview];
        [p removeFromSuperview];
        return;
    }
    CGFloat pw = 250, ph = 150;

    // 遮罩：点外部关闭
    UIView *mask = [[UIView alloc] initWithFrame:w.bounds];
    mask.tag = 978004;
    mask.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
    mask.userInteractionEnabled = YES;
    [mask addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:[MXBox shared] action:@selector(tapMask)]];

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(16, 90, pw, ph)];
    panel.tag = TAG_PANEL;
    panel.layer.cornerRadius = 16;
    panel.backgroundColor = mx_c(16, 18, 26, 0.96);
    panel.layer.borderColor = mx_c(70, 140, 255, 0.45).CGColor;
    panel.layer.borderWidth = 1;
    panel.userInteractionEnabled = YES;
    [panel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:[MXBox shared] action:@selector(noop)]];

    // 左上角头像（同悬浮球，小号彩虹环）
    UIView *avWrap = mx_rainbow_ball(40);
    avWrap.frame = CGRectMake(12, 12, 40, 40);
    [panel addSubview:avWrap];

    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(60, 20, pw - 70, 24)];
    title.text = @"✦ 昆哥儿科技 ✦";
    title.textColor = mx_c(255, 214, 90, 1);
    title.font = [UIFont boldSystemFontOfSize:16];
    title.textAlignment = NSTextAlignmentLeft;
    [panel addSubview:title];

    // 副标语
    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(14, 64, pw - 28, 60)];
    sub.text = @"悬浮助手已就绪\n此版本为纯 UI 壳，未挂载任何游戏功能";
    sub.textColor = mx_c(160, 168, 185, 1);
    sub.font = [UIFont systemFontOfSize:12];
    sub.numberOfLines = 0;
    [panel addSubview:sub];

    [w addSubview:mask];
    [w addSubview:panel];
    UIView *ball = [w viewWithTag:TAG_BALL];
    if (ball) [w bringSubviewToFront:ball];
}

static void mx_make_ui(void) {
    UIWindow *w = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    if (!w) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ mx_make_ui(); }); return; }
    if ([w viewWithTag:TAG_BALL]) return;

    CGFloat bs = 58;
    UIView *ballWrap = mx_rainbow_ball(bs);
    ballWrap.tag = TAG_BALL;
    ballWrap.frame = CGRectMake(w.bounds.size.width - bs - 18, 150, bs, bs);
    ballWrap.userInteractionEnabled = YES;
    ballWrap.layer.shadowColor = [UIColor blackColor].CGColor;
    ballWrap.layer.shadowOpacity = 0.4;
    ballWrap.layer.shadowRadius = 4;
    ballWrap.layer.shadowOffset = CGSizeMake(0, 2);

    // 手势加在透明按钮上（点按 + 拖动共存）
    UIButton *hit = [UIButton buttonWithType:UIButtonTypeCustom];
    hit.frame = ballWrap.bounds;
    hit.backgroundColor = [UIColor clearColor];
    [hit addTarget:[MXBox shared] action:@selector(tapBall) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[MXBox shared] action:@selector(dragBall:)];
    [hit addGestureRecognizer:pan];
    [ballWrap addSubview:hit];

    [w addSubview:ballWrap];
    mlog(@"UI ready (pure shell)");
}

__attribute__((constructor)) static void mxzf_ctor(void) {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"?";
        mlog(@"ctor pid=%d bid=%@ (pure-UI build)", getpid(), bid);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            mx_make_ui();
        });
    }
}
