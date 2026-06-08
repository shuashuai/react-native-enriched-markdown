package com.swmansion.enriched.markdown.renderer

import android.graphics.Paint
import android.text.SpannableStringBuilder
import android.text.style.LineHeightSpan
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.BlockquoteBottomPaddingSpan
import com.swmansion.enriched.markdown.spans.BlockquoteSpan
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_CONTAINER_BACKGROUND
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_LINE_METRICS
import com.swmansion.enriched.markdown.utils.text.span.applyMarginBottom
import com.swmansion.enriched.markdown.utils.text.span.applyMarginTop

class BlockquoteRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val start = builder.length
    val style = config.style.blockquoteStyle
    val context = factory.blockStyleContext
    val depth = context.blockquoteDepth

    context.blockquoteDepth = depth + 1
    context.setBlockquoteStyle(style)

    try {
      factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)
    } finally {
      context.popBlockStyle()
      context.blockquoteDepth = depth
    }

    if (builder.length == start) return

    // Collapse duplicate trailing newlines but keep the last paragraph terminator.
    // Stripping the final \n breaks line metrics on the last content line; bottom
    // padding is provided by the dedicated spacer \n appended below.
    var contentEnd = builder.length
    while (contentEnd > start + 1 &&
      builder[contentEnd - 1] == '\n' &&
      builder[contentEnd - 2] == '\n'
    ) {
      builder.delete(contentEnd - 1, contentEnd)
      contentEnd--
    }

    var blockquoteStart = start
    if (depth == 0 && style.marginTop > 0f) {
      applyMarginTop(builder, blockquoteStart, style.marginTop)
      blockquoteStart += 1
    }

    val paddingTopLength = if (depth == 0 && style.paddingTop > 0f) 1 else 0
    val paddingBottomLength = if (depth == 0 && style.paddingBottom > 0f) 1 else 0

    if (depth == 0 && style.paddingTop > 0f) {
      builder.insert(blockquoteStart, "\n")
    }
    if (depth == 0 && style.paddingBottom > 0f) {
      builder.append("\n")
    }

    val end = builder.length

    builder.setSpan(
      BlockquoteSpan(style, depth, factory.context, factory.styleCache),
      blockquoteStart,
      end,
      SPAN_FLAGS_CONTAINER_BACKGROUND,
    )

    val textStart = blockquoteStart + paddingTopLength
    val textEnd = end - paddingBottomLength

    // Fixed padding heights must be applied last so they win over paragraph line-height spans.
    if (depth == 0 && style.paddingTop > 0f) {
      applyFixedPaddingHeight(builder, blockquoteStart, blockquoteStart + 1, style.paddingTop)
    }
    if (depth == 0 && style.paddingBottom > 0f) {
      val paddingStart = end - paddingBottomLength
      applyFixedPaddingHeight(builder, paddingStart, end, style.paddingBottom)
      if (textEnd > textStart) {
        builder.setSpan(
          BlockquoteBottomPaddingSpan(style.paddingBottom),
          textEnd - 1,
          textEnd,
          SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
        )
      }
    }

    if (depth == 0) {
      applyMarginBottom(builder, style.marginBottom)
    }
  }

  private fun applyFixedPaddingHeight(
    builder: SpannableStringBuilder,
    start: Int,
    end: Int,
    padding: Float,
  ) {
    if (padding <= 0f || start >= end) return

    val paddingPixels = padding.toInt()
    builder.setSpan(
      object : LineHeightSpan {
        override fun chooseHeight(
          text: CharSequence,
          start: Int,
          end: Int,
          spanstartv: Int,
          lineHeight: Int,
          fm: Paint.FontMetricsInt,
        ) {
          // Grow the spacer line downward only. Resetting ascent to 0 pulls the
          // previous content line up and makes the last paragraph overlap.
          val currentHeight = fm.descent - fm.ascent
          val needed = paddingPixels - currentHeight
          if (needed > 0) {
            fm.descent += needed
            if (fm.bottom < fm.descent) {
              fm.bottom = fm.descent
            }
          }
        }
      },
      start,
      end,
      SPAN_FLAGS_LINE_METRICS,
    )
  }
}
