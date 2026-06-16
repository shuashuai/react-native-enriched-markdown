package com.swmansion.enriched.markdown.renderer

import android.content.Context
import android.text.SpannableString
import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.BlockquoteBottomPaddingSpan
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.spans.MarginBottomSpan
import com.swmansion.enriched.markdown.styles.StyleConfig

class Renderer {
  private var cachedFactory: RendererFactory? = null
  private var cachedStyle: StyleConfig? = null
  private var cachedContext: Context? = null

  private val collectedImageSpans = mutableListOf<ImageSpan>()
  private var lastElementMarginBottom: Float = 0f

  fun configure(
    style: StyleConfig,
    context: Context,
  ) {
    if (cachedStyle === style && cachedContext === context) return

    cachedStyle = style
    cachedContext = context
    cachedFactory =
      RendererFactory(
        RendererConfig(style),
        context,
      ) { span -> reportImageSpan(span) }
  }

  fun renderDocument(
    document: MarkdownASTNode,
    onLinkPress: ((String) -> Unit)? = null,
    onLinkLongPress: ((String) -> Unit)? = null,
  ): SpannableString {
    val factory =
      requireNotNull(cachedFactory) {
        "Renderer must be configured with a style before calling renderDocument."
      }

    factory.resetForNewRender()
    collectedImageSpans.clear()
    lastElementMarginBottom = 0f

    val builder = SpannableStringBuilder()

    renderNode(document, builder, onLinkPress, onLinkLongPress, factory)

    // Remove trailing margin from last block element
    removeTrailingMargin(builder)

    // Flush deferred spans (e.g. BaselineShiftSpan) after all block-level spans are set.
    // See BaselineShiftRenderer for context and the proper long-term fix.
    factory.flushDeferredSpans(builder)

    return SpannableString(builder)
  }

  /** Removes trailing margin spacing while preserving blockquote bottom padding spacer lines. */
  private fun removeTrailingMargin(builder: SpannableStringBuilder) {
    if (builder.isEmpty()) return

    val lastSpan =
      builder
        .getSpans(0, builder.length, MarginBottomSpan::class.java)
        .maxByOrNull { builder.getSpanEnd(it) }

    val blockquotePaddingSpan =
      builder
        .getSpans(0, builder.length, BlockquoteBottomPaddingSpan::class.java)
        .maxByOrNull { builder.getSpanStart(it) }

    lastElementMarginBottom = lastSpan?.marginBottom ?: 0f

    val preserveBlockquotePaddingSpacer = blockquotePaddingSpan != null

    // Strip only the document-end margin spacer. Blockquote bottom padding uses a
    // dedicated \n with fixed line height (same strategy as paddingTop) and must
    // survive trimming — deleting it removes the inset entirely on Android.
    if (lastSpan != null) {
      val marginStart = builder.getSpanStart(lastSpan)
      val marginEnd = builder.getSpanEnd(lastSpan)
      if (
        marginEnd == builder.length &&
        marginStart >= 0 &&
        marginEnd - marginStart == 1 &&
        builder[marginStart] == '\n'
      ) {
        builder.delete(marginStart, marginEnd)
        builder.removeSpan(lastSpan)
      }
    }

    if (!preserveBlockquotePaddingSpacer) {
      while (builder.endsWith('\n')) {
        builder.delete(builder.length - 1, builder.length)
      }
    }
  }

  /**
   * Returns the marginBottom value of the last element in the document.
   * This is dynamically determined from the actual last element (paragraph, image, heading, etc.)
   * and can be used in MeasurementStore to adjust the measured height.
   */
  fun getLastElementMarginBottom(): Float = lastElementMarginBottom

  private fun renderNode(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    factory.getRenderer(node).render(node, builder, onLinkPress, onLinkLongPress, factory)
  }

  /**
   * Internal helper used by the Factory's lambda to collect spans.
   */
  private fun reportImageSpan(span: ImageSpan) {
    collectedImageSpans.add(span)
  }

  /**
   * Provides the EnrichedMarkdownText with the exact list of spans that need registration.
   */
  fun getCollectedImageSpans(): List<ImageSpan> = collectedImageSpans
}
