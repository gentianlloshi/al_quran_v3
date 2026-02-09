# AyahByAyahInScrollInfoCubit

Source: lib/src/screen/quran_script_view/cubit/ayah_by_ayah_in_scroll_info_cubit.dart

## State (AyahByAyahInScrollInfoState)
- `isAyahByAyah` (bool) — whether the viewer is in ayah-by-ayah scrolling mode
- `surahInfoModel` (SurahInfoModel) — metadata including ayah/page layout
- `expandedForWordByWord` (List<String>?) — which ayahs are expanded
- `pageByPageList` (List<int>?) — list used for page mapping
- `dropdownAyahKey` (dynamic) — used by UI dropdowns

## Triggers (methods)
- `setData({...})` — single method to update any of the fields; optionally clears `dropdownAyahKey`; persists `isAyahByAyah` to Hive.

## Dependencies
- `Hive` for `isAyahByAyah` persistence.
- `SurahInfoModel` for mapping between ayah keys and pages/offsets.

## Cross-Cubit Interaction
- Drives precise scrolling logic: renderers consume `pageByPageList`, `surahInfoModel` and `dropdownAyahKey` to compute exact scroll offsets for a requested ayah.
- Works alongside `AyahKeyCubit` and `SegmentedQuranReciterCubit` for sync scenarios.

## Scroll/Highlight role
- Provides the structural mapping required to translate an ayah key into a pixel/offset position in the scrollable view (essential for smooth, accurate auto-scrolling).