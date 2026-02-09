# Audio–Text Sync Overview & Cubit Dependencies

This short overview maps the Cubits involved in audio–text synchronization and the typical data flow used by the app.

## Key Cubits in the sync path
- `PlayerPositionCubit` — current playback positions (time, buffer, total).
- `PlayerStateCubit` — play/pause and processing state.
- `SegmentedQuranReciterCubit` — provides per-ayah/word segment maps when segmented recitations are used.
- `AyahKeyCubit` — canonical current ayah key and persisted ayah range / last scrolled page.
- `QuranViewCubit` — policy flags (`scrollWithRecitation`, `enableWordByWordHighlight`, `useAudioStream`).
- `WordPlayingStateCubit`, `AyahToHighlight` — used for fine-grained highlights.

## Typical mapping flow (audio -> highlight/scroll)
1. Audio player emits a time update → `PlayerPositionCubit.changeCurrentPosition`.
2. Sync logic (in `AudioPlayerManager` or a controller) reads `PlayerPositionCubit.state.currentDuration`.
3. If segmented recitations available, consult `SegmentedQuranReciterCubit.getAyahSegments(ayahKey)` to map time -> word/ayah.
4. Otherwise, use a fallback mapping (precomputed offsets or approximate timings).
5. Call `AyahKeyCubit.changeCurrentAyahKey(newAyahKey)` and/or `AyahToHighlight.changeAyah(...)` to update UI.
6. UI renderers observe `AyahKeyCubit` and `QuranViewCubit` policy flags; if `scrollWithRecitation` enabled, compute scroll offset from `AyahByAyahInScrollInfoCubit` and perform scrolling.

## Persistence & Offline behavior
- Many Cubits persist settings/state to `Hive` (`AyahKeyCubit`, `QuranViewCubit`, `QuickAccessCubit`, `AudioTabReciterCubit`) such that offline resumes and last positions are restored quickly.

## Observations for comparison
- The app favors Cubit/Shared-State orchestration over event streams between Cubits (no explicit cross-cubit streams; UI reads multiple Cubits directly).
- Segmented recitations provide a high-precision mapping when available; otherwise fallback heuristics are used.
- Persistence is heavy (many settings in Hive) — good for UX but increases local storage coupling.

---

Files created:
- audio_ui_cubit.md
- player_position_cubit.md
- player_state_cubit.md
- ayah_key_cubit.md
- segmented_quran_reciter_cubit.md
- quran_view_cubit.md
- ayah_by_ayah_in_scroll_info_cubit.md
- overview_sync_and_dependencies.md
