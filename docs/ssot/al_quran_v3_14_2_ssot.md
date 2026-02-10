# Al Quran v3.14.2 — SSOT Deep‑Dive (Single Source of Truth)

**Data:** 2026‑02‑10  
**Qëllimi:** Dokumentim i plotë teknik për arkitekturën, rendering‑un, menaxhimin e të dhënave, audio/sync, dhe QA edge‑cases.

---

## A) Arkitektura e Sistemit (High‑Level Design)

### A.1 State Management (Cubit Hierarchy)

| Cubit | Përgjegjësia | Dëgjon / Varet nga | Përdoret nga (UI/Logic) | Burim referencash |
|---|---|---|---|---|
| `AyahKeyCubit` | Menaxhon `start/end/current` ayahKey, listën e ajeteve, persistencë | Hive `user` box | `AudioPlayerManager` (update `current`), `AudioControllerUi`, `QuranScriptView` | [lib/src/core/audio/cubit/ayah_key_cubit.dart](lib/src/core/audio/cubit/ayah_key_cubit.dart) |
| `PlayerPositionCubit` | Pozicioni/audio duration | `AudioPlayerManager.positionStream` | `AudioControllerUi`, `NonTajweedPageRenderer` | [lib/src/core/audio/cubit/player_position_cubit.dart](lib/src/core/audio/cubit/player_position_cubit.dart), [lib/src/core/audio/player/audio_player_manager.dart](lib/src/core/audio/player/audio_player_manager.dart) |
| `PlayerStateCubit` | playing/processing state | `AudioPlayerManager.playerEventStream` | `AudioControllerUi` | [lib/src/core/audio/cubit/player_state_cubit.dart](lib/src/core/audio/cubit/player_state_cubit.dart) |
| `AudioUiCubit` | UI state i player‑it (expand/show) | — | `AudioControllerUi`, `NonTajweedPageRenderer` (gate për highlight) | [lib/src/core/audio/cubit/audio_ui_cubit.dart](lib/src/core/audio/cubit/audio_ui_cubit.dart) |
| `SegmentedQuranReciterCubit` | Reciter i segmentuar + download i segmenteve | `SegmentedResourcesManager` (Hive + Dio) | `NonTajweedPageRenderer`, audio/recitation UI | [lib/src/core/audio/cubit/segmented_quran_reciter_cubit.dart](lib/src/core/audio/cubit/segmented_quran_reciter_cubit.dart) |
| `AyahByAyahInScrollInfoCubit` | State i mënyrës së skrollimit (Ayah‑by‑Ayah vs Reading) + dropdown | Hive `user` | `QuranScriptView` | [lib/src/screen/quran_script_view/cubit/ayah_by_ayah_in_scroll_info_cubit.dart](lib/src/screen/quran_script_view/cubit/ayah_by_ayah_in_scroll_info_cubit.dart) |
| `QuranViewCubit` | Preferencat e view (font, line height, script type, hide flags) | Hive `user` | `QuranScriptView`, renderers | [lib/src/screen/settings/cubit/quran_script_view_cubit.dart](lib/src/screen/settings/cubit/quran_script_view_cubit.dart) |

#### Observim
- **Nuk ka një “Dependency Graph” të centralizuar**; varësitë janë implicit në UI përmes `context.read<...>()`.
- **Persistenca e preferencave** është e përqendruar në Hive `user` box (pa repository abstractions).

### A.2 Layer Separation (DataSources / Repositories / Logic)

| Shtresa | Vendndodhja | Përshkrim | Status |
|---|---|---|---|
| DataSources (Network) | `lib/src/utils/quran_resources/*` + `Dio` | Shkarkim i burimeve (tafsir, translation, word‑by‑word, segments) | **Në vend** (por static utils) |
| Persistence | Hive `user`, LazyBox për content | Cache lokale dhe preferenca | **Në vend** |
| Logic/State | `Cubit` në `lib/src/**/cubit` | State management & view settings | **Në vend** |
| UI | `lib/src/screen`, `lib/src/widget` | Widgets + Renderers | **Në vend** |
| Repository Layer | — | Abstraksion i munguar | **Mungon** (technical debt) |

