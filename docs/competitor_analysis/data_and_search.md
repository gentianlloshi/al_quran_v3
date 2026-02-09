**Menaxhimi i të Dhënave & Kërkimi**

- **Përmbledhje e shkurtër:**: Tekstet e Kur'anit dhe përkthimet ruhen kryesisht si json të kompresuar në assets/ose si kuti Hive (lazy/regular) pas shkarkimit ose pas inicializimit; nuk përdoret SQLite/SQL për përmbajtjen kryesore. Kërkimi i ndërfaqeve (p.sh., kërkimi i sureve) kryhet në memorie me algoritëm afërsie (Levenshtein), dhe nuk ka indeksim full-text të centralizuar për tekstin arab apo përkthimet.

- **Si ruhen tekstet e Kur'anit:**
  - Burimi origjinal i skriptit: JSON të kompresuar të pranishëm në `assets/quran_script/` (p.sh., `QPC_Hafs_Tajweed_Compress.json`, `Uthmani.json`, `Indopak.json`). Shiko: `lib/src/utils/quran_resources/quran_script_function.dart`.
  - Pas instalimit/init-it: kodi shkruan secilën ayah në kuti Hive `script_<type>` (p.sh., `script_tajweed`) për përdorim me lexuesin. Kjo bëhet nga `QuranScriptFunction.writeQuranScript()`.
  - Run-time caching: `QuranScriptFunction.cacheOfAyah` mbahet për të shmangur lexime të përsëritura nga Hive.

- **Si ruhen përkthimet (translations):**
  - Përkthimet ofrohen si skedarë të kompresuar (bz2/json) mbi API dhe shkarkohen me `Dio`.
  - Pas shkarkimit, secili përkthim publikohet në një `Hive.lazyBox` me emër të sanitizuar (p.sh., `translation_en_<book>`). Shiko: `lib/src/utils/quran_resources/quran_translation_function.dart`.
  - Përzgjedhjet e përdoruesit dhe metadata ruhen në kuti `user` të Hive (lista e përkthimeve të shkarkuara / të zgjedhura).
  - Ekziston cache lokale në memorie për kombinime përkthim + word-by-word: `get_translation_with_word_by_word.dart` përdor një `cacheOfAyahKeys` map.

- **Word-by-word (wbw):**
  - Po, WbW ruhet dhe menaxhohet si kuti të veçanta Hive (p.sh., `wbw_<lang>_<book>`). `WordByWordFunction` ofron `init()`, `downloadResource(...)` dhe `getAyahWordByWordData(ayahKey)`.

- **A përdoret SQLite / SQL / një DB relac. ?**
  - Jo — nuk gjeta përdorim të `sqflite`/`sqlite` në kodin burim. Gjithçka bazohet në Hive për ruajtje lokale (kutia `user`, lazy boxes për përkthime, kuti për script-et, etj.).

- **Logjika e kërkimit:**
  - Për lista dhe UI-level search (p.sh., kërkimi i sureve në `JumpToAyah` ose `SurahListView`) përdoret një funksion memorie: `searchPatternInText()` (implementim Levenshtein + krahasim mbi substrings). Ky funksion kthen një përqindje ngjashmërie dhe rezultatet radhiten sipas skorit. Shiko: `lib/src/utils/filter/search_pattern_in_text.dart` dhe `lib/src/utils/filter/filter_surah.dart`.
  - Nuk gjeta një rutinë që përpiqet të kryejë një kërkim full-text në gjithë bazën e përkthimeve/tekstit (p.sh., të iteronte të gjitha ayah-t dhe të bënte një query optimizuar në DB). Në praktikë, kërkimet që kërkojnë përkthime ngarkojnë përkthimin për ayah-in e kërkuar (`QuranTranslationFunction.getTranslation(ayahKey)`) ose përdorin utilitete të filtrave për lista të vogla.

- **Si trajtohet Arabic vs përkthimi në kërkim:**
  - Nuk ka transformim/normalizim të avancuar (p.sh., normalizim harakat/diacritics) të dukshëm si pjesë e funksionit të kërkimit. Kërkimet e listave përdorin `toLowerCase()` dhe Levenshtein për krahasim, kryesisht për emra sure/ID.
  - Për kërkime brenda tekstit arab (full-text) nuk ka një rrugë të centralizuar ose optimizim — nëse kërkohet, implementimi do të duhet ose të: (a) shkarkojë të gjithë përkthimet/tekstin dhe të bëjë kërkime në memorie, ose (b) të ndërtojë një indeks (p.sh., SQLite FTS/Whoosh/S2) për kërkime efikase.

- **Caching-u i të dhënave:**
  - Hive është burimi i qëndrueshëm i caching-ut: skriptet e shkruara (script_* boxes), përkthimet (`translation_*` lazy boxes) dhe word-by-word (`wbw_*` boxes).
  - Ka caches në memorie për performancë: `QuranScriptFunction.cacheOfAyah`, `get_translation_with_word_by_word.cacheOfAyahKeys`, `SegmentedResourcesManager.segmentsCache`.

- **Shkarkimi dhe caching i audios:**
  - Audio për çdo ayah mund të shkarkohet në disk (në `applicationDataPath/recitations/...`) me `AudioPlayerManager.downloadSurah()` që përdor `Dio` dhe shkruan skedarë mp3 të ndara për çdo ayah.
  - Për stream remote përdoret `LockCachingAudioSource` (nga `just_audio`) për të cache-uar remote assets për platformat mobile/desktop të mbështetura.
  - Kur luhet si playlist, `AudioPlayerManager` ndan `AudioSource.file` (lokal) ose `LockCachingAudioSource` (remote + local caching) dhe përdor `just_audio` për playback.

- **Pikat e dobëta / kufizimet aktuale:**
  - Nuk ka indeksim full-text: kërkimet brenda përkthimeve/teksit arab nuk janë optimizuar dhe do të jenë të ngadalta nëse bëhen duke iteruar të gjitha ayah-t pa indeks.
  - Nuk gjeta normalizim të tekstit arab (lidhur me tashkeel/harakat/kosin), që mund të ndikojë në saktësinë e kërkimeve në tekst arab.

- **Rekomandime të shkurtra:**
  - Shto një modul optional FTS: p.sh., SQLite FTS5 (via `sqflite`) ose një indeks invertues në Hive për kërkime full-text mbi përkthimet dhe/ose një normalizim për tekstin arab para indeksimit.
  - Sill cache incremental / paginim kur skanohen të gjitha ayah-t (për të shmangur memorie të tepërt gjatë kërkimeve globale).

Referencat kryesore (pjesë kyçe e implementimit):
- `lib/src/utils/quran_resources/quran_script_function.dart` (skriptet & cache)
- `lib/src/utils/quran_resources/quran_translation_function.dart` (përkthimet & download në Hive)
- `lib/src/utils/quran_resources/word_by_word_function.dart` (wbw)
- `lib/src/utils/filter/search_pattern_in_text.dart` (algoritmi i kërkimit/afërsisë)
- `lib/src/core/audio/player/audio_player_manager.dart` (audio download/play & caching)
- `lib/src/utils/quran_resources/segmented_resources_manager.dart` (segmentet e sinkronizimit audio)
