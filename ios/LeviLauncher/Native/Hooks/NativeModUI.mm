#import "NativeModUI.h"

#import <UIKit/UIKit.h>

#include "UIHook.h"
#include "../InbuiltMods/FpsMod.hpp"
#include "../InbuiltMods/SnaplookMod.hpp"
#include "../InbuiltMods/ZoomMod.hpp"
#include "../InbuiltMods/CreatePort.hpp"
#include "../InbuiltMods/AetherPort.hpp"
#include "../InbuiltMods/TwilightForestPort.hpp"
#include "../Preloader/Preloader.hpp"

static const NSInteger kModsButtonTag = 0x4C4D4F44;
static __weak UIViewController *g_gameViewController = nil;
static __weak UIView *g_gameView = nil;
static __weak UILabel *g_fpsLabel = nil;
static CADisplayLink *g_fpsDisplayLink = nil;

static UIColor *mcBackground() {
    return [UIColor colorWithRed:0.10 green:0.10 blue:0.10 alpha:0.97];
}

static UIColor *mcCell() {
    return [UIColor colorWithRed:0.22 green:0.22 blue:0.22 alpha:1.0];
}

static UIColor *mcBorder() {
    return [UIColor colorWithWhite:0.04 alpha:1.0];
}

static UIColor *mcGreen() {
    return [UIColor colorWithRed:0.32 green:0.68 blue:0.24 alpha:1.0];
}

static UIFont *mcFont(CGFloat size) {
    return [UIFont fontWithName:@"Menlo-Bold" size:size] ?: [UIFont boldSystemFontOfSize:size];
}

static NSString *builtinPreferenceKey(NSInteger index) {
    NSArray<NSString *> *keys = @[
        @"LeviBuiltinFps", @"LeviBuiltinZoom", @"LeviBuiltinSnaplook",
        @"LeviBuiltinCreatePort", @"LeviBuiltinAetherPort", @"LeviBuiltinTwilightForestPort"
    ];
    return index >= 0 && index < (NSInteger)keys.count ? keys[index] : nil;
}

static void styleLabel(UILabel *label, CGFloat size) {
    label.font = mcFont(size);
    label.textColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    label.shadowColor = [UIColor blackColor];
    label.shadowOffset = CGSizeMake(1.0, 1.0);
}

static void styleTableController(UITableViewController *controller, NSString *title) {
    controller.title = title;
    controller.tableView.backgroundColor = mcBackground();
    controller.tableView.separatorColor = mcBorder();
    controller.tableView.sectionHeaderTopPadding = 10.0;
    NSDictionary<NSAttributedStringKey, id> *titleAttributes = @{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: mcFont(16.0)
    };
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.16 alpha:1.0];
    appearance.shadowColor = mcBorder();
    appearance.titleTextAttributes = titleAttributes;

    UINavigationBar *navigationBar = controller.navigationController.navigationBar;
    navigationBar.barStyle = UIBarStyleBlack;
    navigationBar.tintColor = [UIColor whiteColor];
    navigationBar.standardAppearance = appearance;
    navigationBar.scrollEdgeAppearance = appearance;
    navigationBar.compactAppearance = appearance;
}

static void setBuiltinEnabled(NSInteger index, BOOL enabled) {
    switch (index) {
        case 0: FpsMod::setEnabled(enabled == YES); break;
        case 1: ZoomMod::setEnabled(enabled == YES); break;
        case 2: SnaplookMod::setEnabled(enabled == YES); break;
        case 3: CreatePort::setEnabled(enabled == YES); break;
        case 4: AetherPort::setEnabled(enabled == YES); break;
        case 5: TwilightForestPort::setEnabled(enabled == YES); break;
        default: break;
    }
    NSString *key = builtinPreferenceKey(index);
    if (key) [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:key];
}

