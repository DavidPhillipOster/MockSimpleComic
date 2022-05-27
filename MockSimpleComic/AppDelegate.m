//  AppDelegate.m
//  MockSimpleComic
//
//  Created by David Phillip Oster on 5/16/22. Apache Version 2 open source license.
//

#import "AppDelegate.h"

#import "SimpleImagePageView.h"

@interface AppDelegate ()

@property IBOutlet NSWindow *window;
@property IBOutlet NSScrollView *scroll;
@property IBOutlet SimpleImagePageView *ocrView;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

	self.ocrView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	self.ocrView.image = [NSImage imageNamed:@"test.jpg"];
	NSImageRep *rep = self.ocrView.image.representations.lastObject;
	CGRect frame = self.ocrView.frame;
	frame.size = self.ocrView.image.size;
	self.ocrView.frame = frame;

	// resize down from full size by 0.4
	self.scroll.magnification = (rep.pixelsWide / frame.size.width) * 0.4;
	[self.ocrView ocrImage:self.ocrView.image];	// <- run the OCR engine and initialize the U.I.
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}


@end
