# Quran Reader Engine — Analysis

This document analyzes the Quran reading module implementation (widgets, rendering, fonts, performance, alignment).

Files inspected (key):
- `lib/src/screen/quran_script_view/quran_script_view.dart` (main reader screen)
- `lib/src/widget/quran_script/pages_render/pages_render.dart`
- `lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart`
- `lib/src/widget/quran_script/pages_render/tajweed_page_render/tajweed_page_renderer.dart`
- `lib/src/widget/ayah_by_ayah/ayah_by_ayah_card.dart`
- `lib/src/utils/quran_resources/quran_script_function.dart`

1) Which scrolling/list widget is used?
- The reader uses `ScrollablePositionedList.builder` (from `scrollable_positioned_list` package) for both:
  - Ayah-by-ayah mode (`itemCount = ayahsList.length`) — each item is an ayah card.
  - Reading (page) mode (`itemCount = pagesList.length`) — each item is a page (list of ayah keys).
- Navigation sidebars also use `ScrollablePositionedList.builder` for surah/page/ayah shortcuts.
- `PageView` is not used for the main reader; occasional `PageView` appears in unrelated UI (popups).

2) How is Arabic text rendered?
- Arabic text is rendered with Flutter `Text`/`Text.rich` and `TextSpan`s, not as images or canvas drawings.
- Word-level rendering: each ayah (or page) is split into words and assembled into nested `TextSpan` children. The word list comes from preloaded script data.
- Custom fonts are used (examples seen): `QPC_Hafs` and `AlQuranNeov5x1` in `NonTajweedPageRenderer` and `TajweedPageRenderer`.
- Tajweed rendering: there is a dedicated tajweed parser/renderer (`parseTajweedWord` / `tajweed_text_preser.dart`) which generates spans that include tajweed diacritics/colors while still using `Text` widgets.
- Word taps are supported with `TapGestureRecognizer` on `TextSpan` to show popups and word-by-word info.

3) Performance strategies for very long ayahs (e.g., Baqarah 282)
- Incremental/positioned list rendering:
  - Uses `ScrollablePositionedList.builder` so only visible items are built and kept, enabling efficient navigation and reduced widget tree size compared to building all pages/ayahs at once.
- Caching and local storage:
  - Quran script data (per-word arrays) is loaded from asset JSON into a Hive box during initialization (`QuranScriptFunction.writeQuranScript`) and then accessed via `QuranScriptFunction.getWordListOfAyah`.
  - A memory cache (`QuranScriptFunction.cacheOfAyah`) stores per-ayah word lists to avoid repeated Hive lookups/parsing.
- Translation prefetch & placeholders:
  - The code tries to use `getTranslationFromCache(ayahKey)` to immediately render translations when available; otherwise it uses a `FutureBuilder` and returns a placeholder `SizedBox` (e.g., fixed height) until the translation loads to avoid layout jank.
- Visibility-based updates:
  - `VisibilityDetector` detects visible pages/ayahs to update history and other state and helps avoid unnecessary work for off-screen items.
- Fine-grained rebuild control:
  - `BlocBuilder` `buildWhen` is used (e.g., in page renderers) to limit rebuilds only to the necessary situations (audio highlighting changes only when inside player and segments match current ayah).
- Word-level highlighting relies on `SegmentedResourcesManager` (segment timing maps). The renderer checks `PlayerPositionCubit` and compares currentDuration to segment boundaries; `buildWhen` logic prevents full rebuilds except when highlighting needs to change.
- Layout approach (text spans) reduces complexity vs. many separate Widgets per word — but building large `TextSpan` trees can still be costly; mitigations include caching and paging.

4) Text alignment and spacing between Arabic and translations
- Arabic text alignment:
  - `Text` uses `textAlign: TextAlign.right` and `textDirection: TextDirection.rtl` for Arabic lines.
  - Page/ayah renderers wrap Arabic content in `Text.rich` with RTL direction and the Arabic font.
- Translation layout:
  - Translations are rendered below the Arabic block (in ayah-by-ayah cards) and are `Align(alignment: Alignment.centerLeft)` so they appear left-to-right under the Arabic.
  - Visual separators (gaps, `pageLabelOfQuran` container, and `SurahInfoHeaderBuilder`) provide spacing and context.
  - The `baseTextStyle` and `QuranViewState.lineHeight` control vertical spacing (line height) for Arabic; translation font sizes are from `QuranViewState.translationFontSize`.
- Word-by-word alignment:
  - Word-by-word expansions use a `Wrap` with `textDirection: TextDirection.rtl` to arrange words and control spacing between them.

5) Additional notes and implications
- The implementation favors data-driven rendering: the Quran text is stored in compressed JSON, saved into Hive, and read as arrays of words — enabling quick lookups and consistent rendering across scripts.
- Scalability: `ScrollablePositionedList` + caching + lazy translation load makes very long surahs manageable. However, constructing very large `TextSpan` trees for pages that contain many ayahs/words could still be memory/time heavy; the app mitigates this by page-splitting and efficient caching.
- Interactivity & sync: The app integrates audio sync tightly via `PlayerPositionCubit`, `SegmentedQuranReciterCubit`, and `AyahKeyCubit` to provide highlighting + auto-scroll while limiting rebuilds.

References (source lines):
- Reader and list usage: `lib/src/screen/quran_script_view/quran_script_view.dart` (uses `ScrollablePositionedList.builder` for both modes)
- Page renderers: `lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart` and `tajweed_page_renderer.dart` (use `Text.rich` & `TextSpan` per word)
- Word source & caching: `lib/src/utils/quran_resources/quran_script_function.dart` (loads JSON assets into Hive, caches `cacheOfAyah`)
- Ayah-by-ayah card and translations: `lib/src/widget/ayah_by_ayah/ayah_by_ayah_card.dart`

---

If you want, next I can:
- Extract exact line snippets that show where fonts are declared and where caches are populated.
- Produce a short comparison table vs. Kurani Fisnik (memory vs DB, ScrollablePositionedList vs PageView, etc.).
- Create a small diagram showing data flow for audio -> segment lookup -> ayah highlight -> scroll.