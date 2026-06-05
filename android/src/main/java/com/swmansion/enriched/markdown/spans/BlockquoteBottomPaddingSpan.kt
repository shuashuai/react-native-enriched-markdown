package com.swmansion.enriched.markdown.spans

import android.text.TextPaint
import android.text.style.CharacterStyle

/** Marks blockquote content that needs bottom padding preserved after trailing newlines are trimmed. */
class BlockquoteBottomPaddingSpan(
  val padding: Float,
) : CharacterStyle() {
  override fun updateDrawState(tp: TextPaint?) {}
}
