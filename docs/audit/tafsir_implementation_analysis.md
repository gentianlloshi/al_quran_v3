# Analizë Teknike — Implementimi i Tefsirit (Exegesis)

Data: 10 Shkurt 2026

Ky dokument përmbledh gjetjet nga rikthimi i kodit (reverse engineering) për menaxhimin e Tefsirit në aplikacion.

## 1) Modeli i të Dhënave (Data Schema)
- Key/Index: Çdo entri i Tefsirit ruhet me një çelës unik që përfaqëson `ayahKey` (format: `"S:V"`, p.sh. `"2:255"`). Kjo është çelësi i përdorur në `Hive.lazyBox`.
- Struktura e një entry: vërehet se vlera e ruajtur për çdo `ayahKey` është një `Map<String, dynamic>` që përmban të paktën fushën `"text"` (string), e cila përdoret në UI. Gjithashtu shtohen metadatat e librit në `meta_data` brenda box-it.
- TafsirBookModel: metadata e librit (autor/gjuha/emri/totalAyahs/hasTafsir/score/full_path) ruhet si `TafsirBookModel` dhe serializohet si `Map` për ruajtje në `user` Hive box.
- Tekste të gjata: Tefsiri ruhet si string (mund të përmbajë HTML). Nuk ka ndarje fikse në paragrafë në storage; UI përdor `flutter_html` për t'u renderuar.

## 2) Logjika e Shkarkimit dhe Ruajtjes (Storage & Fetching)
- Metodë e shkarkimit: `QuranTafsirFunction.downloadResources` bën një GET në `ApisUrls.base + tafsirBook.fullPath`. Përmbajtja server-side duket të jetë një file i kompresuar (përmendet `decodeBZip2String`) që dekodohet dhe `jsonDecode`-ohet në një `Map`.
- Format i transferit: një JSON (sipas kodit) ku çelësat janë `ayahKey` dhe vlerat janë objektet e Tefsirit përkatëse.
- Ruajtja në disk: Pas dekodimit, secili çelës/objekt shkruhet në `Hive.lazyBox` me `tafsirBox.put(key, data[key])`. Gjithashtu ruhet `meta_data` me `tafsirBook.toMap()`.
- Hive.lazyBox: Përdorim i `LazyBox` siguron që të mos ngarkohet i gjithë libri në RAM; thirret `get(ayahKey)` për të marrë vetëm ajetin që nevojitet.

## 3) Si menaxhohet memoria (RAM)
- Për të ruajtur kujtesën të ulët, implementimi përdor `Hive.lazyBox`, pra entitetet lexohen on-demand. Kjo do të thotë se kur përdoruesi hap TafsirView për `ayahKey`, metoda `getTafsirForBook` e merr vetëm atë çelës nga box dhe e kthen.
- Përmbledhje: nuk ngarkohet i gjithë Tefsiri në memorie; vetëm item-et e kërkuara. Kjo e bën modelin të shkallëzueshëm për libra të mëdhenj.

