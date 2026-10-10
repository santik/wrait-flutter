import 'package:flutter/foundation.dart';

const settingsBackButtonKey = ValueKey<String>('settingsBackButton');
const transcriptionLanguageSectionKey = ValueKey<String>(
  'transcriptionLanguageSection',
);
const transcriptionLanguageDropdownKey = ValueKey<String>(
  'transcriptionLanguageDropdown',
);
const transcriptionLanguageFocusKey = ValueKey<String>(
  'transcriptionLanguageFocus',
);
const transcriptionLanguageAutomaticKey = ValueKey<String>(
  'transcriptionLanguageOption:auto',
);
const transcriptionLanguageSavingKey = ValueKey<String>(
  'transcriptionLanguageSaving',
);
const transcriptionLanguageErrorKey = ValueKey<String>(
  'transcriptionLanguageError',
);
const transcriptionLanguageRetryKey = ValueKey<String>(
  'transcriptionLanguageRetry',
);

ValueKey<String> transcriptionLanguageOptionKey(String code) =>
    ValueKey<String>('transcriptionLanguageOption:$code');
const appLockSwitchKey = ValueKey<String>('appLockSwitch');
const appLockSavingKey = ValueKey<String>('appLockSaving');
const appLockPreferenceErrorKey = ValueKey<String>('appLockPreferenceError');
const appLockDeviceSettingsKey = ValueKey<String>('appLockDeviceSettings');
