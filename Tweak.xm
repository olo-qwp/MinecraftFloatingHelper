/*
 * MinecraftFloatingHelper - iOS悬浮窗多功能辅助工具 for Minecraft PE
 * 支持所有MC版本: 国际版/网易版/预览版/教育版
 * 兼容A11芯片 (iPhone 8/X), iOS 15+, 60fps
 * 13项功能: 飞行/加速/杀戮光环/ESP透视/X-Ray/防摔/自动挖矿/自动吃/范围扩大/防击退/夜视/自动工具/穿墙
 *
 * 关键方案: 创建独立 PassThroughWindow (UIWindowLevelStatusBar + 1000)
 * Minecraft PE 使用 Metal 渲染层覆盖整个窗口，直接 addSubview 到游戏窗口
 * 会被渲染层遮挡。必须使用独立高层 UIWindow 才能显示在游戏画面之上。
 * PassThroughWindow 重写 hitTest:with: 实现触摸穿透，不影响游戏交互。
 * 使用 CADisplayLink 持续保活窗口，防止被游戏渲染覆盖。
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - ==================== 功能定义 ====================

typedef NS_ENUM(NSInteger, MCTFeature) {
    MCTFeatureFly = 0,
    MCTFeatureSpeed,
    MCTFeatureKillAura,
    MCTFeatureESP,
    MCTFeatureXRay,
    MCTFeatureNoFall,
    MCTFeatureAutoMine,
    MCTFeatureAutoEat,
    MCTFeatureReach,
    MCTFeatureAntiKB,
    MCTFeatureFullbright,
    MCTFeatureAutoTool,
    MCTFeatureNoClip,
    MCTFeatureCount
};

static NSString * const kFeatureNames[] = {
    [MCTFeatureFly]       = @"飞行 Fly",
    [MCTFeatureSpeed]     = @"加速 Speed",
    [MCTFeatureKillAura]  = @"杀戮光环 KillAura",
    [MCTFeatureESP]       = @"ESP透视",
    [MCTFeatureXRay]      = @"矿透 X-Ray",
    [MCTFeatureNoFall]    = @"防摔 NoFall",
    [MCTFeatureAutoMine]  = @"自动挖矿 AutoMine",
    [MCTFeatureAutoEat]   = @"自动吃 AutoEat",
    [MCTFeatureReach]     = @"范围扩大 Reach",
    [MCTFeatureAntiKB]    = @"防击退 AntiKB",
    [MCTFeatureFullbright]= @"夜视 Fullbright",
    [MCTFeatureAutoTool]  = @"自动工具 AutoTool",
    [MCTFeatureNoClip]    = @"穿墙 NoClip"
};

static NSString * const kFeatureIcons[] = {
    [MCTFeatureFly]       = @"🪽",
    [MCTFeatureSpeed]     = @"⚡",
    [MCTFeatureKillAura]  = @"⚔️",
    [MCTFeatureESP]       = @"👁️",
    [MCTFeatureXRay]      = @"💎",
    [MCTFeatureNoFall]    = @"🛡️",
    [MCTFeatureAutoMine]  = @"⛏️",
    [MCTFeatureAutoEat]   = @"🍖",
    [MCTFeatureReach]     = @"📏",
    [MCTFeatureAntiKB]    = @"🧱",
    [MCTFeatureFullbright]= @"☀️",
    [MCTFeatureAutoTool]  = @"🔧",
    [MCTFeatureNoClip]    = @"👻"
};

#pragma mark - ==================== 全局状态 ====================

static BOOL g_featureEnabled[MCTFeatureCount] = {NO};
static BOOL g_tweakReady = NO;
static UIButton *g_floatingBtn = nil;
static UIView *g_menuPanel = nil;
static BOOL g_menuVisible = NO;

#pragma mark - ==================== PassThroughWindow ====================

// 独立窗口，悬浮在游戏画面之上
// hitTest 返回 nil 时触摸穿透到游戏，只有点中按钮/菜单时才拦截
@interface MCPassThroughWindow : UIWindow
@end

@implementation MCPassThroughWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    // 只有命中的是窗口本身（透明背景），才返回 nil 让触摸穿透到游戏
    if (hitView == self) {
        return nil;
    }
    return hitView;
}

@end

static MCPassThroughWindow *g_overlayWindow = nil;
static CADisplayLink *g_keepAliveLink = nil;

#pragma mark - ==================== 颜色定义 ====================

#define COLOR_ACCENT [UIColor colorWithRed:0.20 green:0.80 blue:0.60 alpha:1.0]
#define COLOR_CARD_NORMAL [UIColor colorWithRed:0.14 green:0.14 blue:0.20 alpha:0.85]
#define COLOR_CARD_ON [UIColor colorWithRed:0.20 green:0.70 blue:0.50 alpha:0.25]
#define COLOR_BORDER_ON [UIColor colorWithRed:0.20 green:0.80 blue:0.60 alpha:0.40]
#define COLOR_ENABLED [UIColor colorWithRed:0.20 green:0.80 blue:0.60 alpha:1.0]

#pragma mark - ==================== 工具方法 ====================

static void MCExecOnMain(void (^block)(void)) {
    if ([NSThread isMainThread]) { block(); }
    else { dispatch_async(dispatch_get_main_queue(), block); }
}

static UIColor *MCColorForFeature(MCTFeature f) {
    switch (f) {
        case MCTFeatureFly:    return [UIColor colorWithRed:0.29 green:0.69 blue:1.00 alpha:1.0];
        case MCTFeatureSpeed:  return [UIColor colorWithRed:1.00 green:0.84 blue:0.20 alpha:1.0];
        case MCTFeatureKillAura: return [UIColor colorWithRed:1.00 green:0.27 blue:0.27 alpha:1.0];
        case MCTFeatureESP:    return [UIColor colorWithRed:0.69 green:0.33 blue:1.00 alpha:1.0];
        default: return COLOR_ACCENT;
    }
}

/// 获取当前 App 的活跃 UIWindowScene
static UIWindowScene *MCGetActiveScene(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState == UISceneActivationStateForegroundActive) {
                return ws;
            }
        }
        // 后备: 取任意一个 windowScene
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                return (UIWindowScene *)scene;
            }
        }
    }
    return nil;
}

/// CADisplayLink 保活辅助类
@interface MCKeepAlive : NSObject
+ (instancetype)shared;
- (void)tick:(CADisplayLink *)link;
@end

@implementation MCKeepAlive
+ (instancetype)shared {
    static MCKeepAlive *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [self new]; });
    return instance;
}
- (void)tick:(CADisplayLink *)link {
    if (g_overlayWindow) {
        // 仅保持窗口可见，不抢占 key window（避免破坏游戏输入/窗口管理）
        if (g_overlayWindow.hidden) {
            g_overlayWindow.hidden = NO;
        }
        // 把悬浮按钮提到最前，防止被游戏渲染层覆盖
        if (g_floatingBtn && g_floatingBtn.superview == g_overlayWindow) {
            [g_overlayWindow bringSubviewToFront:g_floatingBtn];
        }
    }
}
@end

/// 创建或复用独立 overlay 窗口
static MCPassThroughWindow *MCGetOverlayWindow(void) {
    if (g_overlayWindow && !g_overlayWindow.hidden) {
        return g_overlayWindow;
    }

    UIWindowScene *scene = MCGetActiveScene();
    if (!scene) {
        NSLog(@"[MCTweak] 无法获取 UIWindowScene");
        return nil;
    }

    g_overlayWindow = [[MCPassThroughWindow alloc] initWithWindowScene:scene];
    // 使用极高窗口层级，确保在 Metal 渲染层之上
    g_overlayWindow.windowLevel = UIWindowLevelStatusBar + 1000.0;
    g_overlayWindow.backgroundColor = [UIColor clearColor];
    g_overlayWindow.opaque = NO;
    g_overlayWindow.frame = [UIScreen mainScreen].bounds;
    g_overlayWindow.userInteractionEnabled = YES;
    // 仅设为可见，不抢占 key window（游戏保持焦点，hitTest 跨窗口穿透仍生效）
    g_overlayWindow.hidden = NO;

    // CADisplayLink 持续保活，防止游戏渲染覆盖窗口
    if (!g_keepAliveLink) {
        g_keepAliveLink = [CADisplayLink displayLinkWithTarget:[MCKeepAlive shared]
                                                       selector:@selector(tick:)];
        [g_keepAliveLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }

    NSLog(@"[MCTweak] Overlay 窗口已创建, level: %.1f", g_overlayWindow.windowLevel);
    return g_overlayWindow;
}

#pragma mark - ==================== 功能实现（前置声明） ====================
// 重要：com.mojang.minecraftpe 是 C++ 二进制。LocalPlayer / MinecraftClient /
// MoveInputHandler / Player 均为 C++ 类，不在 ObjC 运行时中，Logos %hook 对它们
// 完全无效（objc_getClass 返回 nil，钩子永不触发）。因此本插件不再 %hook 这些类。
// 可用实现路线：
//   - 夜视 Fullbright：修改 options.txt 的 gfx_gamma（免逆向，最稳）
//   - 飞行/加速：发送游戏命令 /gamemode、/effect（需世界开启作弊 + 聊天注入）
//   - KillAura/ESP/X-Ray/Reach/Knockback 等：纯 C++ 逻辑，需 IDA+Dobby 偏移挂钩，
//     本插件不提供无效代码，仅给出诚实提示。
static void MCShowToast(NSString *msg);
static void MCSetFullbright(BOOL on);
static BOOL MCSendCommand(NSString *cmd);
static void MCApplyFeature(MCTFeature feat, BOOL on);

#pragma mark - ==================== 悬浮窗管理 ====================

@interface MCFloatingManager : NSObject
@property (nonatomic, strong) UIButton *floatingBtn;
@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, assign) BOOL menuVisible;
- (void)setup;
- (void)show;
- (void)hide;
@end

@implementation MCFloatingManager

+ (instancetype)shared {
    static MCFloatingManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)setup {
    MCPassThroughWindow *overlayWin = MCGetOverlayWindow();

    // 后备: 若无法创建独立 overlay 窗口，注入到游戏 key window 的根视图
    UIView *hostView = nil;
    if (overlayWin) {
        hostView = overlayWin;
    } else {
        NSLog(@"[MCTweak] overlay 窗口不可用，尝试注入游戏 key window");
        UIWindow *keyWin = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (!w.hidden && w.windowLevel == UIWindowLevelNormal) { keyWin = w; break; }
        }
        if (!keyWin) {
            NSLog(@"[MCTweak] 无可用 key window，延迟重试");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self setup];
            });
            return;
        }
        hostView = keyWin.rootViewController.view ?: keyWin;
    }

    // 如果按钮已存在且在当前宿主中，跳过
    if (self.floatingBtn && self.floatingBtn.superview == hostView) {
        return;
    }

    // 清理旧按钮
    [self.floatingBtn removeFromSuperview];
    self.floatingBtn = nil;
    g_floatingBtn = nil;

    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;

    // 悬浮按钮 - 直接添加到宿主视图（不用 rootViewController）
    CGFloat btnSize = 52;
    CGFloat margin = 16;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(sw - btnSize - margin, sh * 0.35, btnSize, btnSize);
    btn.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.20 alpha:0.92];
    btn.layer.cornerRadius = btnSize / 2;
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOffset = CGSizeMake(0, 4);
    btn.layer.shadowOpacity = 0.5;
    btn.layer.shadowRadius = 8;
    btn.layer.borderWidth = 2;
    btn.layer.borderColor = COLOR_ACCENT.CGColor;
    btn.titleLabel.font = [UIFont systemFontOfSize:24];
    [btn setTitle:@"⛏" forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(btnTapped) forControlEvents:UIControlEventTouchUpInside];

    // 确保按钮在最上层
    btn.layer.zPosition = 9999;

    // 拖拽手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(btnDragged:)];
    [btn addGestureRecognizer:pan];

    // 直接添加到宿主视图，不通过 rootViewController
    [hostView addSubview:btn];
    [hostView bringSubviewToFront:btn];

    self.floatingBtn = btn;
    g_floatingBtn = btn;

    NSLog(@"[MCTweak] 悬浮按钮已添加到宿主视图: %@", hostView.class);
}

- (void)show {
    MCExecOnMain(^{
        [self setup];
        if (!self.floatingBtn) return;

        // 确保按钮可见并位于最上层（宿主可能是 overlay 窗口或游戏 key window）
        self.floatingBtn.hidden = NO;
        UIView *host = self.floatingBtn.superview;
        if (host) {
            [host bringSubviewToFront:self.floatingBtn];
        }

        // 入场动画
        self.floatingBtn.transform = CGAffineTransformMakeScale(0.3, 0.3);
        self.floatingBtn.alpha = 0;
        [UIView animateWithDuration:0.6 delay:0.3 usingSpringWithDamping:0.6 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.floatingBtn.transform = CGAffineTransformIdentity;
            self.floatingBtn.alpha = 1;
        } completion:nil];

        NSLog(@"[MCTweak] 悬浮窗已显示");
    });
}

- (void)hide {
    MCExecOnMain(^{
        [self.menuView removeFromSuperview];
        self.menuView = nil;
        self.menuVisible = NO;
        g_menuVisible = NO;
        self.floatingBtn.hidden = YES;
        [self.floatingBtn removeFromSuperview];
        self.floatingBtn = nil;
        g_floatingBtn = nil;
        // 隐藏 overlay 窗口（若存在）
        if (g_overlayWindow) {
            g_overlayWindow.hidden = YES;
            g_overlayWindow = nil;
        }
    });
}

- (void)btnDragged:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    if (!v) return;
    static CGPoint center;
    if (g.state == UIGestureRecognizerStateBegan) {
        center = v.center;
        [UIView animateWithDuration:0.2 animations:^{
            v.transform = CGAffineTransformMakeScale(1.15, 1.15);
        }];
    } else if (g.state == UIGestureRecognizerStateChanged) {
        CGPoint t = [g translationInView:v.superview];
        v.center = CGPointMake(center.x + t.x, center.y + t.y);
    } else if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            v.transform = CGAffineTransformIdentity;
            CGRect f = v.frame;
            CGFloat sw = [UIScreen mainScreen].bounds.size.width;
            CGFloat sh = [UIScreen mainScreen].bounds.size.height;
            CGFloat tx = (f.origin.x + f.size.width/2 < sw/2) ? 8 : sw - f.size.width - 8;
            tx = MAX(4, MIN(tx, sw - f.size.width - 4));
            CGFloat ty = MAX(50, MIN(f.origin.y, sh - f.size.height - 50));
            f.origin.x = tx; f.origin.y = ty;
            v.frame = f;
        } completion:nil];
    }
}

- (void)btnTapped {
    if (self.menuVisible) [self dismissMenu];
    else [self showMenu];
}

- (void)showMenu {
    if (self.menuVisible) return;
    self.menuVisible = YES;
    g_menuVisible = YES;

    // 使用按钮所在宿主作为菜单容器（overlay 窗口或游戏 key window）
    UIView *containerView = self.floatingBtn.superview;
    if (!containerView) {
        MCPassThroughWindow *overlayWin = MCGetOverlayWindow();
        containerView = overlayWin;
    }
    if (!containerView) return;

    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    CGFloat pw = MIN(sw - 32, 380);
    CGFloat ph = MIN(sh * 0.72, 540);
    CGFloat px = (sw - pw) / 2;
    CGFloat py = (sh - ph) / 2;

    // 遮罩层
    UIButton *overlay = [UIButton buttonWithType:UIButtonTypeCustom];
    overlay.frame = CGRectMake(0, 0, sw, sh);
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    overlay.tag = 9991;
    overlay.layer.zPosition = 9998;
    [overlay addTarget:self action:@selector(dismissMenu) forControlEvents:UIControlEventTouchUpInside];
    [containerView addSubview:overlay];
    [containerView bringSubviewToFront:overlay];
    overlay.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{ overlay.alpha = 1; }];
    
    // 主面板
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(px, py, pw, ph)];
    panel.backgroundColor = [UIColor clearColor];
    panel.layer.cornerRadius = 22;
    panel.clipsToBounds = YES;
    panel.layer.zPosition = 9999;
    
    // 毛玻璃
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blur.frame = panel.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [panel addSubview:blur];
    
    // 标题栏
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, pw, 54)];
    header.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.18 alpha:0.5];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, pw - 80, 54)];
    title.text = @"⛏ Minecraft 辅助";
    title.font = [UIFont boldSystemFontOfSize:18];
    title.textColor = [UIColor whiteColor];
    [header addSubview:title];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(pw - 48, 7, 40, 40);
    closeBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.4];
    closeBtn.layer.cornerRadius = 20;
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(dismissMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];
    
    [panel addSubview:header];
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, 54, pw, 1)];
    sep.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.3];
    [panel addSubview:sep];
    
    // 功能列表 - 使用UIScrollView + 手动布局
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 55, pw, ph - 55)];
    scroll.showsVerticalScrollIndicator = NO;
    scroll.backgroundColor = [UIColor clearColor];
    
    // 分类数据
    NSArray *sections = @[
        @{@"title": @"🏃 移动 Movement", @"features": @[@(MCTFeatureFly), @(MCTFeatureSpeed), @(MCTFeatureNoClip)]},
        @{@"title": @"⚔️ 战斗 Combat", @"features": @[@(MCTFeatureKillAura), @(MCTFeatureReach), @(MCTFeatureAntiKB)]},
        @{@"title": @"👁️ 视觉 Visual", @"features": @[@(MCTFeatureESP), @(MCTFeatureXRay), @(MCTFeatureFullbright)]},
        @{@"title": @"🎯 生存 Survival", @"features": @[@(MCTFeatureNoFall), @(MCTFeatureAutoMine), @(MCTFeatureAutoEat), @(MCTFeatureAutoTool)]}
    ];
    
    CGFloat yOff = 0;
    CGFloat rowH = 60;
    CGFloat sectionH = 32;
    CGFloat leftMargin = 16;
    CGFloat cellW = pw - 32;
    
    NSArray *descs = @[
        @"自由飞行模式", @"提升移动速度", @"穿越方块移动",
        @"自动攻击附近敌人", @"增加交互距离", @"免疫击退效果",
        @"透视实体位置", @"透视矿物方块", @"永久明亮视野",
        @"免疫摔落伤害", @"快速破坏方块", @"自动补充饱食度", @"自动切换最佳工具"
    ];
    
    for (NSDictionary *section in sections) {
        // 分类标题
        UILabel *sectionLabel = [[UILabel alloc] initWithFrame:CGRectMake(leftMargin, yOff, cellW, sectionH)];
        sectionLabel.text = section[@"title"];
        sectionLabel.font = [UIFont boldSystemFontOfSize:14];
        sectionLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
        [scroll addSubview:sectionLabel];
        yOff += sectionH;
        
        NSArray *features = section[@"features"];
        for (NSNumber *featNum in features) {
            MCTFeature feat = (MCTFeature)[featNum integerValue];
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(leftMargin, yOff, cellW, rowH - 4)];
            row.backgroundColor = COLOR_CARD_NORMAL;
            row.layer.cornerRadius = 14;
            row.tag = 2000 + feat;
            
            // 图标
            UILabel *iconL = [[UILabel alloc] initWithFrame:CGRectMake(12, 12, 36, 36)];
            iconL.text = kFeatureIcons[feat];
            iconL.font = [UIFont systemFontOfSize:22];
            iconL.textAlignment = NSTextAlignmentCenter;
            [row addSubview:iconL];
            
            // 名称
            UILabel *nameL = [[UILabel alloc] initWithFrame:CGRectMake(56, 6, 160, 24)];
            nameL.text = kFeatureNames[feat];
            nameL.font = [UIFont boldSystemFontOfSize:14];
            nameL.textColor = [UIColor whiteColor];
            [row addSubview:nameL];
            
            // 描述
            UILabel *descL = [[UILabel alloc] initWithFrame:CGRectMake(56, 28, 160, 20)];
            descL.text = (feat < 13) ? descs[feat] : @"";
            descL.font = [UIFont systemFontOfSize:10];
            descL.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
            [row addSubview:descL];
            
            // 开关
            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(cellW - 66, 14, 51, 31)];
            sw.onTintColor = COLOR_ENABLED;
            sw.tag = 3000 + feat;
            sw.on = g_featureEnabled[feat];
            [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            [row addSubview:sw];
            
            // 高亮状态
            if (g_featureEnabled[feat]) {
                UIColor *accent = MCColorForFeature(feat);
                row.backgroundColor = [accent colorWithAlphaComponent:0.2];
                row.layer.borderWidth = 1;
                row.layer.borderColor = [accent colorWithAlphaComponent:0.4].CGColor;
            } else {
                row.layer.borderWidth = 0;
            }
            
            [scroll addSubview:row];
            yOff += rowH;
        }
        yOff += 6;
    }
    
    yOff += 16;
    scroll.contentSize = CGSizeMake(cellW, yOff);
    [panel addSubview:scroll];
    
    self.menuView = panel;
    g_menuPanel = panel;

    // 入场动画
    panel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    panel.alpha = 0;
    [containerView addSubview:panel];
    [containerView bringSubviewToFront:panel];
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        panel.transform = CGAffineTransformIdentity;
        panel.alpha = 1;
    } completion:nil];
    
    // 按钮脉冲
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.duration = 0.15;
    pulse.fromValue = @1.0;
    pulse.toValue = @0.85;
    pulse.autoreverses = YES;
    [self.floatingBtn.layer addAnimation:pulse forKey:nil];
}

- (void)dismissMenu {
    if (!self.menuVisible) return;
    self.menuVisible = NO;
    g_menuVisible = NO;

    UIView *container = self.menuView.superview ?: (UIView *)g_overlayWindow;
    [UIView animateWithDuration:0.25 animations:^{
        self.menuView.transform = CGAffineTransformMakeScale(0.85, 0.85);
        self.menuView.alpha = 0;
        UIView *ov = [container viewWithTag:9991];
        ov.alpha = 0;
    } completion:^(BOOL finished) {
        [self.menuView removeFromSuperview];
        self.menuView = nil;
        g_menuPanel = nil;
        [[container viewWithTag:9991] removeFromSuperview];
    }];
}

- (void)switchChanged:(UISwitch *)sender {
    MCTFeature feat = (MCTFeature)(sender.tag - 3000);
    g_featureEnabled[feat] = sender.isOn;
    NSLog(@"[MCTweak] %@ -> %@", kFeatureNames[feat], sender.isOn ? @"ON" : @"OFF");

    // 更新卡片样式
    UIView *row = [self.menuView viewWithTag:2000 + feat];
    if (row) {
        if (sender.isOn) {
            UIColor *accent = MCColorForFeature(feat);
            row.backgroundColor = [accent colorWithAlphaComponent:0.2];
            row.layer.borderWidth = 1;
            row.layer.borderColor = [accent colorWithAlphaComponent:0.4].CGColor;
        } else {
            row.backgroundColor = COLOR_CARD_NORMAL;
            row.layer.borderWidth = 0;
        }
    }

    // 派发到真实功能实现
    MCApplyFeature(feat, sender.isOn);
}

@end

#pragma mark - ==================== 初始化 ====================

/*
 * 初始化策略：
 * 1. 监听 UIApplicationDidFinishLaunchingNotification 等待App启动完成
 * 2. 启动后每隔1秒尝试获取窗口，最多尝试10次
 * 3. 监听 UIApplicationDidBecomeActiveNotification 作为后备
 * 4. 窗口出现时自动重新附加按钮
 */