### A.3 Diagram ASCII — Rrjedha Audio → Highlight Word

```
[just_audio AudioPlayer]
         |
         | positionStream
         v
[AudioPlayerManager] --emit--> [PlayerPositionCubit]
         |                         |
         | currentIndexStream      | (state update)
         v                         v
 [AyahKeyCubit]           [NonTajweedPageRenderer]
         |                         |
         | current ayah            | buildWhen(): krahaso ms
         v                         v
   [Ayah Highlight]     [Word Highlight TextSpan]
```

Burime:
- [lib/src/core/audio/player/audio_player_manager.dart](lib/src/core/audio/player/audio_player_manager.dart)
- [lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart](lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart)

---

## B) Motori i Rendering‑ut & UI (Deep‑Dive)

### B.1 Verse Rendering — `uthmani_page_renderer.dart`

**Struktura e `TextSpan`**
- `Text.rich(TextSpan(children: ...))`
- Për çdo `ayahKey`:
  - Krijo `TextSpan` wrapper për ajetin (për background highlight të ajetit aktual)
  - `children` = `List<TextSpan>` per çdo fjalë në ajet
  - Për çdo fjalë:
    - `TextSpan(text: "$word ")`
    - `TapGestureRecognizer` → hap popup me Word‑by‑Word
    - Highlight aktivizohet nëse `currentDuration` bie në segmentin `[startMs, endMs]`

Burim: [lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart](lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart)

**Snippet kritik (highlight word‑by‑word)**
```dart
if (Duration(milliseconds: word[1]) < (current.currentDuration ?? Duration.zero) &&
    Duration(milliseconds: word[2]) > (current.currentDuration ?? Duration.zero)) {
  highlightingWord = "$currentAyahKey:${word[0]}";
}
```

### B.2 Matrica e Performancës (estimim teorik)

| Faktor | Kompleksitet | Implikim | Risk |
|---|---|---|---|
| Numri i fjalëve në faqe | $O(W)$ TextSpan | 1 TextSpan / fjalë | Medium |
| Ajet me >100 fjalë | $O(100)$ | 100 spans + recognizers | High (frame cost) |
| Word‑by‑word highlight | $O(S)$ ku S = segmente në ajet | Kërkon kontroll për çdo word segment | Medium |
| `Text.rich` me shumë spans | $O(W)$ | Layout më i rëndë | Medium‑High |

> **Shënim:** Këto janë **estimime** strukturore, jo matje runtime.

### B.3 Responsive Logic & Breakpoints

| Komponent | Threshold | Sjellje |
|---|---|---|
| `QuranScriptView` | `width > 600` | aktivizon layout të dyfishtë (sidebar + main) | [lib/src/screen/quran_script_view/quran_script_view.dart](lib/src/screen/quran_script_view/quran_script_view.dart) |
| `AudioControllerUi` | `width > 600` | ndryshon layout të player‑it (row vs column) | [lib/src/widget/audio/audio_controller_ui.dart](lib/src/widget/audio/audio_controller_ui.dart) |
| `SetupPage` | `width > 600` | layout adaptiv për setup | [lib/src/screen/setup/setup_page.dart](lib/src/screen/setup/setup_page.dart) |

**Observim:** Nuk shfaqet `800dp` breakpoint; kryesor është 600dp.

---

## C) Menaxhimi i të Dhënave (Data Persistence)

### C.1 Hive Schema & Boxes

| Box | Tip | Përmbajtje | Vendndodhje |
|---|---|---|---|
| `user` | Box | preferenca, selections, last ayah state | **core** |
| `translation_*` | LazyBox | përkthime per ayahKey | `QuranTranslationFunction` |
| `tafsir_*` | LazyBox | tafsir per ayahKey | `QuranTafsirFunction` |
| `surah_info_{lang}` | LazyBox | info për sure në gjuhë | `QuranTranslationFunction` |
| `wbw_*` | LazyBox | word‑by‑word për ayahKey | `WordByWordFunction` |
| `segmented_recitation_*` | Box | segmente audio (word timing) | `SegmentedResourcesManager` |