static BOOL isBuiltinEnabled(NSInteger index) {
    switch (index) {
        case 0: return FpsMod::isEnabled() ? YES : NO;
        case 1: return ZoomMod::isEnabled() ? YES : NO;
        case 2: return SnaplookMod::isEnabled() ? YES : NO;
        case 3: return CreatePort::isEnabled() ? YES : NO;
        case 4: return AetherPort::isEnabled() ? YES : NO;
        case 5: return TwilightForestPort::isEnabled() ? YES : NO;
        default: return NO;
    }
}

static NSArray<NSDictionary<NSString *, NSString *> *> *builtinMods() {
    return @[
        @{@"name": @"FPS Counter", @"detail": @"Show frames per second while playing",
          @"icon": @"number.square.fill"},
        @{@"name": @"Zoom", @"detail": @"Enable the native zoom hook",
          @"icon": @"magnifyingglass"},
        @{@"name": @"Snaplook", @"detail": @"Enable quick-look camera controls",
          @"icon": @"arrow.triangle.2.circlepath"},
        @{@"name": @"Create Port",
          @"detail": [NSString stringWithFormat:@"Prototype: %zu registry entries", CreatePort::contentCount()],
          @"icon": @"gearshape.2.fill"},
        @{@"name": @"Aether Port",
          @"detail": [NSString stringWithFormat:@"Prototype: %zu entries with a sky dimension", AetherPort::contentCount()],
          @"icon": @"cloud.sun.fill"},
        @{@"name": @"Twilight Forest Port",
          @"detail": [NSString stringWithFormat:@"Prototype: %zu entries with bosses and structures", TwilightForestPort::contentCount()],
          @"icon": @"tree.fill"}
    ];
}

@interface LLFpsDisplayTarget : NSObject
- (void)tick:(CADisplayLink *)displayLink;
@end

static LLFpsDisplayTarget *g_fpsTarget = nil;

@implementation LLFpsDisplayTarget
- (void)tick:(CADisplayLink *)displayLink {
    (void)displayLink;
    g_fpsLabel.text = [NSString stringWithFormat:@"%d FPS", FpsMod::getFps()];
}
@end

static void refreshFpsOverlay() {
    [g_fpsDisplayLink invalidate];
    g_fpsDisplayLink = nil;
    [g_fpsLabel removeFromSuperview];
    g_fpsLabel = nil;

    UIView *gameView = g_gameView;
    if (!gameView || !FpsMod::isEnabled()) return;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"0 FPS";
    label.textColor = [UIColor colorWithRed:0.95 green:0.92 blue:0.20 alpha:1.0];
    label.font = mcFont(14.0);
    label.shadowColor = [UIColor blackColor];
    label.shadowOffset = CGSizeMake(1.0, 1.0);
    [gameView addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:gameView.safeAreaLayoutGuide.leadingAnchor
                                           constant:10.0],
        [label.topAnchor constraintEqualToAnchor:gameView.safeAreaLayoutGuide.topAnchor
                                         constant:10.0]
    ]];
    g_fpsLabel = label;

    g_fpsTarget = [[LLFpsDisplayTarget alloc] init];
    g_fpsDisplayLink = [CADisplayLink displayLinkWithTarget:g_fpsTarget selector:@selector(tick:)];
    [g_fpsDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

static UITableViewCell *modCell(UITableView *tableView,
                                NSIndexPath *indexPath,
                                id target,
                                SEL action) {
    NSDictionary<NSString *, NSString *> *mod = builtinMods()[indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                   reuseIdentifier:nil];
    cell.backgroundColor = mcCell();
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = mod[@"name"];
    styleLabel(cell.textLabel, 13.0);
    cell.detailTextLabel.text = mod[@"detail"];
    cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:10.0] ?:
        [UIFont systemFontOfSize:10.0];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.67 alpha:1.0];
    cell.imageView.image = [UIImage systemImageNamed:mod[@"icon"]];
    cell.imageView.tintColor = mcGreen();

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.tag = indexPath.row;
    toggle.on = isBuiltinEnabled(indexPath.row);
    toggle.onTintColor = mcGreen();
    [toggle addTarget:target action:action forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

@interface LLNativeSettingsViewController : UITableViewController
@end

@implementation LLNativeSettingsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    styleTableController(self, @"Minecraft Settings");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? builtinMods().count : 4;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? @"MODDED" : @"LEVI INFO";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return modCell(tableView, indexPath, self, @selector(toggleChanged:));
    }

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                    reuseIdentifier:nil];
    cell.backgroundColor = mcCell();
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    styleLabel(cell.textLabel, 12.0);
    cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:11.0] ?:
        [UIFont systemFontOfSize:11.0];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.68 alpha:1.0];

    if (indexPath.row == 0) {
        cell.textLabel.text = @"Minecraft";
        cell.detailTextLabel.text = [NSString stringWithUTF8String:Preloader::minecraftVersion()];
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"Mod Injection";
        cell.detailTextLabel.text = @"ACTIVE";
        cell.detailTextLabel.textColor = mcGreen();
    } else if (indexPath.row == 2) {
        cell.textLabel.text = @"Prototype Entries";
        const std::size_t total = CreatePort::contentCount() + AetherPort::contentCount() +
            TwilightForestPort::contentCount();
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%zu", total];
    } else {
        cell.textLabel.text = @"Loaded Mods";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%zu", Preloader::getModCount()];
    }
    return cell;
}

