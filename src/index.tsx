import { Platform } from 'react-native';

if (Platform.OS === 'android') {
  // Fabric Bridgeless 不会从 ViewManager 常量注册自定义 DirectEvent，需手动注册。
  const {
    customDirectEventTypes,
  } = require('react-native/Libraries/Renderer/shims/ReactNativeViewConfigRegistry');
  if (customDirectEventTypes.topContentHeightChange == null) {
    customDirectEventTypes.topContentHeightChange = {
      registrationName: 'onContentHeightChange',
    };
  }
}

export { default as EnrichedMarkdownText } from './native/EnrichedMarkdownText';
export type {
  EnrichedMarkdownTextProps,
  StreamingConfig,
  MarkdownStyle,
  Md4cFlags,
  ContextMenuItem as TextContextMenuItem,
  SelectionMenuConfig as TextSelectionMenuConfig,
} from './native/EnrichedMarkdownText';
export type {
  LinkPressEvent,
  LinkLongPressEvent,
  TaskListItemPressEvent,
  ContentHeightChangeEvent,
} from './types/events';

export { EnrichedMarkdownTextInput } from './EnrichedMarkdownTextInput';
export type {
  EnrichedMarkdownTextInputProps,
  EnrichedMarkdownTextInputInstance,
  MarkdownTextInputStyle,
  StyleState,
  ContextMenuItem,
  OnLinkDetected,
  OnStartMentionEvent,
  OnChangeMentionEvent,
  OnEndMentionEvent,
  CaretRect,
} from './EnrichedMarkdownTextInput';
