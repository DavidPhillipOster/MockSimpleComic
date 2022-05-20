//  OCRedTextView.h
//  MockSimpleComic
//
//  Created by David Phillip Oster on 5/16/22.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCRedTextView : NSView

/// The selected text as a single string. Readonly, because it is selected using the mouse. nil if not available.
@property(readonly, nullable) NSString *selection;

/// all the text on the page. nil if not available.
@property(readonly, nullable) NSString *allText;

/// Run the ocr engine on the image in the default language.
- (void)ocrImage:(NSImage *)image;

/// Run the ocr engine on the CGimage in the default language.
- (void)ocrCGImage:(CGImageRef)cgImage;

@end

NS_ASSUME_NONNULL_END
