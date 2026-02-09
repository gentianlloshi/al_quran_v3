# QuranViewCubit

Source: lib/src/screen/settings/cubit/quran_script_view_cubit.dart

## State (QuranViewState)
Key fields persisted in `Hive` and kept in state:
- `ayahKey` (String) — preview/current ayah
- `fontSize` (double)
- `translationFontSize` (double)
- `lineHeight` (double)
- `quranScriptType` (enum `QuranScriptType`)
- `hideFootnote`, `hideWordByWord`, `hideTranslation`, `hideToolbar`, `hideQuranAyah` (bools)
- `alwaysOpenWordByWord` (bool)
- `enableWordByWordHighlight` (bool)
- `scrollWithRecitation` (bool)
- `useAudioStream` (bool)
- `playbackSpeed` (double)

## Triggers (methods)
- `changeAyah(String ayah)` and helper setters that update Hive and emit state.
- `changeFontSize(double)`, `changeLineHeight(double)`, `changeQuranScriptType(QuranScriptType)`, `changeTranslationFontSize(double)`.
- `setViewOptions({...})` — atomic update for multiple view toggles; validates invalid combos (shows toast) and persists each option to Hive.

## Dependencies
- `Hive` for persistence of view options.
- `Fluttertoast` to notify on invalid option combinations.

## Cross-Cubit Interaction
- `scrollWithRecitation` and `enableWordByWordHighlight` are consulted by the audio–text sync logic and UI renderers to decide whether to auto-scroll and highlight during playback.
- Many renderers (`uthmani_view`, `tajweed_view`, page renderers) read `QuranViewCubit` state to determine visibility and layout.

## Scroll/Highlight role
- This cubit contains the user-configurable switches that determine how aggressive the auto-scroll and highlight behaviors are — thus it is effectively a policy provider for sync implementations.