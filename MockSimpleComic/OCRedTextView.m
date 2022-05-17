//  OCRedTextView.m
//  MockSimpleComic
//
//  Created by David Phillip Oster on 5/16/22.
//

#import "OCRedTextView.h"

#import "OCRGraphicsMath.h"
#import <Vision/Vision.h>

///  start and end are in range 0…1 and control how much of the potential path to return. For the whole path, use start=0, end=1
///
/// @param piece - VNRecognizedTextObservation with points of rectangle.
/// @param start - low ratio of the piece's path
/// @param end - high ratio of the piece's path
/// @return the quadrilateral of the text observation as a NSBezierPath/
API_AVAILABLE(macos(10.15))
static NSBezierPath *BezierPathFromTextObservation(VNRecognizedTextObservation *piece, CGFloat start, CGFloat end)
{
	return OCRBezierPathFromCornersRatio(piece.topLeft, piece.topRight, piece.bottomRight, piece.bottomLeft, start, end);
}

static NSString *sOCRLanguage;

static NSArray<NSString *> *sOCRLanguages;
static NSSpeechSynthesizer *sSpeechSynthesizer;

typedef enum OCRDragEnum {
	OCRDragEnumNot,
	OCRDragEnumHand,
	OCRDragEnumIBeam
} OCRDragEnum;

@interface OCRSelectionPiece : NSObject
@property CGFloat start;
@property CGFloat end;
@end
@implementation OCRSelectionPiece
@end

@interface OCRedTextView()
@property OCRDragEnum dragKind;
/// <VNRecognizedTextObservation *> - 10.15 and newer
@property(nonatomic) NSArray *textPieces;
@property NSError *ocrError;

/// key is the address of a VNRecognizedTextObservation, value is start,end fractions in 0…1
@property NSMutableDictionary<NSValue *, OCRSelectionPiece *> *selectionPieces;

@end

@implementation OCRedTextView

+ (void)initialize
{
	[super initialize];
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if (@available(macOS 10.15, *))
		{
			NSUInteger revision = VNRecognizeTextRequestRevision1;
			if (@available(macOS 11.0, *))
			{
				revision = VNRecognizeTextRequestRevision2;
			}
			if (@available(macOS 12.0, *))
			{
				VNRecognizeTextRequest *textRequest = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError *error){}];
				sOCRLanguages = [textRequest supportedRecognitionLanguagesAndReturnError:nil];
			} else {
				sOCRLanguages = [VNRecognizeTextRequest supportedRecognitionLanguagesForTextRecognitionLevel:VNRequestTextRecognitionLevelAccurate revision:revision error:NULL];
			}
			sOCRLanguage = sOCRLanguages.firstObject;
		}
	});
}

+ (NSArray<NSString *> *)ocrLanguages
{
	if (nil == sOCRLanguages){ return @[]; }
	return sOCRLanguages;
}

+ (NSString *)ocrLanguage
{
	return sOCRLanguage;
}

+ (void)setOCRLanguage:(NSString *)ocrLanguage
{
	if (nil != ocrLanguage)
	{
		if ([[self ocrLanguages] containsObject:ocrLanguage])
		{
			sOCRLanguage = ocrLanguage;
		}
	} else {
		sOCRLanguage = sOCRLanguages.firstObject;
	}
}

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
	self.selectionPieces = [NSMutableDictionary	dictionary];
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
				NSRect bound = [self boundBoxOfPiece:piece];
				if (CGRectIntersectsRect(bound, dirtyRect))
				{
					OCRSelectionPiece *selectionPiece = self.selectionPieces[ [NSValue valueWithPointer:(__bridge const void *)(piece)] ];
					if (selectionPiece != nil) {
						CGFloat start = selectionPiece.start;
						CGFloat end = selectionPiece.end;
						if (end < start) {
							start = selectionPiece.end;
							end = selectionPiece.start;
						}
						NSBezierPath *path = BezierPathFromTextObservation(piece, start, end);
						[path transformUsingAffineTransform:transform];
						[[NSColor.yellowColor colorWithAlphaComponent:0.4] set];
						[path fill];

						path = BezierPathFromTextObservation(piece, 0, 1);
						[path transformUsingAffineTransform:transform];
						[[NSColor.yellowColor colorWithAlphaComponent:0.7] set];
						[path stroke];

					}
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
			NSValue *textValue = [NSValue valueWithPointer:(__bridge const void *)(piece)];
			OCRSelectionPiece *selectionPair = self.selectionPieces[textValue];
			if (selectionPair != nil)
			{
				NSArray<VNRecognizedText *> *text1 = [piece topCandidates:1];
				[a addObject:text1.firstObject.string];
			}
		}
	}
	return [a componentsJoinedByString:@"\n"];
}

