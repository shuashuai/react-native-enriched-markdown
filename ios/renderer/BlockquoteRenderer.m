#import "BlockquoteRenderer.h"
#import "BlockquoteBorder.h"
#import "FontUtils.h"
#import "ListItemRenderer.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

static NSString *const kNestedInfoDepthKey = @"depth";
static NSString *const kNestedInfoRangeKey = @"range";

@implementation BlockquoteRenderer

- (void)renderNode:(MarkdownASTNode *)node into:(NSMutableAttributedString *)output context:(RenderContext *)context
{
  NSInteger currentDepth = context.blockquoteDepth;
  context.blockquoteDepth = currentDepth + 1;

  [context setBlockStyle:BlockTypeBlockquote
                    font:[_config blockquoteFont]
                   color:[_config blockquoteColor]
            headingLevel:0];

  NSUInteger start = output.length;
  @try {
    [_rendererFactory renderChildrenOfNode:node into:output context:context];
  } @finally {
    [context clearBlockStyle];
    context.blockquoteDepth = currentDepth;
  }

  NSUInteger end = output.length;
  if (end <= start) {
    return;
  }

  [self applyStylingAndSpacing:output start:start end:end currentDepth:currentDepth];
}

#pragma mark - Styling and Spacing

- (void)applyStylingAndSpacing:(NSMutableAttributedString *)output
                         start:(NSUInteger)start
                           end:(NSUInteger)end
                  currentDepth:(NSInteger)currentDepth
{
  // Collapse duplicate trailing newlines but keep the last paragraph terminator.
  while (end > start + 1 && [output.string characterAtIndex:end - 1] == '\n' &&
         [output.string characterAtIndex:end - 2] == '\n') {
    [output deleteCharactersInRange:NSMakeRange(end - 1, 1)];
    end--;
  }

  NSUInteger blockquoteStart = start;
  NSUInteger paddingTopLength = 0;
  NSUInteger paddingBottomLength = 0;
  CGFloat paddingBottom = currentDepth == 0 ? [_config blockquotePaddingBottom] : 0;

  if (currentDepth == 0) {
    blockquoteStart += applyBlockSpacingBefore(output, start, [_config blockquoteMarginTop]);
    paddingTopLength = [self insertPaddingSpacer:output at:blockquoteStart padding:[_config blockquotePaddingTop]];
    if (paddingBottom > 0) {
      paddingBottomLength = [self appendPaddingSpacer:output padding:paddingBottom];
    }
  }

  end = output.length;
  NSRange blockquoteRange = NSMakeRange(blockquoteStart, end - blockquoteStart);
  CGFloat levelSpacing = [_config blockquoteBorderWidth] + [_config blockquoteGapWidth];
  CGFloat lineHeight = [_config blockquoteLineHeight];
  NSArray<NSDictionary *> *nestedInfo = [self collectNestedBlockquotes:output range:blockquoteRange depth:currentDepth];
  NSArray<NSValue *> *listRanges = [self collectListRanges:output range:blockquoteRange];

  [self applyBaseBlockquoteStyle:output
                           range:blockquoteRange
                           depth:currentDepth
                    levelSpacing:levelSpacing
                 backgroundColor:[_config blockquoteBackgroundColor]
                      listRanges:listRanges];

  NSUInteger contentStart = blockquoteStart + paddingTopLength;
  NSUInteger contentEnd = end - paddingBottomLength;

  // Line height on text content only — padding spacers keep their own metrics.
  if (contentEnd > contentStart && lineHeight > 0) {
    [self applyLineHeight:output
                    range:NSMakeRange(contentStart, contentEnd - contentStart)
               lineHeight:lineHeight
               listRanges:listRanges];
  }

  if (paddingTopLength > 0) {
    [self applyPaddingSpacerStyle:output
                            range:NSMakeRange(blockquoteStart, paddingTopLength)
                          padding:[_config blockquotePaddingTop]];
  }

  [self reapplyNestedStyles:output nestedInfo:nestedInfo levelSpacing:levelSpacing];

  if (paddingBottomLength > 0) {
    NSUInteger paddingStart = end - paddingBottomLength;
    [self applyPaddingSpacerStyle:output range:NSMakeRange(paddingStart, paddingBottomLength) padding:paddingBottom];
    [output addAttribute:BlockquoteBottomPaddingAttributeName
                   value:@(paddingBottom)
                   range:NSMakeRange(paddingStart, paddingBottomLength)];
  }

  if (currentDepth == 0) {
    CGFloat marginBottom = [_config blockquoteMarginBottom];
    applyBlockSpacingAfter(output, marginBottom);
    if (marginBottom > 0) {
      [output addAttribute:BlockquoteMarginBottomAttributeName
                     value:@(marginBottom)
                     range:NSMakeRange(output.length - 1, 1)];
    }
  }
}

