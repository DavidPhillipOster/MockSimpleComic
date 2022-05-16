//  OCRedTextView.m
//  MockSimpleComic
//
//  Created by David Phillip Oster on 5/16/22.
//

#import "OCRedTextView.h"

#import <Vision/Vision.h>

/// @return the quadrilateral of the text observation as a NSBezierPath/
API_AVAILABLE(macos(10.15))
static NSBezierPath *BezierPathFromTextObservation(VNRecognizedTextObservation *piece) {
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

@interface OCRedTextView()

/// <VNRecognizedTextObservation *> - 10.15 and newer
@property(nonatomic) NSArray *textPieces;
@end

@implementation OCRedTextView

+ (void)initialize {
	[super initialize];
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if (@available(macOS 10.15, *))
		{
			VNRecognizeTextRequest *textRequest =
				[[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError *error) {}];
			textRequest.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
			sOCRLanguages0 = textRequest.recognitionLanguages;
			textRequest.recognitionLevel = VNRequestTextRecognitionLevelFast;
			sOCRLanguages1 = textRequest.recognitionLanguages;
			sOCRLanguage = sOCRLanguages0.firstObject;
		}
	});
}

+ (NSArray<NSString *> *)ocrLanguages {
	if (nil == sOCRLanguages0) { return @[]; }
	NSMutableSet *langs = [NSMutableSet set];
	if (nil != sOCRLanguages0) {
		[langs addObjectsFromArray:sOCRLanguages0];
	}
	if (nil != sOCRLanguages1) {
		[langs addObjectsFromArray:sOCRLanguages1];
	}
	return [[langs allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

+ (NSString *)ocrLanguage {
	return sOCRLanguage;
}

+ (void)setOCRLanguage:(NSString *)ocrLanguage {
	if (nil != ocrLanguage) {
		if ([[self ocrLanguages] containsObject:ocrLanguage]) {
			sOCRLanguage = ocrLanguage;
		}
	} else {
		sOCRLanguage = sOCRLanguages0.firstObject;
	}
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	[self initOCRedTextView];
	return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	[self initOCRedTextView];
	return self;
}

- (void)initOCRedTextView {
	self.layer.backgroundColor = NSColor.redColor.CGColor;
}

- (void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
	[[NSColor.yellowColor colorWithAlphaComponent:0.4] set];
	if (self.textPieces == nil) {
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
				[path fill];
			}
		}
	}
}

- (NSString *)allText {
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

- (void)setTextPieces:(NSArray *)texts {
	if (_textPieces != texts) {
		_textPieces = texts;
		if (texts.count)
		{
			[self setNeedsDisplay:YES];
			NSLog(@"\n%@", [self allText]);
		}
	}
}

- (void)handleTextRequest:(VNRequest *)request
										error:(NSError *)error
						 continuation:(void (^)(NSArray *_Nullable idx, NSError *_Nullable error))continuation  API_AVAILABLE(macos(10.15)){
	if (error)
	{
		continuation(nil, error);
	} else if ([request isKindOfClass:[VNRecognizeTextRequest class]]) {
		VNRecognizeTextRequest *textRequests = (VNRecognizeTextRequest *)request;
		NSMutableArray<VNRecognizedTextObservation *> *pieces = [NSMutableArray array];
		NSArray *results = textRequests.results;
		for (id rawResult in results) {
			if ([rawResult isKindOfClass:[VNRecognizedTextObservation class]])
			{
				VNRecognizedTextObservation *textO = (VNRecognizedTextObservation *)rawResult;
				NSArray<VNRecognizedText *> *text1 = [textO topCandidates:1];
				if (text1.count) {
					[pieces addObject:textO];
				}
			}
		}
		continuation(pieces, nil);
	}
	else
	{
		NSString *desc = @"Unrecognized text request";
		NSError *err = [NSError errorWithDomain:@"OCRText" code:1 userInfo:@{NSLocalizedDescriptionKey : desc}];
		continuation(nil, err);
	}
}


- (void)actualOCRCGImage:(CGImageRef)image API_AVAILABLE(macos(10.15)) {
  __weak typeof(self) weakSelf = self;
  __block NSError *__autoreleasing  _Nullable *errorp = nil;
  VNRecognizeTextRequest *textRequest =
      [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError *error) {
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
  if (textRequest) {
    handler = [[VNImageRequestHandler alloc] initWithCGImage:image options:@{}];
		[handler performRequests:@[textRequest] error:errorp];
  }
}

- (void)ocrImage:(NSImage *)image {
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

- (void)ocrCGImage:(CGImageRef)cgImage {
	if(@available(macOS 10.15, *))
	{
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			[self actualOCRCGImage:cgImage];
		});
	}
}


- (NSString *)selection {
	return nil;
}

@end