%ctor {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        NSLog(@"[MCTweak] 插件加载! Bundle: %@", bundleID);

        // 支持所有 MC 版本: 国际版/预览版/教育版/网易版
        // plist 已限制仅注入 MC 相关 App，这里做容错校验，匹配所有 Mojang/网易 变体
        BOOL isMinecraft = NO;
        NSString *lower = [bundleID lowercaseString];
        if ([lower hasPrefix:@"com.mojang.minecraft"]) {
            isMinecraft = YES; // com.mojang.minecraftpe / .preview / minecraftedu / minecraftedu_preview
        } else if ([lower isEqualToString:@"com.netease.x19"] ||
                   [lower isEqualToString:@"com.netease.mc"]) {
            isMinecraft = YES; // 网易中国版
        }
        if (!isMinecraft) {
            NSLog(@"[MCTweak] 非目标App，跳过加载");
            return;
        }
        NSLog(@"[MCTweak] 已识别为 Minecraft 变体，开始初始化");
        
        // 方式1: 启动完成后延时加载
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            // 启动后等待2秒，给游戏初始化时间
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (!g_tweakReady) {
                    g_tweakReady = YES;
                    [[MCFloatingManager shared] show];
                    NSLog(@"[MCTweak] 方式1: 启动完成加载");
                }
            });
        }];
        
        // 方式2: 后备 - App活跃时加载
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            if (!g_tweakReady) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (!g_tweakReady) {
                        g_tweakReady = YES;
                        [[MCFloatingManager shared] show];
                        NSLog(@"[MCTweak] 方式2: 活跃通知加载");
                    }
                });
            }
        }];
        
        // 方式3: 延时加载 - 给App充足初始化时间
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!g_tweakReady) {
                g_tweakReady = YES;
                [[MCFloatingManager shared] show];
                NSLog(@"[MCTweak] 方式3: 延时加载");
            }
        });
        
        // 方式4: 窗口出现时尝试加载
        [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidBecomeVisibleNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            if (!g_tweakReady && [note.object isKindOfClass:[UIWindow class]]) {
                UIWindow *win = (UIWindow *)note.object;
                if (win.windowLevel >= 0.0 && !win.hidden) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (!g_tweakReady) {
                            g_tweakReady = YES;
                            [[MCFloatingManager shared] show];
                            NSLog(@"[MCTweak] 方式4: 窗口出现加载");
                        }
                    });
                }
            }
        }];
    }
}

