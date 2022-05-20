//  OCRedTextView.m
//  MockSimpleComic
//
//  Created by David Phillip Oster on 5/16/22.
//

#import "OCRedTextView.h"

#import "OCRVision.h"
#import <Vision/Vision.h>

/// @return the quadrilateral of the text observation as a NSBezierPath/
API_AVAILABLE(macos(10.15))
static NSBezierPath *BezierPathFromTextObservation(VNRecognizedTextObservation *piece)
{
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:piece.topLeft];
	[path lineToPoint:piece.topRight];
	[path lineToPoint:piece.bottomRight];
	[path lineToPoint:piece.bottomLeft];
	[path closePath];
	return path;
}

/// @return the NSRect from two points.
static NSRect RectFrom2Points(NSPoint a, NSPoint b)
{
	NSRect r;
	r.origin = a;
	r.size.width = b.x - a.x;
	r.size.height = b.y - a.y;
	r = CGRectStandardize(r);
	return r;
}

static NSSpeechSynthesizer *sSpeechSynthesizer;

typedef enum OCRDragEnum {
	OCRDragEnumNot,
	OCRDragEnumHand,
	OCRDragEnumIBeam
} OCRDragEnum;

@interface OCRedTextView()
@property OCRDragEnum dragKind;

/// <VNRecognizedTextObservation *> - 10.15 and newer
@property NSArray *textPieces;

/// <VNRecognizedTextObservation *> - 10.15 and newer
@property NSMutableSet *selectionPieces;

@end

@implementation OCRedTextView

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	[self initOCRedTextView];
	return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	[self initOCRedTextView];
	return self;
}

- (void)initOCRedTextView
{
	self.selectionPieces = [NSMutableSet set];
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	if (self.textPieces == nil)
	{
		[[NSColor.yellowColor colorWithAlphaComponent:0.4] set];
		CGRect smallBounds = CGRectInset(self.bounds, 20, 20);
		NSRectFill(smallBounds);
	} else {
		if (@available(macOS 10.15, *))
		{
			NSAffineTransform *transform = [NSAffineTransform transform];
			[transform scaleXBy:self.bounds.size.width yBy:self.bounds.size.height];
			for (VNRecognizedTextObservation *piece in self.textPieces)
			{
				if ([self.selectionPieces containsObject:piece])
				{
					NSBezierPath *path = BezierPathFromTextObservation(piece);
					[path transformUsingAffineTransform:transform];
					[[NSColor.yellowColor colorWithAlphaComponent:0.4] set];
					[path fill];
				}
			}
		}
	}
}

#pragma mark Model

- (NSString *)allText
{
	if (@available(macOS 10.15, *))
	{
		NSMutableArray *a = [NSMutableArray array];
		for (VNRecognizedTextObservation *piece in self.textPieces)
		{
			NSArray<VNRecognizedText *> *text1 = [piece topCandidates:1];
			[a addObject:text1.firstObject.string];
		}
		return [a componentsJoinedByString:@"\n"];
	}
	return nil;
}

- (NSString *)selection
{
	NSMutableArray *a = [NSMutableArray array];
	if (@available(macOS 10.15, *))
	{
		for (VNRecognizedTextObservation *piece in self.textPieces)
		{
			if ([self.selectionPieces containsObject:piece])
			{
				NSArray<VNRecognizedText *> *text1 = [piece topCandidates:1];
				[a addObject:text1.firstObject.string];
			}
		}
	}
	return [a componentsJoinedByString:@"\n"];
}

- (nullable NSObject *)textPieceForMouseEvent:(NSEvent *)theEvent
{
	NSPoint where = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	return [self textPieceForPoint:where];
}

/// For a point, find the textPiece
///
/// @param where - a point in View coordinates,
/// @return the textPiece that contains that point
- (nullable NSObject *)textPieceForPoint:(CGPoint)where
{
	if (@available(macOS 10.15, *))
	{
		if (self.textPieces)
		{
			CGRect container = [[self enclosingScrollView] documentVisibleRect];
			for (VNRecognizedTextObservation *piece in self.textPieces)
			{
				CGRect r = [self boundBoxOfPiece:piece];
				r = CGRectIntersection(r, container);
				if (!CGRectIsEmpty(r) && CGRectContainsPoint(r, where)) {
					return piece;
				}
			}
		}
	}
	return nil;
}

