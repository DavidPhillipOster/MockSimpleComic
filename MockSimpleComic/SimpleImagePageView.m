//  SimpleImagePageView.m
//  MockSimpleComic
//
//  Created by David Phillip Oster on 5/16/22.

#import "SimpleImagePageView.h"

#import "OCRVision.h"

typedef enum DragEnum {
	DragEnumNot,
	DragEnumHand
} DragEnum;

@interface SimpleImagePageView()
@property DragEnum dragKind;
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
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
}

#pragma mark OCR

- (void)ocrImage:(NSImage *)image
{
}

- (void)ocrCGImage:(CGImageRef)cgImage
{
}


#pragma mark Mouse

- (void)mouseDown:(NSEvent *)theEvent
{
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
	self.dragKind = DragEnumHand;
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
	self.dragKind = DragEnumNot;
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
	if([self dragIsPossible])
	{
		NSCursor *cursor = self.dragKind == DragEnumHand ? [NSCursor closedHandCursor] : [NSCursor openHandCursor];
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
