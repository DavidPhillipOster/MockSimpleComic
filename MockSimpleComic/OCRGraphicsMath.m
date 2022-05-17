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

#import "OCRGraphicsMath.h"

@class OCRPolyLine;

typedef struct LineSegmentStruct {
  CGPoint start;
  CGPoint end;
} LineSegmentStruct;

// A line segment
@interface OCRLineSegment  : NSObject<NSCopying>
@property(nonatomic) LineSegmentStruct ls;

// slope. Undefined for vertical lines.
@property(nonatomic, readonly) CGFloat m;

// intercept of the Y axis.
@property(nonatomic, readonly) CGFloat b;

- (instancetype)initWithStart:(CGPoint)start end:(CGPoint)end;

- (void)shortenStartBy:(CGFloat)amount;

- (void)shortenEndBy:(CGFloat)amount;

@end


// A PolyLine. Can also be used to represent an array of vertices.
// A Polygon triangle would have three vertices. A polyline has 4 since we explicitly lineTo at the end.
@interface OCRPolyLine : NSObject<NSCopying>
@property(nonatomic) int count;
@property(nonatomic, unsafe_unretained) CGPoint *pts;

- (void)addPt:(CGPoint)p;

- (void)insertPt:(CGPoint)p atIndex:(NSUInteger)index;

- (void)addSegmentStart:(CGPoint)pStart end:(CGPoint)pEnd;

// For each line segment, replace it by a quadrilateral that is "wider" than the line segment
// by 'amount', then merge the quadrilaterals. Analogous to setPenSize.
- (instancetype)widen:(CGFloat)amount;

// Like widen, but 'miter' the ends of the polylines by endcapAngle.
- (instancetype)widen:(CGFloat)amount endcapAngle:(CGFloat)endcapAngle;

- (NSBezierPath *)path;

@end

static const float kTiny = 1.0e-6;


// floating equals.
static BOOL feq(CGFloat a, CGFloat b) {
  return fabs(a - b) < kTiny;
}

static BOOL ArePointsEqual(CGPoint a, CGPoint b) {
  return feq(a.x, b.x) && feq(a.y, b.y);
}

static CGFloat AngleInRadians1(CGPoint first, CGPoint center) {
  first.x -= center.x;
  first.y -= center.y;
  return atan2(first.y, first.x);
}

@implementation OCRLineSegment

- (instancetype)initWithStart:(CGPoint)start end:(CGPoint)end {
  self = [super init];
  if (self) {
    LineSegmentStruct ls;
    ls.start = start;
    ls.end = end;
    self.ls = ls;
  }
  return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
  OCRLineSegment *result = [[[self class] allocWithZone:zone] init];
  result.ls = self.ls;
  return result;
}

- (BOOL)isVertical {
  return feq(self.ls.start.x, self.ls.end.x);
}

// y = m*x + b : solve for m.
// Undefined for vertical lines.
- (CGFloat)m {
  return (self.ls.start.y - self.ls.end.y)/(self.ls.start.x - self.ls.end.x);
}

// y = m*x + b : solve for b.
- (CGFloat)b {
  return [self bFromM:self.m];
}

// y - m*x = b
- (CGFloat)bFromM:(CGFloat)m {
  return self.ls.start.y - self.ls.start.x*m;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"LineSegment{%g,%g %g,%g}", _ls.start.x, _ls.start.y, _ls.end.x, _ls.end.y];
}

// true for any intersection.
- (BOOL)intersectsLine:(OCRLineSegment *)other at:(CGPoint *)outP {
  BOOL doesIntersect = NO;
  if([self isVertical] && [other isVertical]) {
    if (feq(self.ls.start.x, other.ls.end.x)) {
      outP->x = self.ls.start.x;
      outP->y = (self.ls.start.y + self.ls.end.y + other.ls.start.y + other.ls.end.y)/4;
      return YES;
    }
    return NO;  // Both are vertical. Treat them as non-intersecting.
  } else if ([self isVertical]) {
    CGFloat x = self.ls.start.x;
    CGFloat y = other.m*x + other.b;
    *outP = CGPointMake(x, y);
    doesIntersect = YES;
  } else if([other isVertical]) {
    CGFloat x = other.ls.start.x;
    CGFloat y = self.m*x + self.b;
    *outP = CGPointMake(x, y);
    doesIntersect = YES;
  } else {
    CGFloat m1 = self.m;
    CGFloat m2 = other.m;
    CGFloat b1 = self.b;
    CGFloat b2 = other.b;
    // collinear. If they have a common endpoint, prefer that. Otherwise, Just average all the xs and ys.
    if (m1 == m2 && b1 == b2) {
      if (ArePointsEqual(self.ls.end, other.ls.start) || ArePointsEqual(self.ls.end, other.ls.end)) {
        *outP = self.ls.end;
      } else if (ArePointsEqual(self.ls.start, other.ls.end) || ArePointsEqual(self.ls.start, other.ls.start)) {
        *outP = self.ls.start;
      } else {
        outP->x = (self.ls.start.x + self.ls.end.x + other.ls.start.x + other.ls.end.x)/4;
        outP->y = (self.ls.start.y + self.ls.end.y + other.ls.start.y + other.ls.end.y)/4;
      }
      doesIntersect = YES;
    } else {
      CGFloat x = (b2-b1)/(m1-m2);
      
      // This gives the intersection point of the two lines. It might still be outside either segment.
      // The 'or' is because we don't know what direction the segment goes: is start left of end or vice versa?
      CGFloat y = m1*x + b1;
      *outP = CGPointMake(x, y);
      doesIntersect = YES;
    }
  }
  return doesIntersect;
}