- (void)toggleChanged:(UISwitch *)sender {
    setBuiltinEnabled(sender.tag, sender.isOn);
    refreshFpsOverlay();
}

@end

@interface LLNativeModsViewController : UITableViewController
@end


@implementation LLNativeModsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    styleTableController(self, @"Mods");
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Close"
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(close)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape.fill"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(openSettings)];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = @"Minecraft Settings";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    if (section == 0) return builtinMods().count;
    return MAX((NSInteger)Preloader::getModCount(), 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? @"BUILT-IN MODS" : @"LOADED MODS";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return modCell(tableView, indexPath, self, @selector(toggleChanged:));
    }

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                    reuseIdentifier:nil];
    cell.backgroundColor = mcCell();
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    styleLabel(cell.textLabel, 13.0);

    const size_t count = Preloader::getModCount();
    if (count == 0) {
        cell.textLabel.text = @"No external mods loaded";
        cell.detailTextLabel.text = @"Install mods before launching Minecraft";
        cell.imageView.image = [UIImage systemImageNamed:@"shippingbox"];
        cell.imageView.tintColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    } else {
        const std::string info = Preloader::getModInfo((size_t)indexPath.row);
        NSString *record = [NSString stringWithUTF8String:info.c_str()] ?: @"";
        NSArray<NSString *> *parts = [record componentsSeparatedByString:@"|"];
        NSString *identifier = parts.count > 0 ? parts[0] : @"Unknown mod";
        NSString *name = parts.count > 1 && parts[1].length > 0 ? parts[1] :
            identifier.lastPathComponent;
        NSString *version = parts.count > 2 ? parts[2] : @"";
        NSString *author = parts.count > 3 ? parts[3] : @"";
        cell.textLabel.text = name;
        if (author.length > 0 && version.length > 0) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  |  %@", author, version];
        } else if (author.length > 0 || version.length > 0) {
            cell.detailTextLabel.text = author.length > 0 ? author : version;
        } else {
            cell.detailTextLabel.text = @"Native ARM64 mod loaded";
        }
        cell.imageView.image = [UIImage systemImageNamed:@"checkmark.square.fill"];
        cell.imageView.tintColor = mcGreen();
    }
    cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:10.0] ?:
        [UIFont systemFontOfSize:10.0];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    return cell;
}

- (void)toggleChanged:(UISwitch *)sender {
    setBuiltinEnabled(sender.tag, sender.isOn);
    refreshFpsOverlay();
}