Referenca:
- [lib/src/utils/quran_resources/quran_translation_function.dart](lib/src/utils/quran_resources/quran_translation_function.dart)
- [lib/src/utils/quran_resources/quran_tafsir_function.dart](lib/src/utils/quran_resources/quran_tafsir_function.dart)
- [lib/src/utils/quran_resources/word_by_word_function.dart](lib/src/utils/quran_resources/word_by_word_function.dart)
- [lib/src/utils/quran_resources/segmented_resources_manager.dart](lib/src/utils/quran_resources/segmented_resources_manager.dart)

### C.2 Lazy Loading Strategy
- Përkthimet dhe tafsiri ruhen në **LazyBox**, kështu `get(ayahKey)` është on‑demand.
- `init()` hap vetëm box‑et e zgjedhura nga përdoruesi.
- **Cache lokale** për segments (`segmentsCache`) për të shmangur lookup të përsëritur.

### C.3 Asset Lifecycle (bz2 → Runtime Map)

1. Shkarkim JSON i kompresuar nga serveri (string bazë64)
2. `decodeBZip2String` → `jsonDecode` (në isolate me `compute`)
3. Shpërndarje në LazyBox (key → entry)

Burim:
- [lib/src/utils/encode_decode.dart](lib/src/utils/encode_decode.dart)
- [lib/src/utils/quran_resources/quran_translation_function.dart](lib/src/utils/quran_resources/quran_translation_function.dart)
- [lib/src/utils/quran_resources/quran_tafsir_function.dart](lib/src/utils/quran_resources/quran_tafsir_function.dart)
- [lib/src/utils/quran_resources/segmented_resources_manager.dart](lib/src/utils/quran_resources/segmented_resources_manager.dart)

---

## D) Audio & Sync Engine (Technical Core)

### D.1 Formula e Sync‑ut të Word Highlight

Segmentet janë në format:
```
[wordIndex, startMs, endMs]
```
Për çdo frame:
```
highlight = (startMs < currentMs < endMs)
```
Kur kushti plotësohet, `highlightingWord = "$ayahKey:$wordIndex"`.

Referencë: [lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart](lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart)

### D.2 Latency Analysis (vlerësim)

| Burim latency | Vlerësim | Shënim |
|---|---|---|
| `AudioPlayer.positionStream` | ~100‑250ms (varësisht just_audio) | Nuk ka throttle custom në kod |
| Build/render i widget | ~1 frame | I varur nga numri i spans |
| Total (vlerësim) | ~1–3 frame + stream tick | **Jo i matur** në runtime |

### D.3 Audio Focus / Interruptions (Mungesa)

**Nuk u gjetën handler‑a** për:
- `AudioSession` (audio focus)
- `becomingNoisy` (headphones unplug)
- Evente `phone call` / interruptions

Burim: mungesë në [lib/src/core/audio/player/audio_player_manager.dart](lib/src/core/audio/player/audio_player_manager.dart)

---

## E) Use Cases & Edge Cases (QA Matrix)

| Skenari | Reagimi i kodit (bazuar në analizë) | Risk |
|---|---|---|
| Ndryshimi i fontit gjatë dëgjimit | `QuranViewCubit` ruan në Hive dhe renderers ndërtohen me `fontSize` të ri | Medium (rebuild gjatë audio) |
| Offline playback me missing segments | `SegmentedResourcesManager.getAyahSegments` mund të kthejë `null`, highlight fjalësh nuk shfaqet | Low‑Medium |
| Telefonatë hyrëse | Nuk ka audio focus handlers; playback mund të vazhdojë ose ndërpritet nga OS | High |
| Ndërrim reciter gjatë playback | `SegmentedQuranReciterCubit` shkarkon dhe rihap box‑et | Medium |
| Skroll i shpejtë | `ScrollablePositionedList` me `scrollTo` | Medium |

---

## Tabela Krahasuese — `Navigator.push` vs `pushReplacement`

| Metodë | Përshkrim | Përdorim i gjetur | Efekt |
|---|---|---|---|
| `Navigator.push` | Shton screen në stack | `JumpToAyahView` → `QuranScriptView` | Kthen mbrapa në modal/dialog |
| `Navigator.pushReplacement` | Zëvendëson screen | sidebar e `QuranScriptView` | Stack më i pastër |

