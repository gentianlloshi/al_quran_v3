# AudioUiCubit

Source: lib/src/core/audio/cubit/audio_ui_cubit.dart

## State
- `AudioControllerUiState` fields:
  - `isExpanded` (bool)
  - `showUi` (bool)
  - `isPlayList` (bool)
  - `isInsideQuranPlayer` (bool)

## Triggers (methods)
- `expand(bool toChange)` — toggles `isExpanded`.
- `showUI(bool toChange)` — toggles `showUi`.
- `isPlayList(bool toChange)` — toggles `isPlayList`.
- `changeIsInsideQuran(bool toChange)` — toggles `isInsideQuranPlayer`.

## Dependencies
- None external. Pure UI state holder used by widgets.

## Cross-Cubit Interaction
- Read by UI and combined with `PlayerStateCubit` and `PlayerPositionCubit` values to render audio controls.
- No direct subscriptions to other Cubits.

## Where used
- Audio widgets and `surah_info_header` read this cubit to decide when to show expanded player UI and whether the UI is inside the Quran reader.

## Notes
- Lightweight cubit: good candidate for keeping ephemeral UI flags separate from persistent playback state.