- (void)setTextPieces:(NSArray *)texts
{
	if (_textPieces != texts)
	{
		_textPieces = texts;
		[self.selectionPieces removeAllObjects];
		[self setNeedsDisplay:YES];
		[self.window invalidateCursorRectsForView:self];
	}
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

/// Called by VNRecognizeTextRequest to process the result.
/// Filter the textPieces that includes actual text, and store in self.textPieces.
///
///  Since this is called on a worker queue, it delivers results on the main queue.
///
/// @param request - The VNRecognizeTextRequest
/// @param error - if non-nil, the VNRecognizeTextRequest is reporting an error.
- (void)handleTextRequest:(nullable VNRequest *)request error:(nullable NSError *)error API_AVAILABLE(macos(10.15))
{
	if (error)
	{
		dispatch_async(dispatch_get_main_queue(), ^{ self.textPieces = nil; self.ocrError = error; });
	}
	else if ([request isKindOfClass:[VNRecognizeTextRequest class]])
	{
		VNRecognizeTextRequest *textRequests = (VNRecognizeTextRequest *)request;
		NSMutableArray<VNRecognizedTextObservation *> *pieces = [NSMutableArray array];
		NSArray *results = textRequests.results;
		for (id rawResult in results)
		{
			if ([rawResult isKindOfClass:[VNRecognizedTextObservation class]])
			{
				VNRecognizedTextObservation *textO = (VNRecognizedTextObservation *)rawResult;
				NSArray<VNRecognizedText *> *text1 = [textO topCandidates:1];
				if (text1.count)
				{
					[pieces addObject:textO];
				}
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{ self.textPieces = pieces; self.ocrError = nil; });
	} else {
		NSString *desc = @"Unrecognized text request";
		NSError *err = [NSError errorWithDomain:@"OCRText" code:1 userInfo:@{NSLocalizedDescriptionKey : desc}];
		dispatch_async(dispatch_get_main_queue(), ^{ self.textPieces = nil; self.ocrError = err; });
	}
}

/// perform the OCR of the CGImage
///
///  make a RequestHandler perform a RecognizeTextRequest, with results processed in the method of this class:
///  -[handleTextRequest:error:]
///
///  Since this is called on a worker queue, it delivers results on the main queue.
///
///  @param image - the CGImage
- (void)actualOCRCGImage:(CGImageRef)image API_AVAILABLE(macos(10.15))
{
  __weak typeof(self) weakSelf = self;
  VNRecognizeTextRequest *textRequest =
      [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError *error)
			{
				[weakSelf handleTextRequest:request error:error];
			}];
  if (textRequest)
  {
		NSString *ocrLanguage = [[self class] ocrLanguage];
		if (ocrLanguage)
		{
			textRequest.recognitionLanguages = @[ocrLanguage];
		}
		NSError *error = nil;
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image options:@{}];
		if (![handler performRequests:@[textRequest] error:&error])
		{
			dispatch_async(dispatch_get_main_queue(), ^{ self.ocrError = error; });
		}
  } else {
		NSString *desc = @"Could not create text request";
		NSError *err = [NSError errorWithDomain:@"OCRText" code:2 userInfo:@{NSLocalizedDescriptionKey : desc}];
		dispatch_async(dispatch_get_main_queue(), ^{ self.ocrError = err; });
  }
}