Referencë: [lib/src/widget/jump_to_ayah/jump_to_ayah.dart](lib/src/widget/jump_to_ayah/jump_to_ayah.dart), [lib/src/screen/quran_script_view/quran_script_view.dart](lib/src/screen/quran_script_view/quran_script_view.dart)

---

## Snippet i rëndësishëm (Alignment 0.15)

```dart
itemScrollControllerAyahByAyah.scrollTo(
  index: ayahsList.indexOf(key),
  alignment: 0.15,
  duration: const Duration(milliseconds: 200),
);
```
Referencë: [lib/src/screen/quran_script_view/quran_script_view.dart](lib/src/screen/quran_script_view/quran_script_view.dart)

---

## Technical Debt (Warnings)

1. **Mungesë e Repository Layer** → logjika dhe data access janë të shpërndara në `utils/*`.
2. **Static utils + global state** → e vështirë për testim unit.
3. **TextSpan heavy rendering** → në ajetet shumë të gjata ka risk për frame drops.
4. **Audio focus handling** mungon → risk për UX në calls/headphones.
5. **Persistencë direkte në Hive nga Cubits** → coupling i lartë.

---

## Konkluzioni i Ekspertit

**Vlerësim i shkallëzueshmërisë:** Mesatar (6/10).
- **Pozitive:** segmentim i qartë i audio/tafsir/translation resources me LazyBox, mirë për storage.
- **Negativ:** mungesë e repository layer dhe audio focus handlers; UI render mund të bëhet i rëndë me shumë `TextSpan`.

**Rekomandim:** Për shkallëzim afatgjatë, shtoni:
- Repository abstractions + caching layer të unifikuar
- AudioSession handlers
- Profilim i render‑it për faqet me shumë spans

---

# SSOT Granular (Deep Code Audit)

Ky seksion zgjeron SSOT‑në me auditim granular të kodit, me fokus te Cubit‑et, modelet, renderers, dhe pipelines e burimeve.

## 1) Dekonstruksioni i Cubit‑eve (Metodë për Metodë)

### 1.1 `AyahKeyCubit`

**State (`AyahKeyManagement`)**

| Field | Tipi | Vlera fillestare | Kuptimi |
|---|---|---|---|
| `start` | `String` | Hive `user.last_ayah_start` (default `1:1`) | AyahKey i nisjes së range‑it |
| `end` | `String` | Hive `user.last_ayah_end` (default `1:7`) | AyahKey i fundit |
| `ayahList` | `List<String>` | Hive `user.last_ayah_ayah_list` | Lista e ajeteve për playback |
| `current` | `String` | Hive `user.last_ayah_current` (default `1:1`) | AyahKey i tanishëm |
| `lastScrolledPageNumber` | `int?` | `null` | Përdoret për historik/scroll |

**Metodat**
| Metoda | Ndryshon | Side‑effects |
|---|---|---|
| `changeCurrentAyahKey(ayahKey)` | `current` | Shkruan në Hive `user.last_ayah_current` |
| `changeData(ayahData)` | `start/end/ayahList/current` | Thërret `saveAyahKeyChanges()` (persistencë) |
| `saveAyahKeyChanges(ayahData)` | — | Shkruan në Hive 4 çelësa (`last_ayah_*`) |
| `changeLastScrolledPage(page)` | `lastScrolledPageNumber` | Nuk persiston në Hive |

Referencë: [lib/src/core/audio/cubit/ayah_key_cubit.dart](lib/src/core/audio/cubit/ayah_key_cubit.dart)

### 1.2 `PlayerPositionCubit`

**State (`AudioPlayerPositionModel`)**

| Field | Tipi | Vlera fillestare | Kuptimi |
|---|---|---|---|
| `currentDuration` | `Duration?` | `null` | Pozicioni aktual i player‑it |
| `totalDuration` | `Duration?` | `null` | Gjatësia totale |
| `bufferDuration` | `Duration?` | `null` | Pozicioni i buffer‑it |

