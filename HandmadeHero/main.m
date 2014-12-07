// Bare bones Handmade Hero-like functionality (but not in HH coding style)
// Simple graphics, runloop and initialization only, needs a XIB for the menubar etc.
// (c) 2014 by Arthur Langereis (@zenmumbler)

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

#include <stdint.h>

static bool running = false;
static int xOffset;

// capture all the app objects so ARC won't deallocate them immediately
@class HHView;
@class HHAppDelegate;
@class HHWindowDelegate;

static HHAppDelegate *appDelegate;
static NSWindow *mainWindow;
static HHView *mainView;
static HHWindowDelegate *winDelegate;


@interface HHAppDelegate : NSObject<NSApplicationDelegate> {
}
@property (nonatomic, strong) NSArray* xibObjects;
@end
@implementation HHAppDelegate
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	// Cocoa will kill your app on the spot if you don't stop it
	// So if you want to do anything beyond your main loop then include this method.
	running = false;
	return NSTerminateCancel;
}
@end


@interface HHWindowDelegate : NSObject<NSWindowDelegate> {}
@end
@implementation HHWindowDelegate
- (BOOL)windowShouldClose:(id)sender {
	running = false;
	return NO;
}
@end


@interface HHView : NSView {
	void* dataPtr_;
	CGContextRef backBuffer_;
}
- (instancetype)initWithFrame:(NSRect)frameRect;
- (void)drawRect:(NSRect)dirtyRect;
- (void*)bitmapData;
@end
@implementation HHView

- (instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame: frameRect];
	if (self) {
		int width = frameRect.size.width;
		int height = frameRect.size.height;
		int rowBytes = 4 * width;
		dataPtr_ = calloc(1, rowBytes * height); // calloc clears memory upon first touch
		
		CMProfileRef prof; // these 2 calls are deprecated as of 10.6, but still work and I can't find their modern equivalent.
		CMGetSystemProfile(&prof);
		CGColorSpaceRef colorSpace = CGColorSpaceCreateWithPlatformColorSpace(prof);
		
		backBuffer_ = CGBitmapContextCreate(dataPtr_, width, height, 8, rowBytes, colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault);
		CGColorSpaceRelease(colorSpace);
		CMCloseProfile(prof);
	}
	return self;
}

- (void*)bitmapData {
	return dataPtr_;
}

- (void)drawRect:(NSRect)dirtyRect {
	CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
	CGImageRef backImage = CGBitmapContextCreateImage(backBuffer_);
	CGContextDrawImage(ctx, self.frame, backImage);
	CGImageRelease(backImage);
}
@end


static void createWindow() {
	NSRect frame = NSMakeRect(0, 0, (CGFloat)1024, (CGFloat)768);
	
	mainWindow = [[NSWindow alloc]
				  initWithContentRect: frame
				  styleMask: NSTitledWindowMask | NSClosableWindowMask
				  backing: NSBackingStoreBuffered
				  defer: NO
				  ];
	[mainWindow setTitle: @"Handmade Hero"];
	[mainWindow setAcceptsMouseMovedEvents: YES];
	[mainWindow setOpaque: YES];
	[mainWindow center];
	
	mainView = [[HHView alloc] initWithFrame:frame];
	[mainWindow setContentView: mainView];

	winDelegate = [[HHWindowDelegate alloc] init];
	[mainWindow setDelegate: winDelegate];

	[mainWindow makeKeyAndOrderFront: nil];
}


void initApp() {
	NSApplication* app = [NSApplication sharedApplication];
	
	appDelegate = [[HHAppDelegate alloc] init];
	[app setDelegate: appDelegate];
	
	// -- install menubar, etc.; store top-level objects in the app delegate to retain them
	NSArray *tlo;
	[[NSBundle mainBundle] loadNibNamed:@"handmade" owner:appDelegate topLevelObjects: &tlo];
	appDelegate.xibObjects = tlo;
	
	// -- allow relative paths to work from the Contents/Resources directory
	const char *resourcePath = [[[NSBundle mainBundle] resourcePath] UTF8String];
	chdir(resourcePath);
	
	running = true;
	[app finishLaunching];
}

void frame() {
	@autoreleasepool {
		NSEvent* ev;
		do {
			ev = [NSApp nextEventMatchingMask: NSAnyEventMask
									untilDate: nil
									   inMode: NSDefaultRunLoopMode
									  dequeue: YES];
			if (ev) {
				// handle events here
				[NSApp sendEvent: ev];
			}
		} while (ev);
	}
}

void renderStuff() {
	uint32_t *bitmap = (uint32_t*)([mainView bitmapData]);
	int width = [mainView frame].size.width,
		height = [mainView frame].size.height;
	
	for (int y=0; y < height; ++y) {
		for (int x=0; x < width; ++x) {
			uint8_t blue = x + xOffset;
			uint8_t green = y;
			*bitmap++ = ((green << 16) | blue << 8);
		}
	}
}

int main(int argc, const char * argv[]) {
	initApp();
	createWindow();
	
	while (running) {
		frame();
		renderStuff();
		[mainView setNeedsDisplay:YES];
		++xOffset;
	}
}
