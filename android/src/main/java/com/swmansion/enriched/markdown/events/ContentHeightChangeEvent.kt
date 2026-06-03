package com.swmansion.enriched.markdown.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

class ContentHeightChangeEvent(
  surfaceId: Int,
  viewId: Int,
  private val height: Float,
) : Event<ContentHeightChangeEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap {
    val eventData: WritableMap = Arguments.createMap()
    eventData.putDouble("height", height.toDouble())
    return eventData
  }

  companion object {
    const val EVENT_NAME: String = "topContentHeightChange"
  }
}