**Metodat**
| Metoda | Ndryshon | Side‑effects |
|---|---|---|
| `changeCurrentPosition(position)` | `currentDuration` | — |
| `changeBufferPosition(position)` | `bufferDuration` | — |
| `changeTotalDuration(duration)` | `totalDuration` | — |
| `changeData(audioPositionData)` | gjithë state | — |

Referencë: [lib/src/core/audio/cubit/player_position_cubit.dart](lib/src/core/audio/cubit/player_position_cubit.dart)

### 1.3 `PlayerStateCubit`

**State (`PlayerState`)**

| Field | Tipi | Vlera fillestare | Kuptimi |
|---|---|---|---|
| `state` | `ProcessingState?` | `null` | Gjendja e just_audio |
| `isPlaying` | `bool` | `false` | Playing flag |

**Metodat**
| Metoda | Ndryshon | Side‑effects |
|---|---|---|
| `changeState(processingState, isPlaying)` | `state`, `isPlaying` | — |

Referencë: [lib/src/core/audio/cubit/player_state_cubit.dart](lib/src/core/audio/cubit/player_state_cubit.dart)

### 1.4 `AudioUiCubit`

**State (`AudioControllerUiState`)**

| Field | Tipi | Vlera fillestare | Kuptimi |
|---|---|---|---|
| `isExpanded` | `bool` | `false` | UI panel i zgjeruar |
| `showUi` | `bool` | `false` | A shfaqet player UI |
| `isPlayList` | `bool` | `false` | Mode playlist |
| `isInsideQuranPlayer` | `bool` | `false` | Për highlight gating |

**Metodat**
| Metoda | Ndryshon | Side‑effects |
|---|---|---|
| `expand(toChange)` | `isExpanded` | — |
| `showUI(toChange)` | `showUi` | — |
| `isPlayList(toChange)` | `isPlayList` | — |
| `changeIsInsideQuran(toChange)` | `isInsideQuranPlayer` | — |

Referencë: [lib/src/core/audio/cubit/audio_ui_cubit.dart](lib/src/core/audio/cubit/audio_ui_cubit.dart)

### 1.5 `SegmentedQuranReciterCubit`

**State (`ReciterInfoModel`)**

| Field | Tipi | Vlera fillestare | Kuptimi |
|---|---|---|---|
| `link` | `String` | nga `getOpenSegmentsReciter()` ose `getSegmentsSupportedReciters().first` | Link i reciter |
| `name` | `String` | — | Emri i reciter‑it |
| `segmentsUrl` | `String?` | — | URL për segments (wbw) |
| `isDownloading` | `bool` | `false` | download state |
| `showAyahHighlight` | `String?` | `null` | përdoret për UI highlight |

**Metodat**
| Metoda | Ndryshon | Side‑effects |
|---|---|---|
| `changeReciter(context, reciter)` | `isDownloading`, state | Shkarkon segments dhe hap Hive box |
| `getAyahSegments(ayahKey)` | — | Lexon nga `SegmentedResourcesManager` |
| `temporaryHilightAyah(ayah)` | `showAyahHighlight` | — |
| `refresh()` | state | — |

Referencë: [lib/src/core/audio/cubit/segmented_quran_reciter_cubit.dart](lib/src/core/audio/cubit/segmented_quran_reciter_cubit.dart)

### 1.6 `AyahByAyahInScrollInfoCubit`

**State (`AyahByAyahInScrollInfoState`)**

| Field | Tipi | Vlera fillestare | Kuptimi |
|---|---|---|---|
| `isAyahByAyah` | `bool` | Hive `user.isAyahByAyah` (default `true`) | Mode listë ajete vs reading |
| `surahInfoModel` | `SurahInfoModel?` | `null` | Sure aktuale |
| `dropdownAyahKey` | `dynamic` | `null` | përdoret për sidebar selection |
| `pageByPageList` | `List<int>?` | `null` | caching i faqeve |

**Metodat**
| Metoda | Ndryshon | Side‑effects |
|---|---|---|
| `setData(...)` | state sipas input | Persiston `isAyahByAyah` në Hive |

Referencë: [lib/src/screen/quran_script_view/cubit/ayah_by_ayah_in_scroll_info_cubit.dart](lib/src/screen/quran_script_view/cubit/ayah_by_ayah_in_scroll_info_cubit.dart)

