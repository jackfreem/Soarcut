//
//  StarPrompt.m
//  Soarcut
//

#import "StarPrompt.h"

// Separate keys, as in T3 Code, so the paste count can never undo a dismissal.
static NSString *const StarPromptPasteCountKey = @"starPromptPasteCount";
static NSString *const StarPromptDismissedKey = @"starPromptDismissed";
static NSString *const StarPromptRepositoryURL = @"https://github.com/jackfreem/Soarcut";

// Pastes are cheaper than T3 Code's prompts, so the bar is higher than its 5.
static const NSInteger StarPromptPastesBeforeAsking = 20;
// T3 Code's toast stays inside its own window until closed. This panel floats over
// other apps, so an ignored prompt hides itself and may come back on a later launch.
static const NSTimeInterval StarPromptVisibleSeconds = 15;
// Lets the paste (sent 0.2s after the choice) land before the panel appears.
static const NSTimeInterval StarPromptDelayAfterPaste = 0.5;

static const CGFloat StarPromptWidth = 340;
static const CGFloat StarPromptHeight = 98;
static const CGFloat StarPromptCornerRadius = 10;

@class StarPromptPanel;
static BOOL shownThisLaunch = NO;
static StarPromptPanel *visiblePanel = nil;

static void StarPromptSaveDismissal(void)
{
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:StarPromptDismissedKey];
}

// The panel never becomes key, so buttons must take the first click.
@interface StarPromptButton : NSButton
@end

@implementation StarPromptButton
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
@end

@protocol StarPromptHoverDelegate
- (void)mouseDidEnterPrompt;
- (void)mouseDidExitPrompt;
@end

// Pauses the auto-hide while the pointer is over the prompt.
@interface StarPromptContentView : NSVisualEffectView {
	id<StarPromptHoverDelegate> hoverDelegate; // not retained; the panel owns this view
}
- (void)setHoverDelegate:(id<StarPromptHoverDelegate>)delegate;
@end

@implementation StarPromptContentView
- (void)setHoverDelegate:(id<StarPromptHoverDelegate>)delegate { hoverDelegate = delegate; }
- (void)updateTrackingAreas
{
	[super updateTrackingAreas];
	for (NSTrackingArea *area in [[self.trackingAreas copy] autorelease])
		[self removeTrackingArea:area];
	NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:NSZeroRect
														options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect
														  owner:self
													   userInfo:nil];
	[self addTrackingArea:area];
	[area release];
}
- (void)mouseEntered:(NSEvent *)event { [hoverDelegate mouseDidEnterPrompt]; }
- (void)mouseExited:(NSEvent *)event { [hoverDelegate mouseDidExitPrompt]; }
@end

@interface StarPromptPanel : NSObject <StarPromptHoverDelegate> {
	NSPanel *panel;
	NSTimer *hideTimer;
	BOOL closed;
}
- (instancetype)initNearStatusItem:(NSStatusItem *)statusItem;
- (void)show;
- (void)closeSavingDismissal:(BOOL)saveDismissal;
@end

@implementation StarPromptPanel

static NSTextField *StarPromptLabel(NSString *text, NSFont *font, NSColor *color, NSRect frame)
{
	NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
	label.stringValue = text;
	label.font = font;
	label.textColor = color;
	label.bezeled = NO;
	label.drawsBackground = NO;
	label.editable = NO;
	label.selectable = NO;
	label.lineBreakMode = NSLineBreakByTruncatingTail;
	return label;
}

static NSImage *StarPromptRoundedMask(CGFloat radius)
{
	NSImage *mask = [NSImage imageWithSize:NSMakeSize(radius * 2 + 1, radius * 2 + 1) flipped:NO drawingHandler:^BOOL(NSRect rect) {
		[[NSColor blackColor] set];
		[[NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius] fill];
		return YES;
	}];
	mask.capInsets = NSEdgeInsetsMake(radius, radius, radius, radius);
	mask.resizingMode = NSImageResizingModeStretch;
	return mask;
}

