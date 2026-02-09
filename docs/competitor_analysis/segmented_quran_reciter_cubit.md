# SegmentedQuranReciterCubit

Source: lib/src/core/audio/cubit/segmented_quran_reciter_cubit.dart

## State
- `ReciterInfoModel` fields include:
  - `segmentsUrl` (String?)
  - `isDownloading` (bool)
  - `showAyahHilight` (String? for temporary highlight)
  - other reciter metadata (name, id, etc.)

Default initial state is from `SegmentedResourcesManager.getOpenSegmentsReciter()` or first supported reciter.

## Triggers (methods)
- `changeReciter(BuildContext context, ReciterInfoModel reciter)` — initiates download of segment resources via `SegmentedResourcesManager.downloadResources`, toggles `isDownloading`, and emits selected reciter on success.
- `getAyahSegments(String ayahKey)` — queries `SegmentedResourcesManager.getAyahSegments(ayahKey)` and returns parsed list.
- `temporaryHilightAyah(String ayah)` — sets `showAyahHilight` to temporarily highlight an ayah in UI.
- `refresh()` — emits state.copyWith() to force rebuilds.

## Dependencies
- `SegmentedResourcesManager` for segment asset management (download, retrieval).
- `getSegmentsSupportedReciters()` helper for available reciters.
- Uses `BuildContext` for download flows that present dialogs/progress.

## Cross-Cubit Interaction
- Provides segment maps consumed by audio sync logic to map playback times to precise word/ayah offsets.
- Can request temporary visual highlight via `temporaryHilightAyah` which UI listens to.

## Sync role
- If segmented recitations are available, this cubit is the authoritative source for mapping audio to text at high precision (word-level timing).