### 1.7 `QuranViewCubit`

**State (`QuranViewState`)** — vlera fillestare dalin nga Hive `user` (font, line height, flags).

**Metodat**
| Metoda | Ndryshon | Side‑effects |
|---|---|---|
| `changeAyah(ayah)` | `ayahKey` | Shkruan `preview_quran_script_ayah` |
| `changeFontSize(fontSize)` | `fontSize` | Shkruan `preview_quran_script_font_size` |
| `changeLineHeight(lineHeight)` | `lineHeight` | Shkruan `quran_script_heigh_of_line` |
| `changeQuranScriptType(type)` | `quranScriptType` | Shkruan `selected_quran_script_type` |
| `changeTranslationFontSize(fontSize)` | `translationFontSize` | Shkruan `preview_translation_font_size` |
| `setViewOptions(...)` | flags + `playbackSpeed` | Shkruan në Hive shumë çelësa (hide* / playback) |

Referencë: [lib/src/screen/settings/cubit/quran_script_view_cubit.dart](lib/src/screen/settings/cubit/quran_script_view_cubit.dart)

---

## 2) Modelet e të Dhënave & Schema (Deep‑Dive)

### 2.1 Hive Adapters

**U gjetën 0 `@HiveType/@HiveField` në kod**. Modelet ruhen si Map/JSON direkt në Hive (LazyBox), jo si typed adapters.

### 2.2 Model Tables

#### `ReciterInfoModel`

| Field | Tipi | Burimi | Përshkrim |
|---|---|---|---|
| `link` | `String` | JSON | URL base i reciter |
| `name` | `String` | JSON | Emri i reciter |
| `supportWordSegmentation` | `bool?` | JSON | A ka wbw segments |
| `source` | `String?` | JSON | Burimi i reciter |
| `style` | `String?` | JSON | Stili (p.sh. murattal) |
| `img` | `String?` | JSON | Foto |
| `bio` | `String?` | JSON | Bio |
| `segmentsUrl` | `String?` | JSON key `segments_url` | URL për segments |
| `isDownloading` | `bool` | runtime | Progress flag |
| `showAyahHighlight` | `String?` | runtime | Highlight i përkohshëm |

Referencë: [lib/src/core/audio/model/recitation_info_model.dart](lib/src/core/audio/model/recitation_info_model.dart)

#### `SegmentsInfoModel`

| Field | Tipi | Përshkrim |
|---|---|---|
| `surahNumber` | `int?` | Sure |
| `ayahNumber` | `int?` | Ajeti |
| `audioUrl` | `String?` | URL i audio segmentit |
| `duration` | `int?` | ms |
| `segments` | `List<List<int>>?` | `[wordIndex, startMs, endMs]` |

Referencë: [lib/src/core/audio/model/segments_info_model.dart](lib/src/core/audio/model/segments_info_model.dart)

#### `SurahInfoModel` + `metaDataSurah`

| Field (JSON key) | Tipi | Kuptimi |
|---|---|---|
| `id` | `int` | numri i sures |
| `ro` | `int` | revelation order |
| `rp` | `String` | revelation place (`makkah`/`madinah`) |
| `vc` | `int` | verses count |
| `pr` | `String` | pages range (p.sh. `1-1`) |
| `noBismillah` | `bool` | mungesa e Bismillah |

Shembull nga `metaDataSurah`:

```dart
"1": {"id": 1, "ro": 5, "rp": "makkah", "vc": 7, "pr": "1-1", "noBismillah": true}
"2": {"id": 2, "ro": 87, "rp": "madinah", "vc": 286, "pr": "2-49"}
"9": {"id": 9, "ro": 113, "rp": "madinah", "vc": 129, "pr": "187-207", "noBismillah": true}
```

Referencë: [lib/src/resources/quran_resources/meta/meta_data_surah.dart](lib/src/resources/quran_resources/meta/meta_data_surah.dart)

#### `AyahKeyManagement`