- (void)shortenStartBy:(CGFloat)amount {
  CGFloat dx = _ls.start.x - _ls.end.x;
  CGFloat dy = _ls.start.y - _ls.end.y;
  CGFloat length = sqrt(dx*dx + dy*dy);
  if (amount < length) {
    length -= amount;
    CGFloat theta = atan2(dy, dx);
    CGFloat x = length*cos(theta) + _ls.end.x;
    CGFloat y = length*sin(theta) + _ls.end.y;
    _ls.start.x = x;
    _ls.start.y = y;
  }
}

// Basically the same as shortenStartBy, but we're going from the other end.
- (void)shortenEndBy:(CGFloat)amount {
  CGFloat dx = _ls.end.x - _ls.start.x;
  CGFloat dy = _ls.end.y - _ls.start.y;
  CGFloat length = sqrt(dx*dx + dy*dy);
  if (amount < length) {
    length -= amount;
    CGFloat theta = atan2(dy, dx);
    CGFloat x = length*cos(theta) + _ls.start.x;
    CGFloat y = length*sin(theta) + _ls.start.y;
    _ls.end.x = x;
    _ls.end.y = y;
  }
}


@end

@implementation OCRPolyLine

- (instancetype)init {
  self = [super init];
  if (self) {
    _pts = malloc(0);
  }
  return self;
}

- (void)dealloc {
  free(_pts);
}

- (instancetype)copyWithZone:(NSZone *)zone {
  OCRPolyLine *result = [[[self class] allocWithZone:zone] init];
  result->_count = _count;
  result->_pts = (CGPoint *)realloc(result->_pts, _count*sizeof(CGPoint));
  memcpy(result->_pts, _pts, _count*sizeof(CGPoint));
  return result;
}

- (NSString *)description {
  NSMutableArray *a = [NSMutableArray array];
  for (int i = 0; i < _count;++i) {
    CGPoint p = _pts[i];
    NSString *s = [NSString stringWithFormat:@"%g,%g", p.x, p.y];
    [a addObject:s];
  }
  return [NSString stringWithFormat:@"PolyLine{%@}", [a componentsJoinedByString:@" "]];
}

- (void)addPt:(CGPoint)p {
  _count += 1;
  _pts = (CGPoint *)realloc(_pts, _count*sizeof(CGPoint));
  _pts[_count-1] = p;
}

- (void)insertPt:(CGPoint)p atIndex:(NSUInteger)index {
  _count += 1;
  _pts = (CGPoint *)realloc(_pts, _count*sizeof(CGPoint));
  memmove(&_pts[index+1], &_pts[index], ((_count-1)-index) * sizeof(CGPoint));
  _pts[index] = p;
}

- (CGPoint)lastPt {
  return _pts[_count-1];
}

- (void)addSegmentStart:(CGPoint)pStart end:(CGPoint)pEnd {
  if (0 == _count || ! ArePointsEqual([self lastPt], pStart)) {
    [self addPt:pStart];
  }
  [self addPt:pEnd];
}

- (void)shortenStartBy:(CGFloat)amount {
	if (amount != 0) {
		OCRLineSegment *segment = [[OCRLineSegment alloc] initWithStart:_pts[0] end:_pts[1]];
		[segment shortenStartBy:amount];
		_pts[0] = segment.ls.start;
  }
}

- (void)shortenEndBy:(CGFloat)amount {
	if (amount != 0) {
		NSUInteger last = _count - 1;
		OCRLineSegment *segment = [[OCRLineSegment alloc] initWithStart:_pts[last - 1] end:_pts[last]];
		[segment shortenEndBy:amount];
		_pts[last] = segment.ls.end;
  }
}