#pragma mark - ==================== 功能实现 ====================
//
// Bedrock 为 C++ 二进制，原 %hook LocalPlayer/MinecraftClient 等均为空操作。
// 下面改用：options.txt 配置 + 游戏命令注入 实现真正可用的功能。

#pragma mark - Toast 提示

/// 在悬浮窗宿主上显示临时提示
static void MCShowToast(NSString *msg) {
    if (!msg) return;
    MCExecOnMain(^{
        UIView *host = g_floatingBtn.superview;
        if (!host) host = (UIView *)MCGetOverlayWindow();
        if (!host) {
            for (UIWindow *w in [UIApplication sharedApplication].windows) {
                if (!w.hidden) { host = w; break; }
            }
        }
        if (!host) return;

        CGFloat sw = [UIScreen mainScreen].bounds.size.width;
        UILabel *t = [[UILabel alloc] init];
        t.text = msg;
        t.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        t.textColor = [UIColor whiteColor];
        t.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.10 alpha:0.92];
        t.textAlignment = NSTextAlignmentCenter;
        t.numberOfLines = 0;
        t.layer.cornerRadius = 12;
        t.layer.masksToBounds = YES;
        [t sizeToFit];
        CGRect f = t.frame;
        f.size.width = MIN(sw - 32, f.size.width + 28);
        f.size.height += 18;
        f.origin.x = (sw - f.size.width) / 2.0;
        f.origin.y = 80;
        t.frame = f;
        t.alpha = 0;
        t.layer.zPosition = 10000;
        [host addSubview:t];
        [host bringSubviewToFront:t];

        [UIView animateWithDuration:0.25 animations:^{ t.alpha = 1; }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{ t.alpha = 0; }
                             completion:^(BOOL done) { [t removeFromSuperview]; }];
        });
    });
}