- (NSRect)frameNearStatusItem:(NSStatusItem *)statusItem
{
	NSWindow *statusWindow = statusItem.button.window;
	NSScreen *screen = statusWindow.screen ?: [NSScreen mainScreen];
	NSRect visible = screen.visibleFrame;
	const CGFloat margin = 8;
	// Right-align with the menu bar icon, kept on screen.
	CGFloat x = statusWindow ? NSMaxX(statusWindow.frame) - StarPromptWidth : NSMaxX(visible) - StarPromptWidth - margin;
	x = MIN(MAX(x, NSMinX(visible) + margin), NSMaxX(visible) - StarPromptWidth - margin);
	CGFloat y = NSMaxY(visible) - StarPromptHeight - margin;
	return NSMakeRect(x, y, StarPromptWidth, StarPromptHeight);
}

- (instancetype)initNearStatusItem:(NSStatusItem *)statusItem
{
	if (!(self = [super init]))
		return nil;

	// Non-activating, so focus stays in the app the user just pasted into.
	panel = [[NSPanel alloc] initWithContentRect:[self frameNearStatusItem:statusItem]
									   styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
										 backing:NSBackingStoreBuffered
										   defer:NO];
	panel.releasedWhenClosed = NO;
	panel.level = NSStatusWindowLevel;
	panel.opaque = NO;
	panel.backgroundColor = [NSColor clearColor];
	panel.hasShadow = YES;
	panel.hidesOnDeactivate = NO;
	panel.becomesKeyOnlyIfNeeded = YES;
	// hideApp hides Soarcut right after every paste; the prompt has to survive that.
	panel.canHide = NO;
	panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient;

	const CGFloat W = StarPromptWidth, H = StarPromptHeight, pad = 14;
	StarPromptContentView *content = [[[StarPromptContentView alloc] initWithFrame:NSMakeRect(0, 0, W, H)] autorelease];
	content.material = NSVisualEffectMaterialPopover;
	content.blendingMode = NSVisualEffectBlendingModeBehindWindow;
	content.state = NSVisualEffectStateActive;
	content.maskImage = StarPromptRoundedMask(StarPromptCornerRadius);
	[content setHoverDelegate:self];
	panel.contentView = content;

	[content addSubview:StarPromptLabel(@"★", [NSFont systemFontOfSize:16], [NSColor systemYellowColor],
										NSMakeRect(pad - 2, H - pad - 21, 22, 22))];
	[content addSubview:StarPromptLabel(@"Enjoying Soarcut?", [NSFont boldSystemFontOfSize:13], [NSColor labelColor],
										NSMakeRect(40, H - pad - 18, W - 40 - 34, 18))];
	[content addSubview:StarPromptLabel(@"Give us a star on GitHub to let us know!", [NSFont systemFontOfSize:12], [NSColor secondaryLabelColor],
										NSMakeRect(40, H - pad - 36, W - 40 - pad, 16))];

	StarPromptButton *closeButton = [[[StarPromptButton alloc] initWithFrame:NSMakeRect(W - 26, H - 26, 14, 14)] autorelease];
	closeButton.bordered = NO;
	closeButton.image = [NSImage imageNamed:NSImageNameStopProgressTemplate];
	closeButton.imageScaling = NSImageScaleProportionallyDown;
	closeButton.target = self;
	closeButton.action = @selector(closeClicked:);
	[closeButton setAccessibilityLabel:@"Close"];
	[content addSubview:closeButton];

	StarPromptButton *starButton = [[[StarPromptButton alloc] initWithFrame:NSZeroRect] autorelease];
	starButton.title = @"Star on GitHub";
	starButton.bezelStyle = NSBezelStyleRounded;
	if (@available(macOS 10.14, *))
		starButton.bezelColor = [NSColor controlAccentColor];
	else
		starButton.bezelColor = [NSColor systemBlueColor];
	starButton.target = self;
	starButton.action = @selector(starClicked:);
	[starButton sizeToFit];
	[starButton setFrameOrigin:NSMakePoint(W - pad - NSWidth(starButton.frame) + 6, 8)];
	[content addSubview:starButton];

	StarPromptButton *dismissButton = [[[StarPromptButton alloc] initWithFrame:NSZeroRect] autorelease];
	dismissButton.title = @"Dismiss";
	dismissButton.bezelStyle = NSBezelStyleRounded;
	dismissButton.bordered = NO;
	dismissButton.target = self;
	dismissButton.action = @selector(dismissClicked:);
	[dismissButton sizeToFit];
	NSRect dismissFrame = dismissButton.frame;
	dismissFrame.size.width += 16;
	dismissFrame.origin = NSMakePoint(NSMinX(starButton.frame) - NSWidth(dismissFrame), NSMidY(starButton.frame) - NSHeight(dismissFrame) / 2);
	dismissButton.frame = dismissFrame;
	[content addSubview:dismissButton];

	return self;
}