- (void)ocrImage:(NSImage *)image
{
	if(@available(macOS 10.15, *))
	{
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			NSData *imageData = image.TIFFRepresentation;
			if(imageData != nil)
			{
				CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
				if (imageSource != nil)
				{
					CGImageRef imageRef =  CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
					if (imageRef != nil)
					{
						[self actualOCRCGImage:imageRef];
						CFRelease(imageRef);
					}
					CFRelease(imageSource);
				}
			}
		});
	}
}

- (void)ocrCGImage:(CGImageRef)cgImage
{
	if(@available(macOS 10.15, *))
	{
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			[self actualOCRCGImage:cgImage];
		});
	}
}

#pragma mark Mouse

- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint where = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSObject *textPiece = [self textPieceForPoint:where];
	if (textPiece != nil)
	{
		if (self.selectionPieces[ [NSValue valueWithPointer:(__bridge const void *)(textPiece)] ] != nil && (theEvent.modifierFlags & NSEventModifierFlagControl) != 0) {
			NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
			[theMenu insertItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"" atIndex:0];
			[theMenu insertItemWithTitle:@"Start Speaking" action:@selector(startSpeaking:) keyEquivalent:@"" atIndex:0];
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
	else if([self dragIsPossible])
	{
		[[NSCursor closedHandCursor] set];
		[self.selectionPieces removeAllObjects];
		[self setNeedsDisplay:YES];
	}
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	[super mouseMoved:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint viewOrigin = [[self enclosingScrollView] documentVisibleRect].origin;
	NSPoint cursor = [theEvent locationInWindow];
	NSPoint currentPoint;
	NSPoint where =  [self convertPoint:cursor fromView:nil];
	NSObject *textPiece = [self textPieceForPoint:where];
	if (textPiece != nil)
	{
		self.dragKind = OCRDragEnumIBeam;
		while ([theEvent type] != NSEventTypeLeftMouseUp)
		{
			if ([theEvent type] == NSEventTypeLeftMouseDragged)
			{
				[self trackTextPiece:textPiece atPoint:where];
				where = [self convertPoint:[theEvent locationInWindow] fromView:nil];
				textPiece = [self textPieceForPoint:where];
			}
			theEvent = [[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged];
		}
		self.dragKind = OCRDragEnumNot;
	}
	else if([self dragIsPossible])
	{
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
}

/// Update the selection - called repeatedly while the mouse is down.
///
///  @param textPieceObject - the VNRecognizedTextObservation the point is in.
///  @param where - the current mouse point
- (void)trackTextPiece:(NSObject *)textPieceObject atPoint:(NSPoint)where
{
	if (@available(macOS 10.15, *))
	{
// TODO: mouse track partial textPieces
		VNRecognizedTextObservation *textPiece = (VNRecognizedTextObservation *)textPieceObject;
		NSValue *textValue = [NSValue valueWithPointer:(__bridge const void *)(textPiece)];
		OCRSelectionPiece *selectionPair = self.selectionPieces[textValue];
		if (selectionPair == nil)
		{
			selectionPair = [[OCRSelectionPiece alloc] init];
			selectionPair.start = 0.0;
			selectionPair.end = 1.0;
			self.selectionPieces[textValue] = selectionPair;
		}
		CGRect r = [self boundBoxOfPiece:textPiece];
		[self setNeedsDisplayInRect:r];
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
		return YES;
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
				NSValue *key = [NSValue valueWithPointer:(__bridge const void *)(piece)];
				OCRSelectionPiece *selectionPiece = self.selectionPieces[ key ];
				if (selectionPiece == nil)
				{
					selectionPiece = [[OCRSelectionPiece alloc] init];
					self.selectionPieces[ key ] = selectionPiece;
				}
				selectionPiece.start = 0.0;
				selectionPiece.end = 1.0;
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
