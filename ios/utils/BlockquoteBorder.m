#import "BlockquoteBorder.h"
#import "StyleConfig.h"
#import <React/RCTI18nUtil.h>

// Attribute constants for identifying blockquote segments in text storage
NSString *const BlockquoteDepthAttributeName = @"BlockquoteDepth";
NSString *const BlockquoteBackgroundColorAttributeName = @"BlockquoteBackgroundColor";
NSString *const BlockquoteBottomPaddingAttributeName = @"BlockquoteBottomPadding";
NSString *const BlockquoteMarginBottomAttributeName = @"BlockquoteMarginBottom";

@implementation BlockquoteBorder {
  StyleConfig *_config;
}

- (instancetype)initWithConfig:(StyleConfig *)config
{
  if (self = [super init]) {
    _config = config;
  }
  return self;
}

/**
 * Main drawing entry point called by the LayoutManager.
 * Iterates through line fragments to draw backgrounds and borders for nested blockquotes.
 */
- (void)drawBordersForGlyphRange:(NSRange)glyphsToShow
                   layoutManager:(NSLayoutManager *)layoutManager
                   textContainer:(NSTextContainer *)textContainer
                         atPoint:(CGPoint)origin
{
  NSTextStorage *textStorage = layoutManager.textStorage;
  if (!textStorage || textStorage.length == 0) {
    return;
  }

  // Cache configuration values to minimize pointer chasing and method lookups in the loop
  StyleConfig *c = _config;
  CGFloat borderWidth = c.blockquoteBorderWidth;
  CGFloat gapWidth = c.blockquoteGapWidth;
  CGFloat levelSpacing = borderWidth + gapWidth;
  CGFloat containerWidth = textContainer.size.width;
  RCTUIColor *defaultBgColor = c.blockquoteBackgroundColor;
  RCTUIColor *borderColor = c.blockquoteBorderColor;

  BOOL isRTL = [[RCTI18nUtil sharedInstance] isRTL];

  // Use a Bezier path to batch all vertical border rectangles into a single GPU draw call
  UIBezierPath *borderPath = [UIBezierPath bezierPath];

  [layoutManager
      enumerateLineFragmentsForGlyphRange:glyphsToShow
                               usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *container,
                                            NSRange glyphRange, BOOL *stop) {
                                 // Map the glyph range back to character indices to retrieve attributes
                                 NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                                               actualGlyphRange:NULL];
                                 if (charRange.location == NSNotFound || charRange.length == 0) {
                                   return;
                                 }

                                 // Perform a single attribute lookup for the current line fragment
                                 NSDictionary *attrs = [textStorage attributesAtIndex:charRange.location
                                                                       effectiveRange:NULL];
                                 NSNumber *depthNum = attrs[BlockquoteDepthAttributeName];

                                 // If no depth is found, this fragment is not part of a blockquote
                                 if (!depthNum) {
                                   return;
                                 }

                                 NSInteger depth = [depthNum integerValue];
                                 CGFloat baseY = origin.y + rect.origin.y;
                                 CGFloat fillHeight = MAX(rect.size.height, usedRect.size.height);

                                 // Markers can sit on the trailing \n, not the first char of the line.
                                 NSNumber *bottomPadding = nil;
                                 NSParagraphStyle *paragraphStyle = attrs[NSParagraphStyleAttributeName];
                                 NSUInteger charRangeEnd = NSMaxRange(charRange);
                                 for (NSUInteger idx = charRange.location; idx < charRangeEnd; idx++) {
                                   NSNumber *marker = [textStorage attribute:BlockquoteBottomPaddingAttributeName
                                                                     atIndex:idx
                                                              effectiveRange:NULL];
                                   if (marker) {
                                     bottomPadding = marker;
                                     NSParagraphStyle *markerStyle =
                                         [textStorage attribute:NSParagraphStyleAttributeName
                                                        atIndex:idx
                                                 effectiveRange:NULL];
                                     if (markerStyle) {
                                       paragraphStyle = markerStyle;
                                     }
                                     break;
                                   }
                                 }

                                 if (bottomPadding) {
                                   CGFloat paddingValue = [bottomPadding floatValue];
                                   if (paragraphStyle.paragraphSpacing > 0) {
                                     fillHeight += paragraphStyle.paragraphSpacing;
                                   } else if (paragraphStyle.minimumLineHeight > 0) {
                                     fillHeight = MAX(fillHeight, paragraphStyle.minimumLineHeight);
                                   } else {
                                     fillHeight = MAX(fillHeight, paddingValue);
                                   }
                                 } else if (paragraphStyle.paragraphSpacing > 0) {
                                   // Document-end fallback after trailing newlines are trimmed.
                                   fillHeight += paragraphStyle.paragraphSpacing;
                                 }

                                 // 1. Draw Background (Painter's algorithm: draw backgrounds before borders)
                                 RCTUIColor *bgColor = attrs[BlockquoteBackgroundColorAttributeName] ?: defaultBgColor;
                                 if (bgColor && bgColor != [RCTUIColor clearColor]) {
                                   CGContextRef ctx = UIGraphicsGetCurrentContext();
                                   [bgColor setFill];
                                   CGContextFillRect(ctx, CGRectMake(origin.x, baseY, containerWidth, fillHeight));
                                 }

                                 // 2. Aggregate vertical borders into the batch path
                                 for (NSInteger level = 0; level <= depth; level++) {
                                   CGFloat borderX =
                                       isRTL ? origin.x + containerWidth - borderWidth - (levelSpacing * level)
                                             : origin.x + (levelSpacing * level);
                                   CGRect borderRect = CGRectMake(borderX, baseY, borderWidth, fillHeight);
                                   UIBezierPathAppendPath(borderPath, [UIBezierPath bezierPathWithRect:borderRect]);
                                 }
                               }];

  // 3. Perform a single batch fill for all borders
  if (!borderPath.isEmpty) {
    [borderColor setFill];
    [borderPath fill];
  }
}

@end