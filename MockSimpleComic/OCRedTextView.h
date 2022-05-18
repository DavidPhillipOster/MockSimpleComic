//  OCRedTextView.h
//  MockSimpleComic
//
//  Created by David Phillip Oster on 5/16/22.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// OCRedTextView use this NSError Domain
extern NSErrorDomain const OCRedTextDomain;

enum {
	OCRedTextErrUnrecognized = 1,
	OCRedTextErrNoCreate,
	OCRedTextErrNotAvailable
};

// Sent when OCR'ing is complete. Object is the OCRedTextView.
extern NSNotificationName const OCRTextCompleteNotification;

@interface OCRedTextView : NSView
/// The list of languages the VisionFramework will accept. en_US is the default. Empty array means the VisionFramework is not available.
@property(class, readonly) NSArray<NSString *> *ocrLanguages;

/// The language the VisionFramework will use. getting nil means the VisionFramework is not available. setting nil restores default.
@property(class, nullable, setter=setOCRLanguage:) NSString *ocrLanguage;

/// The selected text as a single string. Readonly, because it is selected using the mouse. nil if not available.
@property(readonly, nullable) NSString *selection;

/// all the text on the page. nil if not available.
@property(readonly, nullable) NSString *allText;

/// non-nil if an error occurred OCR'ing the image.
@property(readonly, nullable) NSError *ocrError;

/// Run the ocr engine on the image in the default language.
- (void)ocrImage:(NSImage *)image;

/// Run the ocr engine on the CGimage in the default language.
- (void)ocrCGImage:(CGImageRef)cgImage;

@end

NS_ASSUME_NONNULL_END