/// Return the boundbox of a piece in View coordinates
///
/// @param piece - A text piece
/// @return The bound box in View coordinates
- (CGRect)boundBoxOfPiece:(VNRecognizedTextObservation *)piece API_AVAILABLE(macos(10.15))
{
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform scaleXBy:self.bounds.size.width yBy:self.bounds.size.height];
	CGRect r = piece.boundingBox;
	r.origin = [transform transformPoint:r.origin];
	r.size = [transform transformSize:r.size];
	return r;
}

#pragma mark OCR

- (void)ocrDidFinish:(OCRVisionComplete *)complete
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if (@available(macOS 10.15, *)) {
			self.textPieces = complete.textObservations;
		}
		[self.selectionPieces removeAllObjects];
		[self setNeedsDisplay:YES];
		[self.window invalidateCursorRectsForView:self];
	});
}

- (void)ocrImage:(NSImage *)image
{
	__block OCRVision *ocrVision = [[OCRVision alloc] init];
	[ocrVision ocrImage:image completion:^(OCRVisionComplete * _Nonnull complete) {
		[self ocrDidFinish:complete];
		ocrVision = nil;
	}];
}

- (void)ocrCGImage:(CGImageRef)cgImage
{
	__block OCRVision *ocrVision = [[OCRVision alloc] init];
	[ocrVision ocrCGImage:cgImage completion:^(OCRVisionComplete * _Nonnull complete) {
		[self ocrDidFinish:complete];
		ocrVision = nil;
	}];
}


#pragma mark Mouse

- (void)mouseDown:(NSEvent *)theEvent
{
	NSObject *textPiece = [self textPieceForMouseEvent:theEvent];
	if (textPiece != nil)
	{
		[self mouseDownText:theEvent textPiece:textPiece];
	}
	else if([self dragIsPossible])
	{
		[self mouseDownHand];
	}
}

