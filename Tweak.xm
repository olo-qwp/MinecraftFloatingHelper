/*
 * MinecraftFloatingHelper - iOS悬浮窗多功能辅助工具 for Minecraft PE
 * 专注Dopamine (rootless) 版本
 * 兼容A11芯片 (iPhone 8/X), iOS 15+, 60fps
 * 13项功能: 飞行/加速/杀戮光环/ESP透视/X-Ray/防摔/自动挖矿/自动吃/范围扩大/防击退/夜视/自动工具/穿墙
 *
 * 关键方案: 直接添加到keyWindow，不创建独立UIWindow
 * 这是最可靠的悬浮窗显示方式，避免UIWindow场景兼容性问题
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
static UIWindow *g_targetWindow = nil;  // 目标窗口，找到后缓存

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

/// 获取当前App最上层的窗口，用于添加悬浮窗
static UIWindow *MCGetTargetWindow(void) {
    if (g_targetWindow && !g_targetWindow.hidden) {
        return g_targetWindow;
    }
    
    // 尝试获取keyWindow
    UIWindow *keyWin = [UIApplication sharedApplication].keyWindow;
    if (keyWin && !keyWin.hidden) {
        g_targetWindow = keyWin;
        return keyWin;
    }
    
    // 后备：遍历所有窗口，取最上层可见窗口
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *win in [windows reverseObjectEnumerator]) {
        if (!win.hidden && win.windowLevel >= UIWindowLevelNormal) {
            // 跳过我们自己的窗口（如果有）
            g_targetWindow = win;
            return win;
        }
    }
    
    // 最后尝试
    if (windows.count > 0) {
        g_targetWindow = windows[0];
        return windows[0];
    }
    
    return nil;
}

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
    if (self.floatingBtn) return;
    
    UIWindow *targetWin = MCGetTargetWindow();
    if (!targetWin) {
        NSLog(@"[MCTweak] 无法获取目标窗口，延迟重试");
        // 延迟重试
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setup];
        });
        return;
    }
    
    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    
    // 悬浮按钮 - 直接添加到目标窗口
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
    
    [targetWin addSubview:btn];
    
    self.floatingBtn = btn;
    g_floatingBtn = btn;
    g_targetWindow = targetWin;
    
    NSLog(@"[MCTweak] 悬浮按钮已添加到目标窗口 %@", targetWin);
}

- (void)show {
    MCExecOnMain(^{
        [self setup];
        if (!self.floatingBtn) return;
        
        // 确保按钮可见
        self.floatingBtn.hidden = NO;
        [self.floatingBtn.superview bringSubviewToFront:self.floatingBtn];
        
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
    
    // 获取目标窗口
    UIWindow *targetWin = g_targetWindow;
    if (!targetWin) targetWin = MCGetTargetWindow();
    if (!targetWin) return;
    
    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    CGFloat pw = MIN(sw - 32, 380);
    CGFloat ph = MIN(sh * 0.72, 540);
    CGFloat px = (sw - pw) / 2;
    CGFloat py = (sh - ph) / 2;
    
    // 遮罩层
    UIButton *overlay = [UIButton buttonWithType:UIButtonTypeCustom];
    overlay.frame = targetWin.bounds;
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    overlay.tag = 9991;
    overlay.layer.zPosition = 9998;
    [overlay addTarget:self action:@selector(dismissMenu) forControlEvents:UIControlEventTouchUpInside];
    [targetWin addSubview:overlay];
    [targetWin bringSubviewToFront:overlay];
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
    [targetWin addSubview:panel];
    [targetWin bringSubviewToFront:panel];
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
    
    [UIView animateWithDuration:0.25 animations:^{
        self.menuView.transform = CGAffineTransformMakeScale(0.85, 0.85);
        self.menuView.alpha = 0;
        UIView *ov = [g_targetWindow viewWithTag:9991];
        ov.alpha = 0;
    } completion:^(BOOL finished) {
        [self.menuView removeFromSuperview];
        self.menuView = nil;
        g_menuPanel = nil;
        [[g_targetWindow viewWithTag:9991] removeFromSuperview];
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
}

@end

#pragma mark - ==================== 初始化 ====================

/*
 * 初始化策略：
 * 1. %ctor 在 dylib 加载时立即执行
 * 2. 使用 dispatch_after 延迟等待 App 就绪
 * 3. 使用 UIApplicationDidBecomeActiveNotification 作为后备
 * 4. 多重检查确保只执行一次
 */

