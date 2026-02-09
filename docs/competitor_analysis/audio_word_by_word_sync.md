**Audio Word-by-Word Sync**

- **Overview:**: The app uses per-ayah segment maps (word index + start/end ms) + a position stream from `just_audio` to highlight words in real time. It autoscrolls at ayah boundaries, not per-word.

- **Audio engine:**: Uses `just_audio` and `just_audio_background` with `LockCachingAudioSource` for remote caching when appropriate. See [lib/src/core/audio/player/audio_player_manager.dart](lib/src/core/audio/player/audio_player_manager.dart#L1-L240).

- **Segment storage & format:**: Segmented resources are persisted in a Hive box managed by `SegmentedResourcesManager` and exposed via `getAyahSegments(ayahKey)`.
  - **Location:**: [lib/src/utils/quran_resources/segmented_resources_manager.dart](lib/src/utils/quran_resources/segmented_resources_manager.dart#L1-L200)
  - **Shape:**: Each ayah entry contains a `segments` array; each segment is a 3-value list: `[wordIndex, startMs, endMs]` (milliseconds). Renderers convert values to ints and to Durations when comparing.

- **Position propagation:**: `AudioPlayerManager.startListeningAudioPlayerState()` subscribes to `audioPlayer.positionStream` and updates `PlayerPositionCubit` via `changeCurrentPosition(...)` (decisecond rounding used). See [lib/src/core/audio/player/audio_player_manager.dart](lib/src/core/audio/player/audio_player_manager.dart#L48-L66).

- **Highlight triggering (word-level):**:
  - **Renderer check:** Page renderers (e.g., `UthmaniPageRenderer`) build a `BlocBuilder<PlayerPositionCubit, ...>` with a `buildWhen` that:
    - ensures word-by-word highlighting is enabled and the in-app player is active,
    - checks the current ayah is on the visible page,
    - iterates that ayah's `segments` and finds the segment where `startMs < currentDuration < endMs`.
  - **Effect:** When a matching segment is found the renderer sets a `highlightingWord` key (`"<ayahKey>:<wordIndex>"`) and rebuilds; the `TextSpan` for the matching word applies a highlight style. See renderer logic: [lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart](lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart#L1-L220).

- **Autoscroll behavior:**
  - **Per-ayah autoscroll:** `audioPlayer.currentIndexStream` updates `AyahKeyCubit` with the current ayah for playlist playback. `QuranScriptView` listens to `AyahKeyCubit` and calls `scrollToAyah(...)` via `ItemScrollController.scrollTo(...)`, so the UI scrolls when playback advances to a new ayah. See: [lib/src/core/audio/player/audio_player_manager.dart](lib/src/core/audio/player/audio_player_manager.dart#L98-L120) and [lib/src/screen/quran_script_view/quran_script_view.dart](lib/src/screen/quran_script_view/quran_script_view.dart#L120-L200).
  - **Per-word autoscroll:** There is no automatic per-word scrolling; only the in-place word gets highlighted. The app does call `temporaryHilightAyah(...)` on the segmented reciter cubit when ayah changes to support visual emphasis but not per-word scroll. See `SegmentedQuranReciterCubit.temporaryHilightAyah`: [lib/src/core/audio/cubit/segmented_quran_reciter_cubit.dart](lib/src/core/audio/cubit/segmented_quran_reciter_cubit.dart#L1-L80).

- **Manual scroll & user interaction handling:**
  - The renderer's `buildWhen` returns false if `AudioUiCubit.state.isInsideQuranPlayer` is false (i.e., highlighting is disabled when player UI not in Quran context).
  - `QuranScriptView` tracks `scrolledAyahOnAudioPlay` to avoid re-scrolling the same ayah repeatedly and uses `ItemPositionsListener` to avoid scrolling if the ayah is already visible. See: [lib/src/screen/quran_script_view/quran_script_view.dart](lib/src/screen/quran_script_view/quran_script_view.dart#L1-L220).

- **Special cases & details:**
  - **Word playback (`playWord`)**: plays a single-word remote audio source via `AudioPlayerManager.playWord(...)`. That method stops normal listening and plays the single word audio separately; word playback uses `WordPlayingStateCubit`. See: [lib/src/core/audio/player/audio_player_manager.dart](lib/src/core/audio/player/audio_player_manager.dart#L180-L240).
  - **Seeking & speed changes:** Position updates come from `positionStream` so seeks and speed changes update `PlayerPositionCubit` and the highlight will switch accordingly (comparison uses millisecond ranges).
  - **Missing segments:** If `getAyahSegments` returns null, no word highlighting is applied; the UI falls back to normal rendering.

- **Key symbols / functions:**
  - `SegmentedResourcesManager.getAyahSegments(ayahKey)` — retrieve segments
  - `AudioPlayerManager.startListeningAudioPlayerState()` — subscribes to position/currentIndex streams
  - `PlayerPositionCubit.state.currentDuration` — used by renderers to detect current word
  - `AyahKeyCubit` — current ayah; used to trigger page/ayah scroll

- **Recommendation / notes for maintenance:**
  - Ensure segment timestamps are in milliseconds and synchronized with delivered audio files (encoding/resampling can shift timings).
  - If you want smooth per-word autoscroll (center word into view), add a short debounce on position updates and call a per-word scroll only when the target word is off-screen (use `ItemPositionsListener` to check visibility).

---

Generated by code inspection of the repository files referenced above.
