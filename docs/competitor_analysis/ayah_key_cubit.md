# AyahKeyCubit

Source: lib/src/core/audio/cubit/ayah_key_cubit.dart

## State
- `AyahKeyManagement` fields:
  - `start` (String, ayahKey e.g., "1:1")
  - `end` (String)
  - `ayahList` (List<String>)
  - `current` (String, current ayah key)
  - `lastScrolledPageNumber` (int)

Initial values read from `Hive.box('user')` keys: `last_ayah_start`, `last_ayah_end`, `last_ayah_ayah_list`, `last_ayah_current`.

## Triggers (methods)
- `changeCurrentAyahKey(String ayahKey)` — emits new current and persists `last_ayah_current` to Hive.
- `changeData(AyahKeyManagement ayahData)` — replace state and save via `saveAyahKeyChanges`.
- `saveAyahKeyChanges(AyahKeyManagement ayahData)` — writes start/end/list/current to Hive.
- `changeLastScrolledPage(int page)` — updates `lastScrolledPageNumber`.

## Dependencies
- `Hive` for persistence.

## Cross-Cubit Interaction
- Central hub for audio–text sync: UI widgets and audio sync logic write/read `current` to highlight and scroll to the active ayah.
- Typically updated by logic that maps audio time -> ayah key (using segment maps from `SegmentedResourcesManager` or other mapping utilities).

## Scroll/Highlight responsibilities
- Persists last scrolled page to avoid jarring jumps.
- Acts as the canonical source of truth for which ayah is considered "current" in the UI.