| Field | Tipi | Kuptimi |
|---|---|---|
| `start` | `String` | Start ayahKey |
| `end` | `String` | End ayahKey |
| `current` | `String` | AyahKey aktual |
| `ayahList` | `List<String>` | Listë e ajeteve |
| `lastScrolledPageNumber` | `int?` | Numri i faqes së fundit |

Referencë: [lib/src/core/audio/model/ayahkey_management.dart](lib/src/core/audio/model/ayahkey_management.dart)

---

## 3) Logjika e Renderimit (Rendering Pipeline)

### 3.1 `NonTajweedPageRenderer` (Uthmani/Indopak)

**TextSpan Tree**
```
Text.rich(
  TextSpan(
    children: [
      TextSpan( // ayah wrapper
        children: [TextSpan(word1), TextSpan(word2), ...]
      ),
      ...
    ]
  )
)
```

**Fjalë‑për‑fjalë (gesture + highlight)**
- `TapGestureRecognizer` i bashkangjitet çdo `TextSpan` fjale.
- Hapi popup për Word‑by‑Word me `wordKeys` dhe `initWordIndex`.

Snippet (≈ 24 rreshta):
```dart
return TextSpan(
  style: TextStyle(
    backgroundColor:
        highlightingAyahKey == ayahKey
            ? isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08)
            : null,
  ),
  children: List.generate(words.length, (index) {
    String word = words[index];
    return TextSpan(
      text: "$word ",
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          final highlightingWord = List.generate(
            words.length,
            (index) => "$ayahKey:${index + 1}",
          );
          showPopupWordFunction(
            context: context,
            initWordIndex: index,
            wordKeys: highlightingWord,
            wordByWordList: await WordByWordFunction.getAyahWordByWordData(
                  "${highlightingWord.first.split(":")[0]}:${highlightingWord.first.split(":")[1]}",
                ) ??
                [],
          );
        },
    );
  }).toList(),
);
```

Referencë: [lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart](lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart)

### 3.2 `TajweedPageRenderer` + `parseTajweedWord`

**Tajweed pipeline**
- `parseTajweedWord` analizon HTML tags (`<rule class="...">`) dhe mapon ngjyrat sipas rregullave.
- `TapGestureRecognizer` vendoset në nivel TextSpan për çdo node tekst.

Snippet (≈ 26 rreshta):
```dart
TextSpan parseTajweedWord({
  required TextStyle baseStyle,
  required BuildContext context,
  required List<String> words,
  required int surahNumber,
  required int ayahNumber,
  required bool skipWordTap,
  required wordIndex,
}) {
  List<TextSpan> spans = [];
  final brightness = Theme.of(context).brightness;
  final bool isLight = brightness == Brightness.light;
  final TextStyle processingStyle = baseStyle.copyWith(color: defaultColor);

  void processNode(dom.Node node, Color currentColor) {
    if (node.nodeType == dom.Node.TEXT_NODE) {
      spans.add(TextSpan(
        text: node.text,
        style: processingStyle.copyWith(color: currentColor),
        recognizer: skipWordTap == true ? null : (TapGestureRecognizer()
          ..onTap = () async {
            List<String> wordsKey = List.generate(
              words.length,
              (index) => "$surahNumber:$ayahNumber:${index + 1}",
            );
            showPopupWordFunction(
              context: context,
              wordKeys: wordsKey,
              initWordIndex: wordIndex,
              wordByWordList: await WordByWordFunction.getAyahWordByWordData(
                    "${wordsKey.first.split(":")[0]}:${wordsKey.first.split(":")[1]}",
                  ) ??
                  [],
            );
          }),
      ));
    }
  }
  return TextSpan(children: spans, style: processingStyle);
}
```

Referencë: [lib/src/widget/quran_script/script_view/tajweed_view/tajweed_text_preser.dart](lib/src/widget/quran_script/script_view/tajweed_view/tajweed_text_preser.dart)

---

## 4) Matematika e Skrollit & Sinkronizimit

### 4.1 `getListOfAyahKeyExperimental`

**Algoritmi**
1. Parse `startAyahKey`, `endAyahKey` → `startSurah`, `startAyah`, `endSurah`, `endAyah`
2. Për çdo sure nga `startSurah` → `endSurah`:
   - `startAyah` është 1 (përveç sures së parë)
   - `endAyah` nga `quranAyahCount[surah - 1]` (përveç sures së fundit)
