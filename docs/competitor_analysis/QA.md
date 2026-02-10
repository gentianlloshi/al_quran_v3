**QA — Analizë e katër prompteve**

**Prompt 1 — Performanca në ajetet e gjata**
- Renderer-i kryesor: `lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart` krijon një `Text.rich` me shumë `TextSpan`-e, duke mapuar `ayahsKey` → fjalë për fjalë.
- Caching: fjalët e ayah-it ruhen në `QuranScriptFunction.cacheOfAyah` (on-demand). Kjo shmang parsimin e përsëritur, por ndërtimi i `TextSpan`-eve të shumta ndodh në build të parë.
- Rindërtimi: `BlocBuilder<PlayerPositionCubit>` përdor `buildWhen` që kthen `true` vetëm kur kushtet për `enableWordByWordHighlight`, `AudioUiCubit.state.isInsideQuranPlayer`, dhe ndryshimi i `highlightingWord` plotësohen — pra parandalon rerender kur highlight-i nuk ndryshon.

**Prompt 2 — Logjika e skrollit dhe handoff-it**
- `scrollToAyah` (shiko `lib/src/screen/quran_script_view/quran_script_view.dart`) përdor vlera fikse `alignment`: `0.15` për ayah-by-ayah/reading-mode dhe `0.5` për sidebar visibility; nuk përdoret llogaritje dinamike sipas gjatësisë së ajetit.
- Per-word autoscroll: nuk ekziston. Sistemi scroll-on ayah-in/faqen kur `AyahKey` ndryshon; për fjalët brenda ayah-it të gjatë nuk bëhen per-word centering — duket se mbështeten në alignment-in e ayah-it për të mbajtur fjalën të dukshme.

**Prompt 3 — Menaxhimi i burimeve dhe memoria (Hive vs RAM)**
- `writeQuranScript()` shkruan të gjithë skriptin në Hive (disk), por runtime nuk ngarkon automatikisht të gjitha ayah-t në RAM.
- `QuranScriptFunction.cacheOfAyah` është on-demand: vetëm ayah-t që kërkohen mbahen në memorie.
- `SegmentedResourcesManager` ruan segmentet në Hive gjatë download, por përdor `segmentsCache` per-ayah; nuk ngarkohen të gjitha segmentet në RAM në startup.
- `searchPatternInText` është Levenshtein mbi të gjitha substring-et — shumë e kushtueshme për tekste të mëdha dhe mund të bllokojë thread-in kryesor nëse përdoret për korpuse të mëdha; rekomandohet isolate ose indeksim (FTS) për kërkime globale.

**Prompt 4 — Emrat e sureve, font & rendering**
- Emrat e sureve: ruhen si lista locale në `assets/meta_data/surah_name_localization.json` dhe shfaqen me `getSurahName(context, index)`.
- Font/ligatura: emrat përdoren si string Unicode normal; nuk gjeta përdorim të font-eve me ligatura të dedikuara vetëm për emra, as tabela offset-esh për rreshtim pixel-perfect.

**Pikat kryesore për krahasim me tonat**
- Lead/lag: highlight-i drejtohet nga `positionStream` dhe logjika e segmentit (decisecond granularity) — por nuk përdorin lead-scroll per-word.
- Clamping: nuk përdoret clamping i avancuar; kjo është avantazh UX që mund ta kemi ne.
- Navigation: sidebar përdor `Navigator.pushReplacement`, që ndryshon sjelljen e `Back` në krahasim me push/pop standard.

References:
- `lib/src/widget/quran_script/pages_render/uthmani_page_renderer.dart`
- `lib/src/screen/quran_script_view/quran_script_view.dart`
- `lib/src/utils/quran_resources/quran_script_function.dart`
- `lib/src/utils/quran_resources/segmented_resources_manager.dart`
- `lib/src/utils/filter/search_pattern_in_text.dart`
- `assets/meta_data/surah_name_localization.json`