- (void)dealloc
{
	[hideTimer invalidate];
	[panel release];
	[super dealloc];
}

- (void)startHideTimer
{
	[hideTimer invalidate];
	// The timer retains its target until it fires or is invalidated.
	hideTimer = [NSTimer scheduledTimerWithTimeInterval:StarPromptVisibleSeconds
												 target:self
											   selector:@selector(hideTimerFired:)
											   userInfo:nil
												repeats:NO];
}

- (void)show
{
	panel.alphaValue = 0;
	[panel orderFrontRegardless];
	[panel invalidateShadow];
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = 0.2;
		[[panel animator] setAlphaValue:1];
	} completionHandler:nil];
	[self startHideTimer];
}

- (void)closeSavingDismissal:(BOOL)saveDismissal
{
	if (closed)
		return;
	closed = YES;
	[hideTimer invalidate];
	hideTimer = nil;
	if (saveDismissal)
		StarPromptSaveDismissal();

	NSPanel *closingPanel = [panel retain];
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = 0.2;
		[[closingPanel animator] setAlphaValue:0];
	} completionHandler:^{
		[closingPanel orderOut:nil];
		[closingPanel release];
	}];

	if (visiblePanel == self) {
		visiblePanel = nil;
		[self autorelease];
	}
}

// Every close path except the timeout saves the dismissal, as in T3 Code.
- (void)starClicked:(id)sender
{
	[self closeSavingDismissal:YES];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:StarPromptRepositoryURL]];
}
- (void)dismissClicked:(id)sender { [self closeSavingDismissal:YES]; }
- (void)closeClicked:(id)sender { [self closeSavingDismissal:YES]; }
// Ignored is not dismissed: a later launch may ask again.
- (void)hideTimerFired:(NSTimer *)timer
{
	hideTimer = nil;
	[self closeSavingDismissal:NO];
}

- (void)mouseDidEnterPrompt
{
	[hideTimer invalidate];
	hideTimer = nil;
}
- (void)mouseDidExitPrompt
{
	if (!closed)
		[self startHideTimer];
}

@end

@implementation StarPrompt

+ (void)openRepository
{
	StarPromptSaveDismissal();
	[visiblePanel closeSavingDismissal:YES];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:StarPromptRepositoryURL]];
}

+ (void)recordPasteNearStatusItem:(NSStatusItem *)statusItem
{
	if (shownThisLaunch)
		return;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:StarPromptDismissedKey])
		return;
	// A managed (MDM) value that keeps the dismissal off means closing could never
	// stick, which would turn the prompt into a nag, so never ask. Setting
	// starPromptDismissed to true in a profile turns the prompt off for everyone.
	if ([defaults objectIsForcedForKey:StarPromptDismissedKey])
		return;

	NSInteger pastes = [defaults integerForKey:StarPromptPasteCountKey] + 1;
	[defaults setInteger:pastes forKey:StarPromptPasteCountKey];
	if (pastes <= StarPromptPastesBeforeAsking)
		return;

	shownThisLaunch = YES;
	[statusItem retain];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(StarPromptDelayAfterPaste * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		// The menu's "Star Soarcut on GitHub…" item may have dismissed it meanwhile.
		if (![[NSUserDefaults standardUserDefaults] boolForKey:StarPromptDismissedKey]) {
			visiblePanel = [[StarPromptPanel alloc] initNearStatusItem:statusItem];
			[visiblePanel show];
		}
		[statusItem release];
	});
}

@end