## 4) Integrimi në UI (UX Flow)
- Hyrja: Përdoruesi hap Tefsirin nga butoni `Tafsir` që ndodhet në toolbar e kartelës `AyahByAyah` (shiko `getToolbarWidget` në `ayah_by_ayah_card.dart`).
- Prezentimi: Tefsiri shfaqet në një faqe të re `TafsirView` (full screen `Scaffold`) me `TabBar` që përfaqëson librat e shkarkuar/zgjedhur.
- Rrjedha: `TafsirView` përdor `FutureBuilder` që thërret `QuranTafsirFunction.getTafsirForBook(tafsirBook, ayahKey)` dhe më pas renderon `data["text"]` me `flutter_html`.
- Sinkronizimi ndër-ayete: Tafsiri nuk është një view live-synced me swipe të ajetit në pjesën kryesore të QuranScript — por `TafsirView` mund të navigojë te një ajet tjetër nëse `text` përmban referencë të formës `"S:V"` (atëherë tregohet buton për t'u zhvendosur te ai ayah). Për swipe të vazhdueshëm midis ajetesh, duhet të mbyllni dhe rihapni ose të përdorni funksionalitetin e navigimit që refrehs-on `TafsirView` me një `ayahKey` të ri.

## 5) Trajtimi i Referencave dhe Footnotes
- Structure: Përkthimet/footnotes ndahen në `translation` map për përkthime; për Tefsirin vetë `data["text"]` mund të përmbajë referenca si `"2:255"` që kod i interpreton si lidhje.
- Rendering: `TafsirView` përdor `flutter_html` për të renderuar `text` (HTML). Kjo mbështet tag-e bazë HTML dhe lidhje; kur `text` përmban vetëm një link me format `S:V` shfaqet buton për jump.

## 6) Përmbledhje e procesit (end-to-end)
1. Përdoruesi zgjedh një libër Tafsir për download (ose setup process bën download automatik).
2. Aplikacioni shkarkon një file (compressed JSON), dekodon dhe `compute()` për të parse-uar JSON në background isolate.
3. Pasi JSON dekodohet, secili cift `key:value` (dje `ayahKey` -> tafsirObject) shkruhet me `tafsirBox.put(key, value)` në `Hive.lazyBox`.
4. Për marrjen e një tafsiri, `getTafsirForBook` hap (nëse nuk është hapur) `LazyBox` dhe thërret `get(ayahKey)`.

## 7) Krahasim: "Downloadable JSON (si tek ata)" vs "Local JSON (KF)"

Risqet e vendosjes së Tefsirit të plotë në APK:
- APK size: Tefsiri i plotë (me dhjetëra MB teksti dhe media) do të rrisë madhësinë e APK/IPA, duke e bërë instalimin më të ngadaltë dhe duke i bërë përdoruesit të heqin dorë nga instalimi.
- Updateability: Nëse Tefsiri është në assets të APK, çdo përmirësim kërkon një release të ri.
- Memory: Nëse jo e dizajnuar mirë, një JSON i madh i bashkangjitur mund të ngarkohet aksidentalisht në memorie (p.sh. nga jsonDecode në startup).

Përparësitë e secilës qasje:
- Downloadable JSON (server-side, si implementimi i tyre):
  - + Lejon update të përmbajtjes pa release të app.
  - + Mund të kompresohet dhe të shkarkohet inkrementalisht.
  - - Kërkon rrjet gjatë instalimit/first-use.
- Local JSON (embeddim i KF në assets):
  - + Disponueshmëri offline nga instalimi.
  - - Rrit madhësinë e APK; vështirë për të përditësuar përmbajtje.

Rekomandimi praktik për KF (strukturë optimizuar):
1. Mos fusni gjithë Tefsirin si një JSON i vetëm në APK.
2. Përdorni strukturë të ndarë sipas sures: `assets/data/tafsir/<book_slug>/<surah>.json` kur dëshironi të vendosni disa libra të vogla në assets ose
3. Preferoni modelin e tyre: host në server si kompresuar (p.sh., `.bz2`) dhe shkarko/parse si `Map<ayahKey, tafsirObject>` por ruajeni në `Hive.lazyBox` — kjo kombinon përfitimet e updateability + eficiencë memorie.

### Struktura JSON e rekomanduar (per-surah) — shembull `2.json`:
```json
{
  "2:1": { "text": "<p>... tafsir ...</p>", "source":"Saadi", "lang":"en", "footnotes": {"1":"..."} },
  "2:2": { "text": "<p>...</p>" },
  ...
}
```

Alternativë efikase (server-side compressed + local Hive):
- Pse: Shkarkoni `book_bz2` nga serveri, dekodoni në isolate dhe `put` një entry në `LazyBox` për cdo ayah; ruani `meta_data` dhe shfaqni vetëm atë që kërkohet.

## 8) Concluding Recommendations
- Vazhdoni me modelin `LazyBox` (shumë i mirë) por dokumentoni formatin e `meta_data` dhe fushat e brendshme (p.sh., `text`, `author`, `lang`, `footnotes`, `source`, `updated_at`).
- Shtoni validim schema gjatë `downloadResources` (p.sh., verifikoni `totalEntries == tafsirBook.totalAyahs`).
- Për KF: përdorni per-surah JSON në assets për përmbajtje të vogël/paraqitje testuese; për librari të mëdha, përdorni server+compressed+Hive.lazyBox pattern.

---
Referenca (kod i kontrolluar):
- `lib/src/utils/quran_resources/quran_tafsir_function.dart`
- `lib/src/screen/tafsir_view/tafsir_view.dart`
- `lib/src/widget/ayah_by_ayah/ayah_by_ayah_card.dart`
