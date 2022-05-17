//  OCRedTextView.m
//  MockSimpleComic
//
//  Created by David Phillip Oster on 5/16/22.
//

#import "OCRedTextView.h"

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


static NSString *sOCRLanguage;

static NSArray<NSString *> *sOCRLanguages0;
static NSArray<NSString *> *sOCRLanguages1;

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
			sOCRLanguages0 = [VNRecognizeTextRequest supportedRecognitionLanguagesForTextRecognitionLevel:VNRequestTextRecognitionLevelAccurate revision:revision error:NULL];
			sOCRLanguages1 = [VNRecognizeTextRequest supportedRecognitionLanguagesForTextRecognitionLevel:VNRequestTextRecognitionLevelFast revision:revision error:NULL];
			sOCRLanguage = sOCRLanguages0.firstObject;
		}
	});
}

+ (NSArray<NSString *> *)ocrLanguages
{
	if (nil == sOCRLanguages0){ return @[]; }
	NSMutableSet *langs = [NSMutableSet set];
	if (nil != sOCRLanguages0)
	{
		[langs addObjectsFromArray:sOCRLanguages0];
	}
	if (nil != sOCRLanguages1)
	{
		[langs addObjectsFromArray:sOCRLanguages1];
	}
	return [[langs allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
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
		sOCRLanguage = sOCRLanguages0.firstObject;
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
				NSBezierPath *path = BezierPathFromTextObservation(piece);
				[path transformUsingAffineTransform:transform];
				OCRSelectionPiece *selectionPiece = self.selectionPieces[ [NSValue valueWithPointer:(__bridge const void *)(piece)] ];
				if (selectionPiece != nil) {
					NSBezierPath *path = BezierPathFromTextObservation(piece);
					[path transformUsingAffineTransform:transform];
					[[NSColor.yellowColor colorWithAlphaComponent:0.4] set];
					// more here.
					[path fill];
				}
			}
		}
	}
}

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

- (void)setTextPieces:(NSArray *)texts
{
	if (_textPieces != texts)
	{
		_textPieces = texts;
		[self.selectionPieces removeAllObjects];
		[self setNeedsDisplay:YES];
		[self.window invalidateCursorRectsForView:self];
		if (texts.count)
		{
			NSLog(@"\n%@", [self allText]);
		}
	}
}

- (void)handleTextRequest:(VNRequest *)request
										error:(NSError *)error
						 continuation:(void (^)(NSArray *_Nullable idx, NSError *_Nullable error))continuation  API_AVAILABLE(macos(10.15))
{
	if (error)
	{
		continuation(nil, error);
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
		continuation(pieces, nil);
	} else {
		NSString *desc = @"Unrecognized text request";
		NSError *err = [NSError errorWithDomain:@"OCRText" code:1 userInfo:@{NSLocalizedDescriptionKey : desc}];
		continuation(nil, err);
	}
}


- (void)actualOCRCGImage:(CGImageRef)image API_AVAILABLE(macos(10.15))
{
  __weak typeof(self) weakSelf = self;
  __block NSError *__autoreleasing  _Nullable *errorp = nil;
  VNRecognizeTextRequest *textRequest =
      [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError *error)
	{
    [weakSelf handleTextRequest:request error:error continuation:
      ^(NSArray *_Nullable idx, NSError *_Nullable error){
			dispatch_async(dispatch_get_main_queue(), ^{
				weakSelf.textPieces = idx;
				if (error && errorp)
				{
					*errorp = error;
				}
			});
		}];
  }];
  VNImageRequestHandler *handler  = nil;
  if (textRequest)
  {
		NSString *ocrLanguage = [[self class] ocrLanguage];
		if (ocrLanguage)
		{
			textRequest.recognitionLanguages = @[ocrLanguage];
		}
    handler = [[VNImageRequestHandler alloc] initWithCGImage:image options:@{}];
		[handler performRequests:@[textRequest] error:errorp];
  }
}

- (void)ocrImage:(NSImage *)image
{
	if(@available(macOS 10.15, *))
	{
		NSData *imageData = image.TIFFRepresentation;
		if(imageData != nil)
		{
			CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
			if (imageSource != nil)
			{
				CGImageRef imageRef =  CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
				if (imageRef != nil)
				{
					dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
						[self actualOCRCGImage:imageRef];
						CFRelease(imageRef);
					});
				}
				CFRelease(imageSource);
			}
		}
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

- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint where = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSObject *textPiece = [self textPieceForPoint:where];
	if (textPiece != nil)
	{
		[[NSCursor IBeamCursor] set];
		if (!(theEvent.modifierFlags & NSEventModifierFlagCommand))
		{
			[self.selectionPieces removeAllObjects];
			[self setNeedsDisplay:YES];
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

- (void)mouseUp:(NSEvent *)theEvent
{
	if([self dragIsPossible])
	{
		[[NSCursor openHandCursor] set];
	}
}


- (NSString *)selection
{
	return nil;
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

- (CGRect)boundBoxOfPiece:(VNRecognizedTextObservation *)piece  API_AVAILABLE(macos(10.15)){
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform scaleXBy:self.bounds.size.width yBy:self.bounds.size.height];
	CGRect r = piece.boundingBox;
	r.origin = [transform transformPoint:r.origin];
	r.size = [transform transformSize:r.size];
	return r;
}

- (void)trackTextPiece:(NSObject *)textPieceObject atPoint:(NSPoint)where {
	if (@available(macOS 10.15, *))
	{
		VNRecognizedTextObservation *textPiece = (VNRecognizedTextObservation *)textPieceObject;
		NSValue *textValue = [NSValue valueWithPointer:(__bridge const void *)(textPiece)];
		OCRSelectionPiece *selectionPair = self.selectionPieces[textValue];
		if (selectionPair == nil)
		{
			selectionPair = [[OCRSelectionPiece alloc] init];
			selectionPair.start = 0.0;
			selectionPair.end = 0.5;
			self.selectionPieces[textValue] = selectionPair;
		}
		CGRect r = [self boundBoxOfPiece:textPiece];
		[self setNeedsDisplayInRect:r];
	}
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

@end