- (void)mouseDownText:(NSEvent *)theEvent textPiece:(NSObject *)textPiece
{
	if ([self.selectionPieces containsObject:textPiece]  && (theEvent.modifierFlags & NSEventModifierFlagControl) != 0) {
		NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
		[theMenu insertItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"" atIndex:0];
		[theMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
		[theMenu insertItemWithTitle:@"Start Speaking" action:@selector(startSpeaking:) keyEquivalent:@"" atIndex:2];
		[theMenu insertItemWithTitle:@"Stop Speaking" action:@selector(stopSpeaking:) keyEquivalent:@"" atIndex:3];
		[NSMenu popUpContextMenu:theMenu withEvent:theEvent forView:self];
	} else {
		[[NSCursor IBeamCursor] set];
		if (!(theEvent.modifierFlags & NSEventModifierFlagCommand))
		{
			[self.selectionPieces removeAllObjects];
			[self setNeedsDisplay:YES];
		}
	}
}

- (void)mouseDownHand
{
	[[NSCursor closedHandCursor] set];
	[self.selectionPieces removeAllObjects];
	[self setNeedsDisplay:YES];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	[super mouseMoved:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	NSObject *textPiece = [self textPieceForMouseEvent:theEvent];
	if (textPiece != nil)
	{
		[self mouseDragText:theEvent textPiece:textPiece];
	}
	else if([self dragIsPossible])
	{
		[self mouseDraggedHand:theEvent];
	}
}

- (void)mouseDraggedHand:(NSEvent *)theEvent
{
	NSPoint viewOrigin = [[self enclosingScrollView] documentVisibleRect].origin;
	NSPoint cursor = [theEvent locationInWindow];
	NSPoint currentPoint;
	self.dragKind = OCRDragEnumHand;
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
	self.dragKind = OCRDragEnumNot;
	[[self window] invalidateCursorRectsForView: self];
}

- (void)mouseDragText:(NSEvent *)theEvent textPiece:(NSObject *)textPiece
{
	NSPoint startPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	self.dragKind = OCRDragEnumIBeam;
	NSMutableSet *previousSelection = [NSMutableSet set];
	if (theEvent.modifierFlags & NSEventModifierFlagCommand)
	{
		previousSelection = [self.selectionPieces mutableCopy];
	}
	[self.selectionPieces removeAllObjects];
	[self.selectionPieces addObjectsFromArray:[previousSelection allObjects]];
	while ([theEvent type] != NSEventTypeLeftMouseUp)
	{
		if ([theEvent type] == NSEventTypeLeftMouseDragged)
		{
			NSPoint endPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
			NSRect downRect = RectFrom2Points(startPoint, endPoint);
			[self updateSelectionFromDownRect:downRect previousSelection:previousSelection];
		}
		theEvent = [[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged];
	}
	[self.window invalidateCursorRectsForView:self];
	self.dragKind = OCRDragEnumNot;
}

- (void)updateSelectionFromDownRect:(NSRect)downRect previousSelection:(NSMutableSet *)previousSelection
{
	if (@available(macOS 10.15, *))
	{
		NSMutableSet *selectionSet = [NSMutableSet set];
		for (VNRecognizedTextObservation *piece in self.textPieces)
		{
			CGRect pieceR = [self boundBoxOfPiece:piece];
			if (CGRectIntersectsRect(downRect, pieceR)) {
				[selectionSet addObject:piece];
				[previousSelection removeObject:piece];
			}
		}
		[selectionSet addObjectsFromArray:[previousSelection allObjects]];
		if (![self.selectionPieces isEqual:selectionSet]) {
			self.selectionPieces = selectionSet;
			[self setNeedsDisplay:YES];
			[self.window invalidateCursorRectsForView:self];
		}
	}
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
	if (self.dragKind == OCRDragEnumIBeam) {
		[self addCursorRect: [[self enclosingScrollView] documentVisibleRect] cursor:[NSCursor IBeamCursor]];
	}
	else if (@available(macOS 10.15, *))
	{
		if (self.textPieces)
		{
			CGRect container = [[self enclosingScrollView] documentVisibleRect];
			for (VNRecognizedTextObservation *piece in self.textPieces)
			{
				CGRect r = [self boundBoxOfPiece:piece];
				r = CGRectIntersection(r, container);
				if (!CGRectIsEmpty(r)) {
					[self addCursorRect:r cursor:[NSCursor IBeamCursor]];
				}
			}
		}
	}
	if([self dragIsPossible])
	{
		NSCursor *cursor = self.dragKind == OCRDragEnumHand ? [NSCursor closedHandCursor] : [NSCursor openHandCursor];
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
	if ([menuItem action] == @selector(copy:))
	{
		return [self.selectionPieces count] != 0;
	}
	else if ([menuItem action] == @selector(selectAll:) || [menuItem action] == @selector(startSpeaking:))
	{
		if (@available(macOS 10.15, *))
		{
			return [self.textPieces count] != 0 && [self.textPieces count] != [self.selectionPieces count];
		} else {
			return NO;
		}
	}
	else if ([menuItem action] == @selector(stopSpeaking:))
	{
		return [sSpeechSynthesizer isSpeaking];
	}
	return NO;
}

- (void)startSpeaking:(id)sender
{
	if (sSpeechSynthesizer == nil)
	{
		sSpeechSynthesizer = [[NSSpeechSynthesizer alloc] init];
	}
	[sSpeechSynthesizer startSpeakingString:[self selection]];
}

- (void)stopSpeaking:(id)sender
{
	[sSpeechSynthesizer stopSpeaking];
}

- (void)selectAll:(id)sender
{
	if (@available(macOS 10.15, *))
	{
		for (VNRecognizedTextObservation *piece in self.textPieces)
		{
			[self.selectionPieces addObject:piece];
		}
		[self setNeedsDisplay:YES];
		[self.window invalidateCursorRectsForView:self];
	}
}

- (void)copy:(id)sender
{
  NSPasteboard *pboard = [NSPasteboard generalPasteboard];
  [self copyToPasteboard:pboard];
}

- (void)copyToPasteboard:(NSPasteboard *)pboard
{
  NSString *s = [self selection];
  [pboard clearContents];
  [pboard setString:s forType:NSPasteboardTypeString];
}

#pragma mark Services

- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
{
  if (([sendType isEqual:NSPasteboardTypeString] || [sendType isEqual:NSStringPboardType]) && [self.selectionPieces count] != 0)
	{
    return self;
  }
  return [[self nextResponder] validRequestorForSendType:sendType returnType:returnType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
  if (([types containsObject:NSPasteboardTypeString] || [types containsObject:NSStringPboardType]) && [self.selectionPieces count] != 0)
	{
    [self copyToPasteboard:pboard];
    return YES;
  }
  return NO;
}

@end
