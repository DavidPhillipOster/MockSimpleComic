//  GraphicsMath.h
//
//  Created by David Phillip Oster on 5/17/2022
//  Copyright © 2022 David Phillip Oster. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

#import <Cocoa/Cocoa.h>

/// Given the corners of a quadrilateral, and inset ratios, return the NSBezierPath of the quad.
///
/// @param tl - top left corner of a quadrilateral
/// @param tr - top right corner of a quadrilateral
/// @param br - bottom right corner of a quadrilateral (going around it clockwise)
/// @param bl - bottom left corner
/// @param start - ratio, 0…1 to inset. 0 means the left edge.
/// @param end - ratio, 0…1 to inset. 0 means the right edge.
/// @return the NSBezierPath
NSBezierPath *OCRBezierPathFromCornersRatio(CGPoint tl, CGPoint tr, CGPoint br, CGPoint bl, CGFloat start, CGFloat end);

/// Given the corners of a quadrilateral, and a point, return a ratio: 0.0 means the left edge, 1.0 the right edge.
///
/// @param tl - top left corner of a quadrilateral
/// @param tr - top right corner of a quadrilateral
/// @param br - bottom right corner of a quadrilateral (going around it clockwise)
/// @param bl - bottom left corner
/// @param where - a point in the same coordinate system as the quad
/// @return the ratio
CGFloat OCRRatioCornersToPoint(CGPoint tl, CGPoint tr, CGPoint br, CGPoint bl, CGPoint where);
