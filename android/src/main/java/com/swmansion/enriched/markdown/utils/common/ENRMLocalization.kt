package com.swmansion.enriched.markdown.utils.common

import android.content.Context
import com.swmansion.enriched.markdown.R

object ENRMLocalization {
  fun copy(context: Context): String = context.getString(R.string.enrm_copy)

  fun copyAsMarkdown(context: Context): String = context.getString(R.string.enrm_copy_as_markdown)

  fun copyImageUrl(context: Context): String = context.getString(R.string.enrm_copy_image_url)

  fun copyImageUrls(
    context: Context,
    count: Int,
  ): String = context.resources.getQuantityString(R.plurals.enrm_copy_image_urls, count, count)
}
