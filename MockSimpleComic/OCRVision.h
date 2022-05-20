//  OCRVision.h
//
//  Created by David Phillip Oster on 5/19/2022
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// OCRedTextView use this NSError Domain
extern NSErrorDomain const OCRVisionDomain;

enum {
	OCRVisionErrUnrecognized = 1,
	OCRVisionErrNoCreate,
	OCRVisionErrNotAvailable
};

@class VNRecognizedTextObservation;

/// When the  OCR is complete, it will pass your continuation block an object that resp.
///
/// Usage note: you should make a new OCRVision for each image. You can release it when you've gotten the text out of it.
@interface OCRVisionComplete :NSObject

/// all the text on the page. nil if not available.
@property(readonly) NSString *allText;

/// non-nil if an error occurred OCR'ing the image.
@property(readonly, nullable) NSError *ocrError;

/// Once an OCR operation completes, the individual lines of text.
- (NSArray<VNRecognizedTextObservation *> *)textObservations API_AVAILABLE(macos(10.15));

@end

/// Wrap up the Vision OCR framework in a  simple API
@interface OCRVision : NSObject

/// The list of languages the VisionFramework will accept. en_US is the default. Empty array means the VisionFramework is not available.
@property(class, readonly) NSArray<NSString *> *ocrLanguages;

/// The language the VisionFramework will use. getting nil means the VisionFramework is not available. setting nil restores default.
@property(class, nullable, setter=setOCRLanguage:) NSString *ocrLanguage;


/// Run the ocr engine on the image in the default language. When it's done, call the completion passing an object that implements the OCRVisionComplete protocol
///
///  Note: does its work on a background concurrent GCD queue. Completion is called on that queue.
///
/// @param image - the image to OCR
/// @param completion - a block passed an object that corresponds to the OCRVision protocol.
- (void)ocrImage:(NSImage *)image completion:(void (^)(OCRVisionComplete * _Nonnull ocrDone))completion;

/// Run the ocr engine on the image in the default language. When it's done, call the completion passing an object that implements the OCRVisionComplete protocol
///
///  Note: does its work on a background concurrent GCD queue. Completion is called on that queue.
///
/// @param cgImage - the image to OCR
/// @param completion - a block passed an object that corresponds to the OCRVision protocol.
- (void)ocrCGImage:(CGImageRef)cgImage completion:(void (^)(OCRVisionComplete * _Nonnull ocrDone))completion;

@end

NS_ASSUME_NONNULL_END
