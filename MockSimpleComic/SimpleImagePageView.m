//  SimpleImagePageView.m
//  MockSimpleComic
//
//  Created by David Phillip Oster on 5/16/22. Apache Version 2 open source license.

#import "SimpleImagePageView.h"

#import "OCRTracker.h"

@interface SimpleImagePageView()
@property BOOL isInDrag;
@property OCRTracker *tracker;
@end

@implementation SimpleImagePageView

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	[self initSimpleImagePageView];
	return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	[self initSimpleImagePageView];
	return self;
}

- (void)initSimpleImagePageView
{
	_tracker = [[OCRTracker alloc] initWithView:self];
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)becomeFirstResponder {
	[self.tracker becomeNextResponder];
  return YES;
}

- (BOOL)resignFirstResponder {
  return YES;
}


- (void)drawRect:(NSRect)dirtyRect
{
	self.layer.sublayers = nil;

	CALayer* newLayer = [[CALayer alloc]init];
	NSData *firstPageImageData = self.image.TIFFRepresentation;
	if (firstPageImageData != nil) {
		CGImageSourceRef firstPageImageSource = CGImageSourceCreateWithData((__bridge CFDataRef)firstPageImageData, NULL);
		CGImageRef firstPageImageRef =  CGImageSourceCreateImageAtIndex(firstPageImageSource, 0, NULL);
		CFRelease(firstPageImageSource);

		CALayer *firstPageLayer = [CALayer layer];
		firstPageLayer.contents = (__bridge id) firstPageImageRef;
		CFRelease(firstPageImageRef);

		NSRect frame = [self frame];	// ?
		[firstPageLayer setFrame:frame];
		[newLayer addSublayer:firstPageLayer];
		CALayer *selectionLayer = [self.tracker layerForImage:self.image imageLayer:firstPageLayer];
		if (selectionLayer) {
			[newLayer addSublayer:selectionLayer];
		}
	}
	[self.layer addSublayer:newLayer];
}

#pragma mark OCR

- (void)ocrImage:(NSImage *)image
{
	[self.tracker ocrImage:image];
}

- (void)ocrCGImage:(CGImageRef)cgImage
{
	[self.tracker ocrCGImage:cgImage];
}


#pragma mark Mouse

- (void)mouseDown:(NSEvent *)theEvent
{
	if ([self.tracker didMouseDown:theEvent])
	{
		return;
	}
	if([self dragIsPossible])
	{
		[self mouseDownHand];
	}
}

- (void)mouseDownHand
{
	[[NSCursor closedHandCursor] set];
	[self setNeedsDisplay:YES];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	[super mouseMoved:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if ([self.tracker didMouseDragged:theEvent])
	{
		return;
	}
	if([self dragIsPossible])
	{
		[self mouseDraggedHand:theEvent];
	}
}

- (void)mouseDraggedHand:(NSEvent *)theEvent
{
	NSPoint viewOrigin = [[self enclosingScrollView] documentVisibleRect].origin;
	NSPoint cursor = [theEvent locationInWindow];
	NSPoint currentPoint;
	self.isInDrag = YES;
	while ([theEvent type] != NSEventTypeLeftMouseUp)
	{
		if ([theEvent type] == NSEventTypeLeftMouseDragged)
		{
			currentPoint = [theEvent locationInWindow];
			[self scrollPoint: NSMakePoint(viewOrigin.x + cursor.x - currentPoint.x,viewOrigin.y + cursor.y - currentPoint.y)];
//				[sessionController refreshLoupePanel];
		}
		theEvent = [[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged];
	}
	self.isInDrag = NO;
	[[self window] invalidateCursorRectsForView: self];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if([self dragIsPossible])
	{
		[[NSCursor openHandCursor] set];
	}
}

- (BOOL)horizontalScrollIsPossible
{
	NSSize total = self.bounds.size;
	NSSize visible = [[self enclosingScrollView] documentVisibleRect].size;
	return (visible.width < round(total.width));
}


- (BOOL)verticalScrollIsPossible
{
	NSSize total = self.bounds.size;
	NSSize visible = [[self enclosingScrollView] documentVisibleRect].size;
	return (visible.height < round(total.height));
}

- (BOOL)dragIsPossible
{
	return [self horizontalScrollIsPossible] || [self verticalScrollIsPossible];
}

- (void)resetCursorRects
{
	if ([self.tracker didResetCursorRects])
	{
		return;
	}
	if([self dragIsPossible])
	{
		NSCursor *cursor = self.isInDrag ? [NSCursor closedHandCursor] : [NSCursor openHandCursor];
		[self addCursorRect: [[self enclosingScrollView] documentVisibleRect] cursor:cursor];
	}
//	else if(canCrop)
//	{
//		[self addCursorRect: [[self enclosingScrollView] documentVisibleRect] cursor: [NSCursor crosshairCursor]];
//	}
	else
	{
		[super resetCursorRects];
	}
}

#pragma mark Menubar

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	return NO;
}


@end
