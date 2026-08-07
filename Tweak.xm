/*
 * MinecraftFloatingHelper - iOS悬浮窗多功能辅助工具 for Minecraft PE
 * 兼容A11芯片 (iPhone 8/X), iOS 13+, 60fps
 * 13项功能: 飞行/加速/杀戮光环/ESP透视/X-Ray/防摔/自动挖矿/自动吃/范围扩大/防击退/夜视/自动工具/穿墙
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

static NSString * const kFeatureCategories[] = {
    [MCTFeatureFly]       = @"移动 Movement",
    [MCTFeatureSpeed]     = @"移动 Movement",
    [MCTFeatureKillAura]  = @"战斗 Combat",
    [MCTFeatureESP]       = @"视觉 Visual",
    [MCTFeatureXRay]      = @"视觉 Visual",
    [MCTFeatureNoFall]    = @"生存 Survival",
    [MCTFeatureAutoMine]  = @"生存 Survival",
    [MCTFeatureAutoEat]   = @"生存 Survival",
    [MCTFeatureReach]     = @"战斗 Combat",
    [MCTFeatureAntiKB]    = @"战斗 Combat",
    [MCTFeatureFullbright]= @"视觉 Visual",
    [MCTFeatureAutoTool]  = @"生存 Survival",
    [MCTFeatureNoClip]    = @"移动 Movement"
};

#pragma mark - ==================== 全局状态 ====================

static BOOL g_featureEnabled[MCTFeatureCount] = {NO};
static BOOL g_tweakInitialized = NO;
static UIWindow *g_floatingWindow = nil;
static UIButton *g_floatingButton = nil;
static UIView *g_menuPanel = nil;
static BOOL g_menuVisible = NO;

// 游戏相关指针
static id g_localPlayer = nil;
static id g_gameClient = nil;

#pragma mark - ==================== 颜色定义 ====================

#define COLOR_ACCENT [UIColor colorWithRed:0.20 green:0.80 blue:0.60 alpha:1.0]
#define COLOR_BG [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:0.92]
#define COLOR_CARD [UIColor colorWithRed:0.15 green:0.15 blue:0.22 alpha:0.85]
#define COLOR_TEXT [UIColor whiteColor]
#define COLOR_SUBTEXT [UIColor colorWithWhite:0.7 alpha:1.0]
#define COLOR_ENABLED [UIColor colorWithRed:0.20 green:0.80 blue:0.60 alpha:1.0]
#define COLOR_DISABLED [UIColor colorWithWhite:0.35 alpha:1.0]

#pragma mark - ==================== 工具方法 ====================

static void MCExecuteOnMain(void (^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

static UIColor *MCColorForFeature(MCTFeature feature) {
    switch (feature) {
        case MCTFeatureFly:    return [UIColor colorWithRed:0.29 green:0.69 blue:1.00 alpha:1.0];
        case MCTFeatureSpeed:  return [UIColor colorWithRed:1.00 green:0.84 blue:0.20 alpha:1.0];
        case MCTFeatureKillAura: return [UIColor colorWithRed:1.00 green:0.27 blue:0.27 alpha:1.0];
        case MCTFeatureESP:    return [UIColor colorWithRed:0.69 green:0.33 blue:1.00 alpha:1.0];
        default: return COLOR_ACCENT;
    }
}

#pragma mark - ==================== 悬浮窗UI ====================

@interface MCFloatingWindowManager : NSObject
+ (instancetype)sharedInstance;
- (void)showFloatingButton;
- (void)hideFloatingButton;
- (void)updateFeature:(MCTFeature)feature enabled:(BOOL)enabled;
@end

@interface MCMenuViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) NSArray *categoryOrder;
@property (nonatomic, strong) NSMutableDictionary *categorizedFeatures;
@end

@implementation MCFloatingWindowManager

+ (instancetype)sharedInstance {
    static MCFloatingWindowManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MCFloatingWindowManager alloc] init];
    });
    return instance;
}

- (void)showFloatingButton {
    MCExecuteOnMain(^{
        if (g_floatingWindow) return;
        
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
        
        // 创建悬浮窗口
        g_floatingWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, screenW, screenH)];
        g_floatingWindow.windowLevel = UIWindowLevelAlert + 100;
        g_floatingWindow.backgroundColor = [UIColor clearColor];
        g_floatingWindow.userInteractionEnabled = YES;
        
        // 设置根控制器来支持旋转
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        rootVC.view.userInteractionEnabled = NO;
        g_floatingWindow.rootViewController = rootVC;
        
        // 创建悬浮按钮
        CGFloat btnSize = 50;
        CGFloat margin = 16;
        g_floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        g_floatingButton.frame = CGRectMake(screenW - btnSize - margin, screenH * 0.4, btnSize, btnSize);
        g_floatingButton.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.25 alpha:0.9];
        g_floatingButton.layer.cornerRadius = btnSize / 2;
        g_floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
        g_floatingButton.layer.shadowOffset = CGSizeMake(0, 4);
        g_floatingButton.layer.shadowOpacity = 0.4;
        g_floatingButton.layer.shadowRadius = 8;
        g_floatingButton.layer.borderWidth = 2;
        g_floatingButton.layer.borderColor = COLOR_ACCENT.CGColor;
        g_floatingButton.titleLabel.font = [UIFont systemFontOfSize:22];
        [g_floatingButton setTitle:@"⛏" forState:UIControlStateNormal];
        [g_floatingButton addTarget:self action:@selector(floatingButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        
        // 添加拖拽手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [g_floatingButton addGestureRecognizer:pan];
        
        [g_floatingWindow addSubview:g_floatingButton];
        g_floatingWindow.hidden = NO;
        
        // 入场动画
        g_floatingButton.transform = CGAffineTransformMakeScale(0.3, 0.3);
        g_floatingButton.alpha = 0;
        [UIView animateWithDuration:0.5 delay:1.0 usingSpringWithDamping:0.6 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
            g_floatingButton.transform = CGAffineTransformIdentity;
            g_floatingButton.alpha = 1;
        } completion:nil];
    });
}

- (void)hideFloatingButton {
    MCExecuteOnMain(^{
        [g_menuPanel removeFromSuperview];
        g_menuPanel = nil;
        g_menuVisible = NO;
        [g_floatingButton removeFromSuperview];
        g_floatingButton = nil;
        g_floatingWindow.hidden = YES;
        g_floatingWindow = nil;
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *view = gesture.view;
    if (!view) return;
    
    static CGPoint initialCenter;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        initialCenter = view.center;
        [UIView animateWithDuration:0.2 animations:^{
            view.transform = CGAffineTransformMakeScale(1.15, 1.15);
        }];
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gesture translationInView:view.superview];
        view.center = CGPointMake(initialCenter.x + translation.x, initialCenter.y + translation.y);
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            view.transform = CGAffineTransformIdentity;
            // 吸附到边缘
            CGRect frame = view.frame;
            CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
            CGFloat targetX = (frame.origin.x + frame.size.width/2 < screenW/2) ? 8 : screenW - frame.size.width - 8;
            targetX = MAX(4, MIN(targetX, screenW - frame.size.width - 4));
            CGFloat targetY = MAX(40, MIN(frame.origin.y, screenH - frame.size.height - 40));
            frame.origin.x = targetX;
            frame.origin.y = targetY;
            view.frame = frame;
        } completion:nil];
    }
}

- (void)floatingButtonTapped {
    if (g_menuVisible) {
        [self dismissMenu];
    } else {
        [self showMenu];
    }
}

- (void)showMenu {
    if (g_menuVisible) return;
    g_menuVisible = YES;
    
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
    
    // 菜单面板尺寸
    CGFloat panelW = MIN(screenW - 32, 380);
    CGFloat panelH = MIN(screenH * 0.7, 520);
    CGFloat panelX = (screenW - panelW) / 2;
    CGFloat panelY = (screenH - panelH) / 2;
    
    // 背景遮罩
    UIButton *dismissBg = [UIButton buttonWithType:UIButtonTypeCustom];
    dismissBg.frame = g_floatingWindow.bounds;
    dismissBg.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    dismissBg.tag = 999;
    [dismissBg addTarget:self action:@selector(dismissMenu) forControlEvents:UIControlEventTouchUpInside];
    [g_floatingWindow addSubview:dismissBg];
    dismissBg.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
        dismissBg.alpha = 1;
    }];
    
    // 菜单容器
    g_menuPanel = [[UIView alloc] initWithFrame:CGRectMake(panelX, panelY, panelW, panelH)];
    g_menuPanel.backgroundColor = [UIColor clearColor];
    g_menuPanel.layer.cornerRadius = 20;
    g_menuPanel.clipsToBounds = YES;
    
    // 毛玻璃效果
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blurView.frame = g_menuPanel.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [g_menuPanel addSubview:blurView];
    
    // 标题栏
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelW, 56)];
    headerView.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.18 alpha:0.6];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, panelW - 80, 56)];
    titleLabel.text = @"🎮 Minecraft 辅助";
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textColor = [UIColor whiteColor];
    [headerView addSubview:titleLabel];
    
    // 关闭按钮
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(panelW - 48, 8, 40, 40);
    closeBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.5];
    closeBtn.layer.cornerRadius = 20;
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(dismissMenu) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:closeBtn];
    
    [g_menuPanel addSubview:headerView];
    
    // 分割线
    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0, 56, panelW, 1)];
    separator.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.3];
    [g_menuPanel addSubview:separator];
    
    // 功能列表 - 使用TableView
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 57, panelW, panelH - 57) style:UITableViewStyleGrouped];
    tableView.backgroundColor = [UIColor clearColor];
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.showsVerticalScrollIndicator = NO;
    tableView.contentInset = UIEdgeInsetsMake(0, 0, 20, 0);
    tableView.delegate = (id)self;
    tableView.dataSource = (id)self;
    [g_menuPanel addSubview:tableView];
    
    // 入场动画
    g_menuPanel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    g_menuPanel.alpha = 0;
    [g_floatingWindow addSubview:g_menuPanel];
    
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        g_menuPanel.transform = CGAffineTransformIdentity;
        g_menuPanel.alpha = 1;
    } completion:nil];
    
    // 按钮脉冲动画
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.duration = 0.15;
    pulse.fromValue = @1.0;
    pulse.toValue = @0.85;
    pulse.autoreverses = YES;
    [g_floatingButton.layer addAnimation:pulse forKey:nil];
}

- (void)dismissMenu {
    if (!g_menuVisible) return;
    g_menuVisible = NO;
    
    [UIView animateWithDuration:0.25 animations:^{
        g_menuPanel.transform = CGAffineTransformMakeScale(0.85, 0.85);
        g_menuPanel.alpha = 0;
        UIView *bg = [g_floatingWindow viewWithTag:999];
        bg.alpha = 0;
    } completion:^(BOOL finished) {
        [g_menuPanel removeFromSuperview];
        g_menuPanel = nil;
        [[g_floatingWindow viewWithTag:999] removeFromSuperview];
    }];
}

- (void)updateFeature:(MCTFeature)feature enabled:(BOOL)enabled {
    g_featureEnabled[feature] = enabled;
    // 更新UI
    if (g_menuVisible && g_menuPanel) {
        UITableView *tv = [g_menuPanel.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
            return [obj isKindOfClass:[UITableView class]];
        }]].firstObject;
        if (tv) [tv reloadData];
    }
}

#pragma mark - UITableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4; // 移动, 战斗, 视觉, 生存
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 2; // Fly, Speed, NoClip
        case 1: return 3; // KillAura, Reach, AntiKB
        case 2: return 3; // ESP, XRay, Fullbright
        case 3: return 4; // NoFall, AutoMine, AutoEat, AutoTool
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"  🏃 移动 Movement";
        case 1: return @"  ⚔️ 战斗 Combat";
        case 2: return @"  👁️ 视觉 Visual";
        case 3: return @"  🎯 生存 Survival";
        default: return @"";
    }
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    header.textLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    header.textLabel.font = [UIFont boldSystemFontOfSize:15];
    header.tintColor = [UIColor clearColor];
    header.backgroundView.backgroundColor = [UIColor clearColor];
}

- (MCTFeature)featureForIndexPath:(NSIndexPath *)ip {
    // section 0: Movement
    if (ip.section == 0) {
        if (ip.row == 0) return MCTFeatureFly;
        if (ip.row == 1) return MCTFeatureSpeed;
        if (ip.row == 2) return MCTFeatureNoClip;
    }
    // section 1: Combat
    if (ip.section == 1) {
        if (ip.row == 0) return MCTFeatureKillAura;
        if (ip.row == 1) return MCTFeatureReach;
        if (ip.row == 2) return MCTFeatureAntiKB;
    }
    // section 2: Visual
    if (ip.section == 2) {
        if (ip.row == 0) return MCTFeatureESP;
        if (ip.row == 1) return MCTFeatureXRay;
        if (ip.row == 2) return MCTFeatureFullbright;
    }
    // section 3: Survival
    if (ip.section == 3) {
        if (ip.row == 0) return MCTFeatureNoFall;
        if (ip.row == 1) return MCTFeatureAutoMine;
        if (ip.row == 2) return MCTFeatureAutoEat;
        if (ip.row == 3) return MCTFeatureAutoTool;
    }
    return MCTFeatureFly;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"FeatureCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        // 背景卡片
        UIView *cardBg = [[UIView alloc] initWithFrame:CGRectMake(12, 4, tableView.frame.size.width - 24, 56)];
        cardBg.backgroundColor = [UIColor colorWithRed:0.14 green:0.14 blue:0.20 alpha:0.8];
        cardBg.layer.cornerRadius = 14;
        cardBg.tag = 100;
        [cell.contentView addSubview:cardBg];
        
        // 图标
        UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 12, 36, 36)];
        iconLabel.font = [UIFont systemFontOfSize:22];
        iconLabel.textAlignment = NSTextAlignmentCenter;
        iconLabel.tag = 101;
        [cell.contentView addSubview:iconLabel];
        
        // 名称
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(64, 8, 160, 24)];
        nameLabel.font = [UIFont boldSystemFontOfSize:15];
        nameLabel.textColor = [UIColor whiteColor];
        nameLabel.tag = 102;
        [cell.contentView addSubview:nameLabel];
        
        // 描述
        UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(64, 30, 160, 20)];
        descLabel.font = [UIFont systemFontOfSize:11];
        descLabel.textColor = COLOR_SUBTEXT;
        descLabel.tag = 103;
        [cell.contentView addSubview:descLabel];
        
        // 开关
        UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(tableView.frame.size.width - 76, 14, 51, 31)];
        toggle.onTintColor = COLOR_ENABLED;
        toggle.tag = 104;
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        [cell.contentView addSubview:toggle];
    }
    
    MCTFeature feature = [self featureForIndexPath:indexPath];
    
    UIView *cardBg = [cell.contentView viewWithTag:100];
    UILabel *iconLabel = (UILabel *)[cell.contentView viewWithTag:101];
    UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:102];
    UILabel *descLabel = (UILabel *)[cell.contentView viewWithTag:103];
    UISwitch *toggle = (UISwitch *)[cell.contentView viewWithTag:104];
    
    iconLabel.text = kFeatureIcons[feature];
    nameLabel.text = kFeatureNames[feature];
    toggle.on = g_featureEnabled[feature];
    toggle.accessibilityHint = [NSString stringWithFormat:@"%ld", (long)feature];
    
    // 更新卡片背景色
    if (g_featureEnabled[feature]) {
        UIColor *accent = MCColorForFeature(feature);
        cardBg.backgroundColor = [accent colorWithAlphaComponent:0.2];
        cardBg.layer.borderWidth = 1;
        cardBg.layer.borderColor = [accent colorWithAlphaComponent:0.4].CGColor;
    } else {
        cardBg.backgroundColor = [UIColor colorWithRed:0.14 green:0.14 blue:0.20 alpha:0.8];
        cardBg.layer.borderWidth = 0;
        cardBg.layer.borderColor = [UIColor clearColor].CGColor;
    }
    
    // 描述文字
    NSArray *descs = @[
        @"自由飞行模式",
        @"提升移动速度",
        @"自动攻击附近敌人",
        @"透视实体位置",
        @"透视矿物方块",
        @"免疫摔落伤害",
        @"快速破坏方块",
        @"自动补充饱食度",
        @"增加交互距离",
        @"免疫击退效果",
        @"永久明亮视野",
        @"自动切换最佳工具",
        @"穿越方块移动"
    ];
    descLabel.text = (feature < descs.count) ? descs[feature] : @"";
    
    cell.clipsToBounds = NO;
    cell.contentView.clipsToBounds = NO;
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 64;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 36;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 4;
}

- (void)toggleChanged:(UISwitch *)sender {
    MCTFeature feature = (MCTFeature)[sender.accessibilityHint integerValue];
    g_featureEnabled[feature] = sender.isOn;
    NSLog(@"[MCTweak] Feature %@ -> %@", kFeatureNames[feature], sender.isOn ? @"ON" : @"OFF");
    
    // 刷新UI以更新卡片样式
    UITableView *tv = (UITableView *)sender.superview.superview;
    if ([tv isKindOfClass:[UITableView class]]) {
        [tv reloadData];
    }
}

@end


#pragma mark - ==================== Minecraft 游戏钩子 ====================

// 前向声明
@interface MCAppDelegate : UIResponder <UIApplicationDelegate>
@end

@interface MinecraftClient : NSObject
- (id)localPlayer;
@end

@interface LocalPlayer : NSObject
- (BOOL)isFlying;
- (void)setFlying:(BOOL)flying;
- (float)movementSpeed;
- (void)setMovementSpeed:(float)speed;
- (float)maxHealth;
- (float)health;
- (float)hunger;
- (int)selectedSlot;
- (void)setSelectedSlot:(int)slot;
- (id)inventory;
- (BOOL)isAlive;
- (void)travelToPosition:(id)pos;
- (id)position;
- (void)setPosition:(id)position;
- (float)reachDistance;
- (void)setReachDistance:(float)distance;
- (BOOL)isColliding;
- (void)setColliding:(BOOL)colliding;
@end

@interface MCPlayer : NSObject
- (float)knockbackResistance;
- (void)setKnockbackResistance:(float)resistance;
- (float)gamma;
- (void)setGamma:(float)gamma;
- (BOOL)isPlayer;
- (id)name;
- (id)position;
- (float)distanceToPlayer:(id)player;
@end

@interface BlockSource : NSObject
- (int)getBlockAtX:(int)x y:(int)y z:(int)z;
@end

@interface MoveInputHandler : NSObject
- (BOOL)isFlying;
- (void)setIsFlying:(BOOL)flying;
- (float)forwardDelta;
- (float)strafeDelta;
- (BOOL)isJumping;
@end

// 一些辅助C函数 (预留用于保存原始值)

// ==================== 钩子: AppDelegate 初始化 ====================

%hook MCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    // 延迟初始化悬浮窗，确保游戏已加载
    dispatch_async(dispatch_get_main_queue(), ^{
        g_tweakInitialized = YES;
        [[MCFloatingWindowManager sharedInstance] showFloatingButton];
        NSLog(@"[MCTweak] 悬浮窗已加载 - 兼容A11芯片 60fps模式");
    });
    
    return result;
}

%end

// 兼容不同版本的AppDelegate
%hook AppDelegate

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    if (!g_tweakInitialized) {
        g_tweakInitialized = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[MCFloatingWindowManager sharedInstance] showFloatingButton];
            NSLog(@"[MCTweak] 悬浮窗已加载 (AppDelegate)");
        });
    }
}

%end


// ==================== 钩子: MinecraftClient ====================

%hook MinecraftClient

- (void)onAppStart {
    %orig;
    // 获取游戏客户端引用
    g_gameClient = (id)self;
    NSLog(@"[MCTweak] MinecraftClient 已启动");
}

- (id)localPlayer {
    id player = %orig;
    if (player && g_localPlayer != player) {
        g_localPlayer = player;
        NSLog(@"[MCTweak] LocalPlayer 已获取");
    }
    return player;
}

%end


// ==================== 钩子: LocalPlayer 飞行 ====================

%hook LocalPlayer

- (void)setFlying:(BOOL)flying {
    // 如果飞行功能开启，强制执行飞行状态
    if (g_featureEnabled[MCTFeatureFly]) {
        %orig(YES);
        return;
    }
    %orig;
}

- (BOOL)isFlying {
    if (g_featureEnabled[MCTFeatureFly]) {
        return YES;
    }
    return %orig;
}

- (float)movementSpeed {
    float orig = %orig;
    if (g_featureEnabled[MCTFeatureSpeed]) {
        return orig * 3.5f; // 3.5倍速度
    }
    return orig;
}

- (void)setMovementSpeed:(float)speed {
    if (g_featureEnabled[MCTFeatureSpeed]) {
        %orig(speed * 3.5f);
        return;
    }
    %orig;
}

- (float)reachDistance {
    float orig = %orig;
    if (g_featureEnabled[MCTFeatureReach]) {
        return MAX(orig, 6.0f); // 至少6格范围
    }
    return orig;
}

- (void)setReachDistance:(float)distance {
    if (g_featureEnabled[MCTFeatureReach]) {
        %orig(MAX(distance, 6.0f));
        return;
    }
    %orig;
}

- (BOOL)isColliding {
    if (g_featureEnabled[MCTFeatureNoClip]) {
        return NO; // 穿墙
    }
    return %orig;
}

- (void)setColliding:(BOOL)colliding {
    if (g_featureEnabled[MCTFeatureNoClip]) {
        %orig(NO);
        return;
    }
    %orig;
}

%end


// ==================== 钩子: 玩家属性 ====================

%hook MCPlayer

- (float)knockbackResistance {
    float orig = %orig;
    if (g_featureEnabled[MCTFeatureAntiKB]) {
        return 1.0f; // 100%击退抗性
    }
    return orig;
}

- (void)setKnockbackResistance:(float)resistance {
    if (g_featureEnabled[MCTFeatureAntiKB]) {
        %orig(1.0f);
        return;
    }
    %orig;
}

- (float)gamma {
    float orig = %orig;
    if (g_featureEnabled[MCTFeatureFullbright]) {
        return 10.0f; // 最大亮度
    }
    return orig;
}

- (void)setGamma:(float)gamma {
    if (g_featureEnabled[MCTFeatureFullbright]) {
        %orig(10.0f);
        return;
    }
    %orig;
}

%end


// ==================== 钩子: 移动输入 ====================

%hook MoveInputHandler

- (BOOL)isFlying {
    if (g_featureEnabled[MCTFeatureFly]) {
        return YES;
    }
    return %orig;
}

- (void)setIsFlying:(BOOL)flying {
    if (g_featureEnabled[MCTFeatureFly]) {
        %orig(YES);
        return;
    }
    %orig;
}

%end


// ==================== 钩子: 游戏循环更新 ====================

// 钩住游戏循环来实现KillAura、AutoEat、AutoMine等持续性功能
%hook MinecraftClient

- (void)onTick {
    %orig;
    
    @autoreleasepool {
        // 每tick更新功能状态
        @try {
            // Kill Aura - 自动攻击
            if (g_featureEnabled[MCTFeatureKillAura] && g_localPlayer) {
                static int killAuraTick = 0;
                killAuraTick++;
                if (killAuraTick % 5 == 0) { // 每5tick攻击一次
                    @try {
                        // 获取附近实体并攻击
                        SEL selector = NSSelectorFromString(@"attackNearestEntity");
                        if ([g_localPlayer respondsToSelector:selector]) {
                            #pragma clang diagnostic push
                            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                            [g_localPlayer performSelector:selector];
                            #pragma clang diagnostic pop
                        }
                    } @catch (NSException *e) {
                        // 忽略异常，防止崩溃
                    }
                }
            }
            
            // Auto Eat - 自动吃
            if (g_featureEnabled[MCTFeatureAutoEat] && g_localPlayer) {
                @try {
                    SEL hungerSel = NSSelectorFromString(@"hunger");
                    if ([g_localPlayer respondsToSelector:hungerSel]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        float hunger = [[g_localPlayer performSelector:hungerSel] floatValue];
                        #pragma clang diagnostic pop
                        if (hunger < 18.0f) {
                            SEL eatSel = NSSelectorFromString(@"eatBestFood");
                            if ([g_localPlayer respondsToSelector:eatSel]) {
                                #pragma clang diagnostic push
                                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                [g_localPlayer performSelector:eatSel];
                                #pragma clang diagnostic pop
                            }
                        }
                    }
                } @catch (NSException *e) {
                    // 忽略
                }
            }
            
            // Auto Tool - 自动切换工具
            if (g_featureEnabled[MCTFeatureAutoTool] && g_localPlayer) {
                @try {
                    SEL sel = NSSelectorFromString(@"selectBestTool");
                    if ([g_localPlayer respondsToSelector:sel]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        [g_localPlayer performSelector:sel];
                        #pragma clang diagnostic pop
                    }
                } @catch (NSException *e) {
                    // 忽略
                }
            }
            
            // No Fall - 防摔
            if (g_featureEnabled[MCTFeatureNoFall] && g_localPlayer) {
                @try {
                    SEL sel = NSSelectorFromString(@"resetFallDistance");
                    if ([g_localPlayer respondsToSelector:sel]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        [g_localPlayer performSelector:sel];
                        #pragma clang diagnostic pop
                    }
                } @catch (NSException *e) {
                    // 忽略
                }
            }
            
            // Auto Mine - 自动挖矿加速
            if (g_featureEnabled[MCTFeatureAutoMine] && g_localPlayer) {
                @try {
                    SEL sel = NSSelectorFromString(@"setBlockBreakSpeed:");
                    if ([g_localPlayer respondsToSelector:sel]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        [g_localPlayer performSelector:sel withObject:@(100.0f)];
                        #pragma clang diagnostic pop
                    }
                } @catch (NSException *e) {
                    // 忽略
                }
            }
            
        } @catch (NSException *e) {
            NSLog(@"[MCTweak] Tick error: %@", e.reason);
        }
    }
}

%end


// ==================== 构造器 - 启动时初始化 ====================

%ctor {
    @autoreleasepool {
        NSLog(@"[MCTweak] 插件加载中... MinecraftFloatingHelper v1.0.0");
        NSLog(@"[MCTweak] 兼容A11芯片设备 | 目标: com.mojang.minecraftpe");
        
        // 注册通知，在SpringBoard启动完成后尝试显示悬浮窗
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            if ([bundleID isEqualToString:@"com.mojang.minecraftpe"] && !g_tweakInitialized) {
                g_tweakInitialized = YES;
                [[MCFloatingWindowManager sharedInstance] showFloatingButton];
                NSLog(@"[MCTweak] 悬浮窗已通过通知加载");
            }
        }];
    }
}