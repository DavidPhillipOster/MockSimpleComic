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
	self.ocrView.image2 = [NSImage imageNamed:@"test2.jpg"];
	NSImageRep *rep = self.ocrView.image.representations.lastObject;
	CGRect frame = self.ocrView.frame;
	frame.size = self.ocrView.image.size;
	self.ocrView.imageFrame = frame;
	frame.size.width += self.ocrView.image2.size.width;
	self.ocrView.frame = frame;
	[self.ocrView ocrImage:self.ocrView.image];	// <- run the OCR engine and initialize the U.I.

	frame.origin.x = self.ocrView.image.size.width;
	frame.size.width -= self.ocrView.image.size.width;
	self.ocrView.image2Frame = frame;
	[self.ocrView ocrImage2:self.ocrView.image2];	// <- run the OCR engine and initialize the U.I.


	// resize down from full size by 0.4
	self.scroll.magnification = (rep.pixelsWide / frame.size.width) * 0.4;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}


@end
