**Cubits Analysis — Harta e Logjikës dhe Varësive**

Ky dokument përmbledh Cubit-et kryesore të projektit, fushat e tyre të gjendjes, metodave që e ndryshojnë gjendjen, varësitë e jashtme, dhe mënyrën si ndikojnë në sinkronizimin audio–tekst (scroll/highlight).

- **AudioUiCubit**: [lib/src/core/audio/cubit/audio_ui_cubit.dart](lib/src/core/audio/cubit/audio_ui_cubit.dart#L1)
  - **State:** `AudioControllerUiState` fields: `isExpanded`, `showUi`, `isPlayList`, `isInsideQuranPlayer`.
  - **Trigger-at:** `expand(bool)`, `showUI(bool)`, `isPlayList(bool)`, `changeIsInsideQuran(bool)`.
  - **Dependency Mapping:** None external; simple UI state holder.
  - **Cross-Cubit Interaction:** Read by UI widgets to switch audio UI; coordinates with `PlayerStateCubit`/`PlayerPositionCubit` via UI but has no direct subscriptions.

- **PlayerPositionCubit**: [lib/src/core/audio/cubit/player_position_cubit.dart](lib/src/core/audio/cubit/player_position_cubit.dart#L1)
  - **State:** `AudioPlayerPositionModel` with `currentDuration`, `bufferDuration`, `totalDuration`.
  - **Trigger-at:** `changeCurrentPosition(Duration?)`, `changeBufferPosition(Duration?)`, `changeTotalDuration(Duration?)`, `changeData(AudioPlayerPositionModel)`.
  - **Dependency Mapping:** No external services; fed by audio player callbacks in UI/manager.
  - **Cross-Cubit Interaction:** Consumed by UI and possibly logic that computes word-by-word sync; used alongside `AyahKeyCubit` to map position -> ayah.

- **PlayerStateCubit**: [lib/src/core/audio/cubit/player_state_cubit.dart](lib/src/core/audio/cubit/player_state_cubit.dart#L1)
  - **State:** `PlayerState` with `ProcessingState? state` (from just_audio) and `bool isPlaying`.
  - **Trigger-at:** `changeState({ProcessingState?, bool?})`.
  - **Dependency Mapping:** `just_audio` types only; no service calls.
  - **Cross-Cubit Interaction:** Drives UI play/pause visuals; paired with `PlayerPositionCubit` and `AudioUiCubit`.

- **AyahKeyCubit**: [lib/src/core/audio/cubit/ayah_key_cubit.dart](lib/src/core/audio/cubit/ayah_key_cubit.dart#L1)
  - **State:** `AyahKeyManagement` fields: `start`, `end`, `ayahList` (List<String>), `current` (current ayah key), `lastScrolledPageNumber`.
  - **Trigger-at:** `changeCurrentAyahKey(String)`, `changeData(AyahKeyManagement)`, `saveAyahKeyChanges(...)`, `changeLastScrolledPage(int)`.
  - **Dependency Mapping:** Uses `Hive` for persistence (`Hive.box('user')`) — reads/writes last ayah range/current on changes.
  - **Cross-Cubit Interaction:** Central to audio–text sync: UI/audio layers read `AyahKeyCubit.state.current` to highlight current ayah; `PlayerPositionCubit` + segment info map durations to ayah keys then call `changeCurrentAyahKey`.
  - **Scroll/Highlight:** Also tracks `lastScrolledPageNumber` and persists current ayah — used by scroll logic to avoid jumping unnecessarily.

- **SegmentedQuranReciterCubit**: [lib/src/core/audio/cubit/segmented_quran_reciter_cubit.dart](lib/src/core/audio/cubit/segmented_quran_reciter_cubit.dart#L1)
  - **State:** `ReciterInfoModel` (reciter metadata, `segmentsUrl`, flags such as `isDownloading`, `showAyahHilight`).
  - **Trigger-at:** `changeReciter(BuildContext, ReciterInfoModel)` (downloads segment resources via manager), `getAyahSegments(String)`, `temporaryHilightAyah(String)`, `refresh()`.
  - **Dependency Mapping:** `SegmentedResourcesManager` (resource manager for segmented recitations) and `getSegmentsSupportedReciters()` helper; uses Flutter `BuildContext` for download flows.
  - **Cross-Cubit Interaction:** Produces segment data used by audio sync logic and `AyahKeyCubit` to map audio positions to words/ayahs; `temporaryHilightAyah` can be used to visually highlight an ayah temporarily in UI.

- **QuranViewCubit**: [lib/src/screen/settings/cubit/quran_script_view_cubit.dart](lib/src/screen/settings/cubit/quran_script_view_cubit.dart#L1)
  - **State:** `QuranViewState` with many view options: `ayahKey`, `fontSize`, `translationFontSize`, `lineHeight`, `quranScriptType`, `hideFootnote`, `hideWordByWord`, `hideTranslation`, `hideToolbar`, `hideQuranAyah`, `alwaysOpenWordByWord`, `enableWordByWordHighlight`, `scrollWithRecitation`, `useAudioStream`, `playbackSpeed`.
  - **Trigger-at:** `changeAyah`, `changeFontSize`, `changeLineHeight`, `changeQuranScriptType`, `changeTranslationFontSize`, `setViewOptions(...)`.
  - **Dependency Mapping:** Persists settings using `Hive` and uses `Fluttertoast` for invalid combos.
  - **Cross-Cubit Interaction:** The flags `scrollWithRecitation` and `enableWordByWordHighlight` are key toggles for audio–text sync behavior: UI and audio sync code check these to determine whether to auto-scroll/highlight during playback.
  - **Scroll/Highlight:** Controls whether scrolling-with-recitation is enabled and whether highlights appear; state changes are persisted and read by rendering widgets.

- **AyahByAyahInScrollInfoCubit**: [lib/src/screen/quran_script_view/cubit/ayah_by_ayah_in_scroll_info_cubit.dart](lib/src/screen/quran_script_view/cubit/ayah_by_ayah_in_scroll_info_cubit.dart#L1)
  - **State:** `AyahByAyahInScrollInfoState` with `isAyahByAyah` (bool), `surahInfoModel`, `expandedForWordByWord`, `pageByPageList`, `dropdownAyahKey`.
  - **Trigger-at:** `setData(...)` (updates multiple fields; persists `isAyahByAyah` to Hive).
  - **Dependency Mapping:** `Hive` for persistence; `SurahInfoModel` used to compute page/ayah mapping.
  - **Cross-Cubit Interaction:** Provides data used for fine-grained scrolling (ayah-by-ayah) and word-by-word expansion; consumed by page renderers to map ayah keys to scroll offsets.
  - **Scroll/Highlight:** Contains page lists and dropdown targets used by scroll logic to compute exact scroll positions.

- **AyahToHighlight**: [lib/src/screen/quran_script_view/cubit/ayah_to_highlight.dart](lib/src/screen/quran_script_view/cubit/ayah_to_highlight.dart#L1)
  - **State:** `String?` (single ayah key to highlight).
  - **Trigger-at:** `changeAyah(String)`.
  - **Dependency Mapping:** None. Simple broadcast used by renderers to highlight a specific ayah.

- **LandscapeScrollEffect**: [lib/src/screen/quran_script_view/cubit/landscape_scroll_effect.dart](lib/src/screen/quran_script_view/cubit/landscape_scroll_effect.dart#L1)
  - **State:** `bool` (enabled/disabled)
  - **Trigger-at:** `changeState(bool)`
  - **Dependency Mapping:** None — small flag used by UI to control scroll behavior in landscape.

- **QuickAccessCubit**: [lib/src/screen/home/pages/quran/cubit/quick_access_cubit.dart](lib/src/screen/home/pages/quran/cubit/quick_access_cubit.dart#L1)
  - **State:** `List<QuickAccessModel>` persisted in `Hive` under `quick_access`.
  - **Trigger-at:** `addQuickAccess`, `removeQuickAccess`, `updateQuickAccess` (each updates Hive storage).
  - **Dependency Mapping:** `Hive` persistence.
  - **Cross-Cubit Interaction:** Used by home/Quran-page widgets to jump/scroll to saved locations; provides targets for scroll logic.

- **ThemeCubit**: [lib/src/theme/controller/theme_cubit.dart](lib/src/theme/controller/theme_cubit.dart#L1)
  - **State:** `ThemeState` containing `themeMode`, primary colors, shades.
  - **Trigger-at:** `setTheme(ThemeMode)`, `changePrimaryColor(Color)`, `refresh()`.
  - **Dependency Mapping:** `ThemeFunctions` util for persistence and color selection.
  - **Cross-Cubit Interaction:** Globally read by UI widgets for colors; no direct cubit-to-cubit listeners.

- **LanguageCubit**: [lib/src/resources/translation/language_cubit.dart](lib/src/resources/translation/language_cubit.dart#L1)
  - **State:** `MyAppLocalization` (selected locale metadata).
  - **Trigger-at:** `changeLanguage(MyAppLocalization)`, `getInitialLocale()` static helper.
  - **Dependency Mapping:** `SharedPreferences` for persistence.

- **WordPlayingStateCubit**: [lib/src/widget/quran_script_words/cubit/word_playing_state_cubit.dart](lib/src/widget/quran_script_words/cubit/word_playing_state_cubit.dart#L1)
  - **State:** `String?` (current playing word key or null).
  - **Trigger-at:** `changeState(String?)`.
  - **Dependency Mapping:** None; used by word-by-word UI and audio sync.

- **QuranHistoryCubit**: [lib/src/widget/history/cubit/quran_history_cubit.dart](lib/src/widget/history/cubit/quran_history_cubit.dart#L1)
  - **State:** `QuranHistoryState` contains `history: List<HistoryElement>` persisted via `Hive`.
  - **Trigger-at:** `addHistory({ayahKey, pageNumber})`.
  - **Dependency Mapping:** `Hive` for persistence.

- **ResourcesProgressCubit**: [lib/src/screen/setup/cubit/resources_progress_cubit_cubit.dart](lib/src/screen/setup/cubit/resources_progress_cubit_cubit.dart#L1)
  - **State:** `ResourcesProgressCubitState` with progress, processName, success/failure flags; used during initial resource download/setup.
  - **Trigger-at:** `updateProgress`, `success`, `failure`, `onProcess`, `changeTranslationBook`, `changeTafsirBook`.
  - **Dependency Mapping:** Uses models for translation/tafsir selections.

- **AudioDownloadCubit**: [lib/src/screen/audio/download_screen/cubit/audio_download_cubit.dart](lib/src/screen/audio/download_screen/cubit/audio_download_cubit.dart#L1)
  - **State:** `surahNumber`, `progress`, `isDownloading`.
  - **Trigger-at:** `updateDownloadingSurahNumber`, `updateProgress`, `updateIsDownloading`.
  - **Dependency Mapping:** Updated by download flows; UI observes this for download progress bars.

- **OthersSettingsCubit**: [lib/src/screen/settings/cubit/others_settings_cubit.dart](lib/src/screen/settings/cubit/others_settings_cubit.dart#L1)
  - **State:** `OthersSettingsState` fields: `rememberLastTab`, `tabIndex`, `wakeLock`.
  - **Trigger-at:** `setWakeLock(bool)`, `setRememberLastTab(bool)`, `setTabIndex(int)`.
  - **Dependency Mapping:** `Hive` and `WakelockPlus` for wake lock side effects.

- **LocationQiblaPrayerDataCubit**: [lib/src/screen/location_handler/cubit/location_data_qibla_data_cubit.dart](lib/src/screen/location_handler/cubit/location_data_qibla_data_cubit.dart#L1)
  - **State:** `LocationQiblaPrayerDataState` with `latLon`, `kaabaAngle`, `calculationMethod`, `madhab`, `isPrayerTimeDownloading`, etc.
  - **Trigger-at:** `getLocation()`, `alignWithDatabase()`, `saveLocationData(LatLon)`, `saveCalculationMethod(CalculationParameters)`, `saveMadhab(Madhab)`, `changePrayerTimeDownloading(bool)`.
  - **Dependency Mapping:** `Geolocator` (device location), `SharedPreferences` & `Hive` for persistence, uses `adhan_dart` types via compatibility layer (`calcParamsFromEnum`), and internal `calculateQiblaAngle` helper.
  - **Cross-Cubit Interaction:** Publishes location and prayer calculation parameters consumed by prayer-time UI and services.

- **PrayerReminderCubit**: [lib/src/screen/prayer_time/cubit/prayer_time_cubit.dart](lib/src/screen/prayer_time/cubit/prayer_time_cubit.dart#L1)
  - **State:** `PrayerReminderState` with `prayerToRemember` list, `previousReminderModes`, `reminderTimeAdjustment`, `enforceAlarmSound`, `soundVolume`.
  - **Trigger-at:** `addPrayerToRemember`, `removePrayerToRemember`, `setReminderMode`, `setReminderTimeAdjustment`, `setUIReminderTimeAdjustment`, `setReminderEnforceSound`, `setReminderSoundVolume`.
  - **Dependency Mapping:** Uses `adhan_dart` types (e.g., `Prayer` enum) for keys; persistence handled externally (not shown here).

- **AudioTabReciterCubit**: [lib/src/screen/audio/cubit/audio_tab_screen_cubit.dart](lib/src/screen/audio/cubit/audio_tab_screen_cubit.dart#L1)
  - **State:** `ReciterInfoModel` (last selected reciter) persisted in `Hive`.
  - **Trigger-at:** `changeReciter(ReciterInfoModel)` which saves selection.


**Key Observations for Audio–Text Sync (scroll & highlight)**
- There is no single monolithic "SyncCubits" file; sync is implemented by collaboration between:
  - `PlayerPositionCubit` (positions/durations from the audio player),
  - `SegmentedQuranReciterCubit` (segment maps if segmented recitations available),
  - `AyahKeyCubit` (current ayah key and saved ranges),
  - `QuranViewCubit` flags (`scrollWithRecitation`, `enableWordByWordHighlight`, `useAudioStream`),
  - `WordPlayingStateCubit` / `AyahToHighlight` for local word/ayah highlights.
- Persistence: many Cubits persist settings/state to `Hive` (local DB) or `SharedPreferences` (language, location, calculation method), reducing remote calls and enabling fast local reads.
- Cross-Cubit Communication: implemented implicitly through shared state reads in the UI (e.g., `context.read<AyahKeyCubit>().state.current`) rather than explicit Cubit subscriptions; this favors an event-driven UI that queries multiple Cubits in render/build callbacks.

**Next steps I can take (choose one):**
- Extract and generate a per-Cubit detailed file with source snippets and exact line references for each trigger (for audit/comparison).
- Produce a comparison matrix between this app's Cubit design and the Kurani Fisnik architecture you have (memory vs. DB, stream vs. polling, segmented vs. full-file audio sync).
- Create a UML-style dependency diagram (PNG/SVG) showing Cubit → Service relationships.

Të them tani cili nga hapat më sipër preferon të bëj? (Unë rekomandoj të nxjerrim dokumente individuale për 5-8 Cubit kryesorë si hapi i parë.)