- (void)openSettings {
    [self.navigationController pushViewController:[[LLNativeSettingsViewController alloc] init]
                                         animated:YES];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface LLModsButtonTarget : NSObject
- (void)openMods:(UIButton *)sender;
@end

static LLModsButtonTarget *g_buttonTarget = nil;

static UIViewController *topViewController(UIViewController *controller) {
    UIViewController *top = controller;
    while (top.presentedViewController) top = top.presentedViewController;
    if ([top isKindOfClass:[UINavigationController class]]) {
        return topViewController(((UINavigationController *)top).visibleViewController);
    }
    if ([top isKindOfClass:[UITabBarController class]]) {
        return topViewController(((UITabBarController *)top).selectedViewController);
    }
    return top;
}

@implementation LLModsButtonTarget
- (void)openMods:(UIButton *)sender {
    (void)sender;
    UIViewController *presenter = topViewController(g_gameViewController);
    if (!presenter || [presenter isKindOfClass:[LLNativeModsViewController class]] ||
        [presenter.navigationController.viewControllers.firstObject
            isKindOfClass:[LLNativeModsViewController class]]) {
        return;
    }

    LLNativeModsViewController *mods = [[LLNativeModsViewController alloc] init];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:mods];
    navigation.modalPresentationStyle = UIModalPresentationOverFullScreen;
    navigation.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [presenter presentViewController:navigation animated:YES completion:nil];
}
@end

static void installModsButton(UIViewController *gameViewController, UIView *gameView) {
    if (!gameViewController || !gameView) return;

    g_gameViewController = gameViewController;
    g_gameView = gameView;
    if ([gameView viewWithTag:kModsButtonTag]) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.tag = kModsButtonTag;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithRed:0.38 green:0.38 blue:0.38 alpha:0.96];
    button.layer.borderWidth = 2.0;
    button.layer.borderColor = mcBorder().CGColor;
    button.layer.cornerRadius = 2.0;
    button.layer.shadowColor = [UIColor blackColor].CGColor;
    button.layer.shadowOffset = CGSizeMake(0.0, 3.0);
    button.layer.shadowOpacity = 0.8;
    button.layer.shadowRadius = 0.0;
    button.titleLabel.font = mcFont(14.0);
    button.tintColor = [UIColor whiteColor];
    button.accessibilityLabel = @"Mods";
    button.accessibilityHint = @"Opens the native Minecraft mods screen";
    [button setTitle:@"  MODS" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithWhite:0.75 alpha:1.0]
                 forState:UIControlStateHighlighted];
    [button setImage:[UIImage systemImageNamed:@"shippingbox.fill"] forState:UIControlStateNormal];
    [button setBackgroundImage:nil forState:UIControlStateNormal];

    g_buttonTarget = [[LLModsButtonTarget alloc] init];
    [button addTarget:g_buttonTarget action:@selector(openMods:) forControlEvents:UIControlEventTouchUpInside];
    [gameView addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:gameView.safeAreaLayoutGuide.trailingAnchor
                                             constant:-12.0],
        [button.topAnchor constraintEqualToAnchor:gameView.safeAreaLayoutGuide.topAnchor
                                          constant:8.0],
        [button.widthAnchor constraintEqualToConstant:116.0],
        [button.heightAnchor constraintEqualToConstant:42.0]
    ]];

    CALayer *highlight = [CALayer layer];
    highlight.backgroundColor = [UIColor colorWithWhite:0.72 alpha:0.8].CGColor;
    highlight.frame = CGRectMake(2.0, 2.0, 112.0, 2.0);
    [button.layer addSublayer:highlight];
    refreshFpsOverlay();
}

namespace NativeModUI {

void initialize() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSInteger index = 0; index < (NSInteger)builtinMods().count; ++index) {
        NSString *key = builtinPreferenceKey(index);
        NSNumber *stored = key ? [defaults objectForKey:key] : nil;
        if (stored && stored.boolValue != isBuiltinEnabled(index)) {
            setBuiltinEnabled(index, stored.boolValue);
        }
    }

    UIHook::onViewDidLoad([](void *viewController, void *view) {
        UIViewController *controller = (__bridge UIViewController *)viewController;
        UIView *gameView = (__bridge UIView *)view;
        dispatch_block_t install = ^{
            installModsButton(controller, gameView);
        };
        if ([NSThread isMainThread]) install();
        else dispatch_async(dispatch_get_main_queue(), install);
    });
}

} // namespace NativeModUI
