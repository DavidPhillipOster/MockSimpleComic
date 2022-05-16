//  AppDelegate.m
//  MockSimpleComic
//
//  Created by David Phillip Oster on 5/16/22.
//

#import "AppDelegate.h"

#import "OCRedTextView.h"

@interface AppDelegate ()

@property IBOutlet NSWindow *window;
@property IBOutlet NSScrollView *scroll;
@property IBOutlet NSImageView *page;
@property OCRedTextView *ocrView;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	self.ocrView = [[OCRedTextView alloc] initWithFrame:self.page.bounds];
	self.ocrView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	[self.ocrView ocrImage:self.page.image];	// <- run the OCR engine and initialize the U.I.
	[self.page addSubview:self.ocrView];
	CGRect frame = self.page.frame;
	frame.size = self.page.image.size;
	self.page.frame = frame;
	NSImageRep *rep =  self.page.image.representations.lastObject;
	// resize down from full size by 0.4
	self.scroll.magnification = (rep.pixelsWide / frame.size.width) * 0.4;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}


@end