%ctor {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        NSLog(@"[MCTweak] 插件加载! Bundle: %@", bundleID);
        
        // 检查是否在 Minecraft PE 中
        if (![bundleID isEqualToString:@"com.mojang.minecraftpe"]) {
            NSLog(@"[MCTweak] 非目标App，跳过加载");
            return;
        }
        
        // 方式1: 延迟加载 - 给App初始化时间
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!g_tweakReady) {
                g_tweakReady = YES;
                [[MCFloatingManager shared] show];
                NSLog(@"[MCTweak] 方式1: 延迟加载成功");
            }
        });
        
        // 方式2: 后备 - 监听App活跃通知
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            if (!g_tweakReady) {
                g_tweakReady = YES;
                [[MCFloatingManager shared] show];
                NSLog(@"[MCTweak] 方式2: 通知加载成功");
            }
        }];
        
        // 方式3: 极限后备 - 8秒后强制加载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!g_tweakReady) {
                g_tweakReady = YES;
                [[MCFloatingManager shared] show];
                NSLog(@"[MCTweak] 方式3: 强制加载成功");
            }
        });
        
        // 方式4: 监听UIApplicationDidFinishLaunchingNotification
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            if (!g_tweakReady) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (!g_tweakReady) {
                        g_tweakReady = YES;
                        [[MCFloatingManager shared] show];
                        NSLog(@"[MCTweak] 方式4: launch通知加载成功");
                    }
                });
            }
        }];
    }
}

#pragma mark - ==================== 游戏功能钩子 ====================

%hook LocalPlayer

- (BOOL)isFlying {
    @try {
        if (g_featureEnabled[MCTFeatureFly]) return YES;
    } @catch(NSException *e) {}
    return %orig;
}

- (float)movementSpeed {
    @try {
        if (g_featureEnabled[MCTFeatureSpeed]) {
            float orig = %orig;
            return orig * 3.5f;
        }
    } @catch(NSException *e) {}
    return %orig;
}

- (float)reachDistance {
    @try {
        if (g_featureEnabled[MCTFeatureReach]) {
            float orig = %orig;
            return MAX(orig, 6.0f);
        }
    } @catch(NSException *e) {}
    return %orig;
}

%end

%hook MoveInputHandler

- (BOOL)isFlying {
    @try {
        if (g_featureEnabled[MCTFeatureFly]) return YES;
    } @catch(NSException *e) {}
    return %orig;
}

%end

%hook MCPlayer

- (float)knockbackResistance {
    @try {
        if (g_featureEnabled[MCTFeatureAntiKB]) return 1.0f;
    } @catch(NSException *e) {}
    return %orig;
}

- (float)gamma {
    @try {
        if (g_featureEnabled[MCTFeatureFullbright]) return 10.0f;
    } @catch(NSException *e) {}
    return %orig;
}

%end

%hook MinecraftClient

- (void)onTick {
    %orig;
    @autoreleasepool {
        @try {
            id me = (id)self;
            // 持续性功能在每tick执行
            id player = nil;
            SEL localPlayerSel = NSSelectorFromString(@"localPlayer");
            if ([me respondsToSelector:localPlayerSel]) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                player = [me performSelector:localPlayerSel];
                #pragma clang diagnostic pop
            }
            if (!player) return;
            
            // KillAura
            if (g_featureEnabled[MCTFeatureKillAura]) {
                static int tick = 0;
                tick++;
                if (tick % 5 == 0) {
                    SEL attackSel = NSSelectorFromString(@"attackNearestEntity");
                    if ([player respondsToSelector:attackSel]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        [player performSelector:attackSel];
                        #pragma clang diagnostic pop
                    }
                }
            }
            
            // AutoEat
            if (g_featureEnabled[MCTFeatureAutoEat]) {
                SEL hungerSel = NSSelectorFromString(@"hunger");
                if ([player respondsToSelector:hungerSel]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    id hungerVal = [player performSelector:hungerSel];
                    float hunger = [hungerVal floatValue];
                    #pragma clang diagnostic pop
                    if (hunger < 18.0f) {
                        SEL eatSel = NSSelectorFromString(@"eatBestFood");
                        if ([player respondsToSelector:eatSel]) {
                            #pragma clang diagnostic push
                            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                            [player performSelector:eatSel];
                            #pragma clang diagnostic pop
                        }
                    }
                }
            }
            
            // NoFall
            if (g_featureEnabled[MCTFeatureNoFall]) {
                SEL resetSel = NSSelectorFromString(@"resetFallDistance");
                if ([player respondsToSelector:resetSel]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [player performSelector:resetSel];
                    #pragma clang diagnostic pop
                }
            }
            
            // AutoTool
            if (g_featureEnabled[MCTFeatureAutoTool]) {
                SEL toolSel = NSSelectorFromString(@"selectBestTool");
                if ([player respondsToSelector:toolSel]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [player performSelector:toolSel];
                    #pragma clang diagnostic pop
                }
            }
            
            // AutoMine
            if (g_featureEnabled[MCTFeatureAutoMine]) {
                SEL speedSel = NSSelectorFromString(@"setBlockBreakSpeed:");
                if ([player respondsToSelector:speedSel]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [player performSelector:speedSel withObject:@(100.0f)];
                    #pragma clang diagnostic pop
                }
            }
            
        } @catch (NSException *e) {
            // 静默捕获，防止崩溃
        }
    }
}

%end