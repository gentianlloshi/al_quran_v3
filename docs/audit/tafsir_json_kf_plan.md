# Analizë & Plan: Tefsir me JSON Lokal për Kurani Fisnik (KF)

Data: 10 Shkurt 2026

Kort summary: konkurrenti përdor `flutter_html` për render HTML, `Hive.lazyBox` për storage (çelësi = `ayahKey`), dhe `TafsirView` që e renderon tekstin brenda `SingleChildScrollView` në një `Scaffold` me `TabBar` për librat. Ai nuk ngarkon gjithë librin në RAM — përdor `LazyBox.get(ayahKey)`.

1) Rendering i Rich Text
- Konkurrenti: përdor `flutter_html` (shiko `import "package:flutter_html/flutter_html.dart"` dhe `Html(data: ...)` në `TafsirView`).
- Rekomandimi KF: përdorni `flutter_widget_from_html_core` ose `flutter_html` (të dyja janë të mira). `flutter_widget_from_html_core` ka më pak overhead dhe kontroll të mirë mbi rendering.

2) Logjika e Mapimit (ayahKey → entry)
- Konkurrenti mban keys në format `"S:V"` dhe i përdor si çelësa direkt në `Hive.lazyBox`.
- Në `TafsirView` ai thërret `getTafsirForBook(tafsirBook, ayahKey)` që bën `tafsirBox.get(ayahKey)`.
- Për KF: ruajni të njëjtin convention `"S:V"` dhe maponi një surah → skedar JSON që përmban entries për çdo `ayahKey` të asaj sure.

3) Menaxhimi i Memories
- Konkurrenti: `LazyBox` — vetëm `get(ayahKey)` ngarkon atë entry. Për shkarkim/parse ai përdor `compute()` për dekodim në isolate.
- KF plan: mos ngarkoni një JSON global në startup. Përdorni `per-surah` JSON dhe `compute()` për parse; cache-oni në memorie vetëm suren e fundit (LRU me limit 2–3 sures).

4) UI/UX Flow (long tafsir)
- Konkurrenti: `TafsirView` përdor `FutureBuilder` + `SingleChildScrollView` + `Html(data: ...)`. Për referenca thjesht navigon në një `TafsirView` të ri (push) kur `text` përmban `S:V` link.
- KF: do të përdorim të njëjtën qasje: full-screen `Scaffold` me `TabBar` (për libra) dhe `SingleChildScrollView` për përmbajtje të gjatë. Për auto-sync me QuranView, ofroj opsionin `scrollToTafsir(ayahKey)` që gjen pozicionin e elementit HTML (+ element id) dhe scroll-on me `ScrollController`.

5) Strategjia e Shpërndarjes (per assets)
- Rekomandim i fortë: NDAJNI sipas sures. Strukturë propozimi:

  assets/tafsir/<book_slug>/1.json
  assets/tafsir/<book_slug>/2.json
  ...

- Arsye: ngarkim i targetuar, sjell performancë më të mirë dhe shmang rritjen e madhësisë së APK me një JSON të vetëm gjigant.

6) `TafsirRepository` — skicë e thjeshtë
- Funksionalitetet kryesore:
  - `Future<void> preloadSurah(int surah)` — load string me `rootBundle.loadString` dhe `compute(parseJson)` dhe cache në Map.
  - `Future<String?> getTafsirText(String ayahKey)` — siguron që surah-i i përkatës të jetë në cache ose e ngarkon me `preloadSurah`, pastaj kthen entry["text"].
  - `void evictSurah(int surah)` — LRU eviction.

Skicë pseudo-Dart (very short):

```dart
class TafsirRepository {
  final _cache = <int, Map<String,dynamic>>{}; // surah -> parsed map

  Future<void> preloadSurah(int surah) async {
    if (_cache.containsKey(surah)) return;
    final raw = await rootBundle.loadString('assets/tafsir/$book/$surah.json');
    final Map parsed = await compute(jsonDecode, raw);
    _cache[surah] = Map<String,dynamic>.from(parsed);
    _enforceLru();
  }

  Future<String?> getTafsirText(String ayahKey) async {
    final parts = ayahKey.split(":");
    final surah = int.parse(parts[0]);
    await preloadSurah(surah);
    return _cache[surah]?[ayahKey]?['text'] as String?;
  }
}
```

7) Parser & Rendering — performance tips
- Use `compute()` to parse JSON into Map off the UI thread.
- For rendering, use `flutter_widget_from_html_core` with a custom `OnTap` handler for links `S:V`.
- For very long tafsir texts, prefer `SelectableRegion` + segmented rendering or virtualized rendering if needed (e.g., split content into paragraphs and render lazily).

8) Styling (Parchment theme + Amiri)
- Propozo `TextStyle`:
  - fontFamily: `Amiri` for Arabic spans
  - fontSize: 16 (user-scalable via settings)
  - color: `Color(0xFF2B2B2B)` on parchment background `Color(0xFFF7EFE2)`

- Me `flutter_widget_from_html_core`/`flutter_html` konfiguroni style map:

```dart
HtmlWidget(data,
  customStylesBuilder: (element) {
    if (element.localName == 'b') return {'font-weight':'700'};
    return null;
  },
  onTapUrl: (url) => handleLink(url),
);
```

Për të detektuar dhe renditur pjesët arabe me `Amiri`, përdorni `style` rules që target-ojnë Unicode block ose wrapper tags (p.sh. `<span class="arabic">...</span>`).

9) Dependencies rekomanduar
- `flutter_widget_from_html_core` (lightweight) ose `flutter_html` (më i kompletuar)
- `flutter_cache_manager` (opsional, për image assets)

10) Checklist implementimi
- [ ] Strukturoni assets si `assets/tafsir/<book_slug>/<surah>.json`.
- [ ] Implemento `TafsirRepository` me `compute()` parsing dhe LRU cache.
- [ ] Përdor `flutter_widget_from_html_core` për rendering dhe skeda style për Amiri.
- [ ] Implemento `scrollToTafsir(ayahKey)` për auto-sync me QuranView.

--
Konkluzion: Ndërsa konkurrenti përdor `Hive.lazyBox` + `flutter_html`, për KF me JSON lokal per-surah do të arrijmë më shumë kontroll, performancë dhe një pipeline të thjeshtë për update offline. Ndarja në 114 skedarë është rekomandimi kryesor.