- (CGPoint)pointOffset:(CGFloat)amount fromPtAtIndex:(int)i endcapAngle:(CGFloat)endcapAngle {
  CGPoint p0 = _pts[i];
  if (i == 0) {
    CGPoint p1 = _pts[i+1];
    CGFloat angle = AngleInRadians1(p0, p1) + M_PI/2 + endcapAngle;
    CGPoint p;
    p.x = p0.x + cos(angle)*amount;
    p.y = p0.y + sin(angle)*amount;
    return p;
  } else if (i == (_count - 1)) {
    CGPoint pMinus1 = _pts[i-1];
    CGFloat angle = AngleInRadians1(pMinus1, p0) + M_PI/2 + endcapAngle;
    CGPoint p;
    p.x = p0.x + cos(angle)*amount;
    p.y = p0.y + sin(angle)*amount;
    return p;
  } else {
    CGPoint pMinus1 = _pts[i-1];
    CGFloat angleA = AngleInRadians1(pMinus1, p0) + M_PI/2;
    CGPoint pa;
    pa.x = pMinus1.x + cos(angleA)*amount;
    pa.y = pMinus1.y + sin(angleA)*amount;
    CGPoint pb;
    pb.x = p0.x + cos(angleA)*amount;
    pb.y = p0.y + sin(angleA)*amount;

	OCRLineSegment *la = [[OCRLineSegment alloc] initWithStart:pa end:pb];
    
    CGPoint p1 = _pts[i+1];
    CGFloat angle = AngleInRadians1(p0, p1) + M_PI/2;
    CGPoint pc;
    pc.x = p0.x + cos(angle)*amount;
    pc.y = p0.y + sin(angle)*amount;
    CGPoint pd;
    pd.x = p1.x + cos(angle)*amount;
    pd.y = p1.y + sin(angle)*amount;

	OCRLineSegment *lb = [[OCRLineSegment alloc] initWithStart:pc end:pd];

    CGPoint p;
    if( ! [la intersectsLine:lb at:&p]) {
      NSLog(@"-[%@ %@] : %@ %@ don't intersect", [self class], NSStringFromSelector(_cmd), la, lb);
    }
    return p;
  }
}

// For each line segment, replace it by a trapezoid that is "wider" than the line segment
// by amount. Analogous to setPenSize.

// For each vertex, increasing, create the 'south' vertex, then decreasing, create the 'north' vertex.
// for each pair of vertices, go out the appropriate distance to get two vertices on the 'border' line.
// polyline. appropriate distance: solve the trig.
- (instancetype)widen1:(CGFloat)amount endcapAngle:(CGFloat)endcapAngle {
  OCRPolyLine *result = [[OCRPolyLine alloc] init];
  amount /= 2;
  for (int i = 0; i <  _count; ++i) {
    [result addPt:[self pointOffset:amount fromPtAtIndex:i endcapAngle:endcapAngle]];
  }
  for (int i = _count-1; 0 <= i; --i) {
    [result addPt:[self pointOffset:-amount fromPtAtIndex:i endcapAngle:endcapAngle]];
  }
  [result addPt:result.pts[0]];
  return result;
}

- (instancetype)widen:(CGFloat)amount endcapAngle:(CGFloat)endcapAngle {
  return [self widen1:amount endcapAngle:endcapAngle];
}
- (instancetype)widen:(CGFloat)amount {
  return [self widen:amount endcapAngle:0];
}

- (NSBezierPath *)path {
	NSBezierPath *path = [NSBezierPath bezierPath];
	CGPoint p = self.pts[0];
	[path moveToPoint:p];
	for (int i = 1; i < (int)self.count - 1; ++i) {
		p = self.pts[i];
		[path lineToPoint:p];
	}
	[path closePath];
	return path;
}

@end

static CGPoint PointAverage(CGPoint a, CGPoint b) {
	return CGPointMake((a.x + b.x)/2, (a.y + b.y)/2);
}

static CGFloat PointDistance(CGPoint a, CGPoint b) {
	CGFloat dx = a.x - b.x;
	CGFloat dy = a.y - b.y;
	return sqrt(dx*dx + dy*dy);
}

NSBezierPath *OCRBezierPathFromCornersRatio(CGPoint tl, CGPoint tr, CGPoint br, CGPoint bl, CGFloat startRatio, CGFloat endRatio){
	CGPoint leftCenter = PointAverage(tl, bl);
	CGPoint rightCenter = PointAverage(tr, br);
	CGFloat length = PointDistance(leftCenter, rightCenter);
	CGFloat halfWidth = (PointDistance(tl, leftCenter) + PointDistance(bl, leftCenter) + PointDistance(tr, rightCenter) + PointDistance(br, rightCenter))/4;
	OCRPolyLine *polygon = [[OCRPolyLine alloc] init];
	[polygon addSegmentStart:leftCenter end:rightCenter];
	CGFloat shortenBy = startRatio * length;
	[polygon shortenStartBy:shortenBy];
	CGFloat endBy = (1.0 - endRatio) * length;
	[polygon shortenEndBy:endBy];
	polygon = [polygon widen:2*halfWidth];
	return [polygon path];
}