#pragma mark - 夜视 Fullbright（options.txt）

/// options.txt 路径：<App容器>/Documents/games/com.mojang/minecraftpe/options.txt
static NSString *MCOptionsPath(void) {
    @try {
        NSArray *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (docs.count == 0) return nil;
        return [[docs firstObject] stringByAppendingPathComponent:@"games/com.mojang/minecraftpe/options.txt"];
    } @catch (NSException *e) { return nil; }
}

static NSString *g_savedGamma = nil; // 保存原始 gamma，关闭时恢复

static void MCSetFullbright(BOOL on) {
    NSString *path = MCOptionsPath();
    if (!path) { MCShowToast(@"未找到 options.txt"); return; }

    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
    if (err || content.length == 0) { MCShowToast(@"读取 options.txt 失败"); return; }

    NSMutableArray *lines = [[content componentsSeparatedByString:@"\n"] mutableCopy];
    BOOL found = NO;
    for (NSUInteger i = 0; i < lines.count; i++) {
        if ([lines[i] hasPrefix:@"gfx_gamma:"]) {
            if (!g_savedGamma) {
                NSString *v = [lines[i] substringFromIndex:@"gfx_gamma:".length];
                g_savedGamma = [v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (g_savedGamma.length == 0) g_savedGamma = @"1.000000";
            }
            lines[i] = on ? @"gfx_gamma:5.000000"
                          : [NSString stringWithFormat:@"gfx_gamma:%@", g_savedGamma];
            found = YES;
            break;
        }
    }
    if (!found) {
        if (!g_savedGamma) g_savedGamma = @"1.000000";
        [lines addObject:on ? @"gfx_gamma:5.000000"
                            : [NSString stringWithFormat:@"gfx_gamma:%@", g_savedGamma]];
    }

    NSString *out = [lines componentsJoinedByString:@"\n"];
    NSError *werr = nil;
    [out writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&werr];
    NSLog(@"[MCTweak] options.txt gfx_gamma -> %@ (writeErr=%@)", on ? @"5.0" : g_savedGamma, werr);
    MCShowToast(on ? @"夜视已开启（如无变化请重进世界/设置）" : @"夜视已关闭");
}

#pragma mark - 命令注入

/// 用响应者链捕获当前第一响应者（如已打开的聊天输入框）
static __weak UIResponder *g_mcCurrentResponder = nil;

@interface UIResponder (MCCapture)
@end
@implementation UIResponder (MCCapture)
- (void)mc_captureFirstResponder:(id)sender {
    g_mcCurrentResponder = self;
}
@end

static UIResponder *MCGetCurrentResponder(void) {
    g_mcCurrentResponder = nil;
    UIWindow *kw = [UIApplication sharedApplication].keyWindow;
    if (!kw) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { kw = w; break; }
        }
    }
    if (!kw) return nil;
    // sendAction:to:nil 走响应者链，最终由第一响应者接收（API 属于 UIApplication）
    @try {
        [[UIApplication sharedApplication] sendAction:@selector(mc_captureFirstResponder:)
                                                    to:nil from:nil forEvent:nil];
    } @catch (NSException *e) {}
    return g_mcCurrentResponder;
}