#pragma mark - Nested Blockquote Handling

- (NSArray<NSDictionary *> *)collectNestedBlockquotes:(NSMutableAttributedString *)output
                                                range:(NSRange)blockquoteRange
                                                depth:(NSInteger)currentDepth
{
  NSMutableArray<NSDictionary *> *nestedInfo = [NSMutableArray array];

  [output
      enumerateAttribute:BlockquoteDepthAttributeName
                 inRange:blockquoteRange
                 options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
              usingBlock:^(id value, NSRange range, BOOL *stop) {
                NSInteger depth = [value integerValue];
                if (value && depth > currentDepth) {
                  [nestedInfo
                      addObject:@{kNestedInfoDepthKey : value, kNestedInfoRangeKey : [NSValue valueWithRange:range]}];
                }
              }];

  return nestedInfo;
}

- (NSArray<NSValue *> *)collectListRanges:(NSMutableAttributedString *)output range:(NSRange)range
{
  NSMutableArray<NSValue *> *listRanges = [NSMutableArray array];

  [output enumerateAttribute:ListDepthAttribute
                     inRange:range
                     options:0
                  usingBlock:^(id value, NSRange listRange, BOOL *stop) {
                    if (value) {
                      [listRanges addObject:[NSValue valueWithRange:listRange]];
                    }
                  }];

  return listRanges;
}

- (void)applyAttributes:(NSDictionary *)attributes
                toRange:(NSRange)range
        excludingRanges:(NSArray<NSValue *> *)excludedRanges
               inOutput:(NSMutableAttributedString *)output
{
  NSUInteger position = range.location;
  NSUInteger rangeEnd = NSMaxRange(range);

  for (NSValue *excludedValue in excludedRanges) {
    NSRange excludedRange = [excludedValue rangeValue];
    if (NSMaxRange(excludedRange) <= position || excludedRange.location >= rangeEnd) {
      continue;
    }

    if (position < excludedRange.location) {
      NSRange segment = NSMakeRange(position, excludedRange.location - position);
      [output addAttributes:attributes range:segment];
    }
    position = MAX(position, NSMaxRange(excludedRange));
  }

  if (position < rangeEnd) {
    [output addAttributes:attributes range:NSMakeRange(position, rangeEnd - position)];
  }
}

- (void)applyBaseBlockquoteStyle:(NSMutableAttributedString *)output
                           range:(NSRange)blockquoteRange
                           depth:(NSInteger)currentDepth
                    levelSpacing:(CGFloat)levelSpacing
                 backgroundColor:(RCTUIColor *)backgroundColor
                      listRanges:(NSArray<NSValue *> *)listRanges
{
  NSMutableDictionary *containerAttributes = [NSMutableDictionary dictionaryWithObject:@(currentDepth)
                                                                                forKey:BlockquoteDepthAttributeName];
  if (backgroundColor) {
    containerAttributes[BlockquoteBackgroundColorAttributeName] = backgroundColor;
  }
  [output addAttributes:containerAttributes range:blockquoteRange];

  CGFloat totalIndent = [self calculateIndentForDepth:currentDepth levelSpacing:levelSpacing];
  NSMutableParagraphStyle *paragraphStyle = getOrCreateParagraphStyle(output, blockquoteRange.location);
  paragraphStyle.firstLineHeadIndent = totalIndent;
  paragraphStyle.headIndent = totalIndent;

  [self applyAttributes:@{NSParagraphStyleAttributeName : paragraphStyle}
                toRange:blockquoteRange
        excludingRanges:listRanges
               inOutput:output];
}