3. Shto `"surah:ayah"` në listë (rend linear)

Snippet (≈ 22 rreshta):
```dart
List<String> getListOfAyahKeyExperimental({
  required String startAyahKey,
  required String endAyahKey,
}) {
  List<String> ayahKeysList = [];
  int startSurahNumber = int.parse(startAyahKey.split(":")[0]);
  int startAyahNumber = int.parse(startAyahKey.split(":")[1]);
  int endSurahNumber = int.parse(endAyahKey.split(":")[0]);
  int endAyahNumber = int.parse(endAyahKey.split(":")[1]);

  for (int surah = startSurahNumber; surah <= endSurahNumber; surah++) {
    int startAyah = 1;
    if (surah == startSurahNumber) startAyah = startAyahNumber;
    int endAyah = quranAyahCount[surah - 1];
    if (surah == endSurahNumber) {
      endAyah = endAyahNumber;
    }
    for (int ayah = startAyah; ayah <= endAyah; ayah++) {
      ayahKeysList.add("$surah:$ayah");
    }
  }
  return ayahKeysList;
}
```

Referencë: [lib/src/utils/quran_ayahs_function/gen_ayahs_key.dart](lib/src/utils/quran_ayahs_function/gen_ayahs_key.dart)

### 4.2 Alignment Math

- `scrollTo` përdor `alignment: 0.15` për të vendosur ajetin pak poshtë top.
- Nuk ka degëzim për ajetet e gjata; vlera është konstante.

Referencë: [lib/src/screen/quran_script_view/quran_script_view.dart](lib/src/screen/quran_script_view/quran_script_view.dart)

### 4.3 Word Sync Algorithm

Kontrolli ekzekutohet në çdo emission të `positionStream` (just_audio). Frekuenca reale varet nga internals e just_audio dhe platforma (zakonisht 200–500ms).

Pseudo‑formula:
$$\text{highlight} = (t_{start} < t_{current} < t_{end})$$

Referencë: [lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart](lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart)

---

## 5) Analiza e Burimeve (Resources Management)

### 5.1 Shkarkimi me Dio

- **Tafsir/Translation/WbW:** `Dio().get` + `onReceiveProgress` + `compute` → decode
- **Audio:** `Dio().download` me `receiveTimeout` & `sendTimeout` 60s (vetëm audio)

Referencë:
- [lib/src/utils/quran_resources/quran_translation_function.dart](lib/src/utils/quran_resources/quran_translation_function.dart)
- [lib/src/utils/quran_resources/quran_tafsir_function.dart](lib/src/utils/quran_resources/quran_tafsir_function.dart)
- [lib/src/utils/quran_resources/word_by_word_function.dart](lib/src/utils/quran_resources/word_by_word_function.dart)
- [lib/src/core/audio/player/audio_player_manager.dart](lib/src/core/audio/player/audio_player_manager.dart)

### 5.2 Extraction Logic (bz2)

Pipeline:
```
Remote URL → Dio.get → base64 (bz2) → decodeBZip2String → jsonDecode → Hive LazyBox
```

Referencë: [lib/src/utils/encode_decode.dart](lib/src/utils/encode_decode.dart)

---

## 6) Borxhi Teknik & Rekomandime (Granular)

| Problem | Vendndodhje | Risk | Rekomandim |
|---|---|---|---|
| Static utils pa repository | `lib/src/utils/quran_resources/*` | Coupling i lartë | Shto repository layer |
| Hardcoded values (p.sh. 600dp, 0.15 alignment) | UI files | UX në tablet | Parametrizim me config |
| Mungesë `AudioSession` handlers | audio player | UX risk | Shto audio_session |
| Mungesë unit tests | sinkronizim audio/scroll | bug risk | shto test suite |

---

## ASCII Diagram — Class Links (Granular)

```
AyahKeyCubit ──> QuranScriptView ──> ScrollablePositionedList
       |                         \
       |                          \-> NonTajweedPageRenderer
       v
AudioPlayerManager ──> PlayerPositionCubit ──> Word Highlight
```