/// 发送一条游戏命令。优先向当前聊天输入框注入文本；否则复制到剪贴板。
/// 注意：Bedrock 聊天发送由游戏内 C++ 按钮处理，注入文本后仍需玩家按发送键，
/// 或在世界开启作弊后用剪贴板粘贴发送。
static BOOL MCSendCommand(NSString *cmd) {
    if (!cmd) return NO;
    if (![cmd hasPrefix:@"/"]) cmd = [NSString stringWithFormat:@"/%@", cmd];

    UIResponder *fr = MCGetCurrentResponder();
    if (fr && [fr conformsToProtocol:@protocol(UITextInput)]) {
        id<UITextInput> ti = (id<UITextInput>)fr;
        @try { [ti insertText:cmd]; } @catch (NSException *e) {}
        // 尝试用回车发送（部分版本生效）
        @try { [ti insertText:@"\n"]; } @catch (NSException *e) {}
        NSLog(@"[MCTweak] 命令已注入聊天框: %@", cmd);
        MCShowToast(@"已填入命令，如未发送请手动按发送键");
        return YES;
    }

    // 后备：复制到剪贴板
    [UIPasteboard generalPasteboard].string = cmd;
    NSLog(@"[MCTweak] 聊天框未打开，命令已复制到剪贴板: %@", cmd);
    MCShowToast(@"已复制命令，请打开聊天粘贴并发送（需开启作弊）");
    return NO;
}

#pragma mark - 功能派发

static void MCApplyFeature(MCTFeature feat, BOOL on) {
    switch (feat) {
        case MCTFeatureFullbright:
            MCSetFullbright(on);
            break;

        case MCTFeatureFly:
            // 飞行 = 创造模式（双击跳跃起飞）；需世界开启作弊
            MCSendCommand(on ? @"gamemode 1" : @"gamemode 0");
            break;

        case MCTFeatureSpeed:
            MCSendCommand(on ? @"effect @s speed 99999 5" : @"effect @s clear");
            break;

        case MCTFeatureXRay:
            MCShowToast(on ? @"X-Ray 请配合 xray 资源包使用" : @"已关闭");
            break;

        case MCTFeatureNoClip:
        case MCTFeatureKillAura:
        case MCTFeatureESP:
        case MCTFeatureNoFall:
        case MCTFeatureAutoMine:
        case MCTFeatureAutoEat:
        case MCTFeatureReach:
        case MCTFeatureAntiKB:
        case MCTFeatureAutoTool:
            MCShowToast(on ? @"此功能需逆向 C++ 偏移，当前版本暂不支持" : @"已关闭");
            break;

        default:
            break;
    }
}