- (void)applyLineHeight:(NSMutableAttributedString *)output
                  range:(NSRange)range
             lineHeight:(CGFloat)lineHeight
             listRanges:(NSArray<NSValue *> *)listRanges
{
  if (lineHeight <= 0) {
    return;
  }

  NSMutableParagraphStyle *style = getOrCreateParagraphStyle(output, range.location);
  style.minimumLineHeight = lineHeight;
  style.maximumLineHeight = lineHeight;

  [self applyAttributes:@{NSParagraphStyleAttributeName : style}
                toRange:range
        excludingRanges:listRanges
               inOutput:output];
}

- (NSUInteger)insertPaddingSpacer:(NSMutableAttributedString *)output at:(NSUInteger)location padding:(CGFloat)padding
{
  if (padding <= 0) {
    return 0;
  }

  NSAttributedString *spacer = [self paddingSpacerAttributedString:padding];
  [output insertAttributedString:spacer atIndex:location];
  return 1;
}

- (NSUInteger)appendPaddingSpacer:(NSMutableAttributedString *)output padding:(CGFloat)padding
{
  if (padding <= 0) {
    return 0;
  }

  NSAttributedString *spacer = [self paddingSpacerAttributedString:padding];
  [output appendAttributedString:spacer];
  return 1;
}

- (NSAttributedString *)paddingSpacerAttributedString:(CGFloat)padding
{
  NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
  style.baseWritingDirection = currentWritingDirection();
  style.minimumLineHeight = padding;
  style.maximumLineHeight = padding;
  style.paragraphSpacing = 0;

  return [[NSAttributedString alloc] initWithString:@"\n" attributes:@{NSParagraphStyleAttributeName : style}];
}

- (void)applyPaddingSpacerStyle:(NSMutableAttributedString *)output range:(NSRange)range padding:(CGFloat)padding
{
  if (padding <= 0 || range.length == 0) {
    return;
  }

  NSMutableParagraphStyle *style = getOrCreateParagraphStyle(output, range.location);
  style.minimumLineHeight = padding;
  style.maximumLineHeight = padding;
  style.paragraphSpacing = 0;
  [output addAttribute:NSParagraphStyleAttributeName value:style range:range];
}

- (void)reapplyNestedStyles:(NSMutableAttributedString *)output
                 nestedInfo:(NSArray<NSDictionary *> *)nestedInfo
               levelSpacing:(CGFloat)levelSpacing
{
  for (NSDictionary *info in nestedInfo) {
    NSRange nestedRange = [info[kNestedInfoRangeKey] rangeValue];
    NSInteger nestedDepth = [info[kNestedInfoDepthKey] integerValue];
    NSMutableParagraphStyle *style = getOrCreateParagraphStyle(output, nestedRange.location);

    CGFloat indent = [self calculateIndentForDepth:nestedDepth levelSpacing:levelSpacing];
    style.firstLineHeadIndent = indent;
    style.headIndent = indent;
    style.tailIndent = 0;

    [output
        addAttributes:@{NSParagraphStyleAttributeName : style, BlockquoteDepthAttributeName : info[kNestedInfoDepthKey]}
                range:nestedRange];
  }
}

#pragma mark - Helper Methods

- (CGFloat)calculateIndentForDepth:(NSInteger)depth levelSpacing:(CGFloat)levelSpacing
{
  return (depth + 1) * levelSpacing;
}

@end
