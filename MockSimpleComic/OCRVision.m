//  OCRVision.h
//
//  Created by David Phillip Oster on 5/19/2022.
//

#import "OCRVision.h"

#import <Vision/Vision.h>

static NSString *sOCRLanguage;

static NSArray<NSString *> *sOCRLanguages;

// ocrErrors use this NSError Domain
NSErrorDomain const OCRVisionDomain = @"OCRVisionDomain";

@interface OCRVisionComplete()
@property NSArray *textPieces;
@property(readwrite) NSError *ocrError;
@end

@implementation OCRVisionComplete

- (NSArray<VNRecognizedTextObservation *> *)textObservations API_AVAILABLE(macos(10.15)){
	return _textPieces ?: @[];
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
	return @"";
}

@end

@interface OCRVision()
@property NSArray *textPieces;
@property(readwrite, setter=setOCRError:) NSError *ocrError;
@end

@implementation OCRVision

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

#pragma mark OCR

- (void)callCompletion:(void (^)(OCRVisionComplete * _Nonnull))completion textPieces:(NSArray *)textPieces error:(NSError *)error
{
	OCRVisionComplete *visionComplete = [[OCRVisionComplete alloc] init];
	visionComplete.textPieces = textPieces;
	visionComplete.ocrError = error;
	completion(visionComplete);
}

/// Called by VNRecognizeTextRequest to process the result.
/// Filter the textPieces that includes actual text, and store in self.textPieces.
///
///  Since this is called on a worker queue, it delivers results on the main queue.
///
/// @param request - The VNRecognizeTextRequest
/// @param error - if non-nil, the VNRecognizeTextRequest is reporting an error.
- (void)handleTextRequest:(nullable VNRequest *)request
							 completion:(void (^)(OCRVisionComplete * _Nonnull))completion
										error:(nullable NSError *)error API_AVAILABLE(macos(10.15))
{
	if (error)
	{
		[self callCompletion:completion textPieces:nil error:error];
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
		[self callCompletion:completion textPieces:pieces error:nil];
	} else {
		NSString *desc = @"Unrecognized text request";
		NSError *err = [NSError errorWithDomain:@""
																			 code:OCRVisionErrUnrecognized
																	 userInfo:@{NSLocalizedDescriptionKey : desc}];
		[self callCompletion:completion textPieces:nil error:err];
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
- (void)actualOCRCGImage:(CGImageRef)image completion:(void (^)(OCRVisionComplete * _Nonnull))completion API_AVAILABLE(macos(10.15))
{
  __weak typeof(self) weakSelf = self;
  VNRecognizeTextRequest *textRequest =
      [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError *error)
			{
				[weakSelf handleTextRequest:request completion:completion error:error];
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
			[self callCompletion:completion textPieces:nil error:error];
		}
  } else {
		NSString *desc = @"Could not create text request";
		NSError *err = [NSError errorWithDomain:OCRVisionDomain
																			 code:OCRVisionErrNoCreate
																	 userInfo:@{NSLocalizedDescriptionKey : desc}];
		[self callCompletion:completion textPieces:nil error:err];
  }
}

- (void)setNotAvailableError
{
	NSString *desc = @"Requires macOS 10.15 or newer.";
	NSError *err = [NSError errorWithDomain:OCRVisionDomain
																		 code:OCRVisionErrNoCreate
																 userInfo:@{NSLocalizedDescriptionKey : desc}];
	/// As a side effect, sends 'done' notification.
	self.ocrError = err;
}

- (void)ocrImage:(NSImage *)image completion:(void (^)(OCRVisionComplete * _Nonnull))completion
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
						[self actualOCRCGImage:imageRef completion:completion];
						CFRelease(imageRef);
					}
					CFRelease(imageSource);
				}
			}
		});
	} else {
		[self setNotAvailableError];
	}
}

- (void)ocrCGImage:(CGImageRef)cgImage completion:(void (^)(OCRVisionComplete  * _Nonnull))completion
{
	if(@available(macOS 10.15, *))
	{
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			[self actualOCRCGImage:cgImage completion:completion];
		});
	} else {
		[self setNotAvailableError];
	}
}

@end
