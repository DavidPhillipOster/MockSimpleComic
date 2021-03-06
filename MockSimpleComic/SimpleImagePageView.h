//  SimpleImagePageView.h
//  MockSimpleComic
//
//  Created by David Phillip Oster on 5/16/22. Apache Version 2 open source license.

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// A simple imageView, that just supports scrolling and a hand-cursor for scrolling.
@interface SimpleImagePageView : NSView

@property NSImage *image;
@property NSRect imageFrame;

@property NSImage *image2;
@property NSRect image2Frame;

/// The selected text as a single string. Readonly, because it is selected using the mouse. nil if not available. always nil, for now.
@property(readonly, nullable) NSString *selection;

/// all the text on the page. nil if not available. always nil, for now.
@property(readonly, nullable) NSString *allText;

/// Run the ocr engine on the image in the default language.
- (void)ocrImage:(NSImage *)image;

/// Run the ocr engine on the image in the default language.
- (void)ocrImage2:(NSImage *)image;

@end

NS_ASSUME_NONNULL_END
