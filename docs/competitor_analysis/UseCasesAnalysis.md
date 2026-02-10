## Use Cases & Edge Cases Analysis

Përmbledhje QA (detajuar)

1) Audio — Resume / Interrupt / Speed
- Rifillimi: `AyahKeyCubit` ruan `last_ayah_start`, `last_ayah_end`, `last_ayah_current` në Hive. Kështu aplikacioni ruan nivelin e ajetit (cilin ayah po luhet) por **nuk** persiston pozicionin në milisekonda. `PlayerPositionCubit` mban pozicionin aktual në memorie gjatë sesionit, por nuk shkruan automatikisht atë në disk. (ref: `lib/src/core/audio/cubit/ayah_key_cubit.dart`, `lib/src/core/audio/cubit/player_position_cubit.dart`)
- Ndërprerjet: Nuk gjendet përdorim i `audio_session` apo handlers të specializuar për "becoming noisy" (headset-unplug) ose për audio-focus (telefonata). `just_audio` streams (p.sh., `positionStream`, `processingStateStream`, `errorStream`) monitorohen dhe error-et shfaqen si dialog, por mungon logjikë e dedikuar për phone-call/headset/unplug. Prandaj sjellja mbështetet tek sjellja default e platformës/`just_audio`. (ref: `lib/src/core/audio/player/audio_player_manager.dart`)
- Shpejtësia e luajtjes: `AudioPlayerManager` konfiguronte shpejtësinë me `audioPlayer.setSpeed(playbackSpeed)` duke marrë vlerën nga `QuranViewCubit.state.playbackSpeed`. Highlight-i bazohet në `positionStream` që raporton pozicionin në ms, kështu në teorinë sinkronizimi ruhet kur ndryshohet shpejtësia. Kujdes: `playWord()` përdor mekanizma të veçantë për playback dhe mund të mos ndjekë gjithmonë global speed, kështu që preview per-word mund të degradojë sinkronizimin.

2) Gabimet & Mungesa e Rrjetit
- Offline Play: Para se të luajë, `shouldContinuePlaying()` kontrollon preferencën `useAudioStream`. Nëse `useAudioStream==false` dhe skedarët lokalë mungojnë, shfaqet `AlertDialog` që ofron download të surah-së për t'u shkarkuar. Nëse `useAudioStream==true` aplikacioni tenton të stream-ojë (p.sh., `LockCachingAudioSource`); në mungesë rrjeti `errorStream` do të kapë gabimin dhe do shfaqë dialog gabimi. Pra UX: paralajmërim + opsion download, ose error dialog për stream. (ref: `AudioPlayerManager.shouldContinuePlaying()`)
- Download i ndërprerë: `downloadSurah()` përdor `Dio().download` me `deleteOnError: true` dhe `CancelToken`. Në rast anulimi / gabimi, partial file fshihet (nëse ekziston). Nuk ka mekanizëm automatic resume/auto-retry; funksioni ndalon dhe përdoruesi duhet të rilauzojë download. `AudioDownloadCubit` përditësohet për progress / isDownloading. (ref: `AudioPlayerManager.downloadSurah()`, `AudioDownloadCubit`)
- Missing segments: `SegmentedResourcesManager.getAyahSegments()` kthen `null` kur segmentet mungojnë; rendererët kontrollojnë `segments==null` dhe në atë rast nuk bëjnë per-word highlight. Fallback: highlight i të gjithë ayah-it ose asnjë highlight fjale-për-fjale. UI degradon butësisht, pa crash. (ref: `SegmentedResourcesManager`, `uthmani_page_renderer.dart`)

3) UI / Layout Edge Cases
- Ndryshimi i fontit gjatë playback: `QuranViewCubit.changeFontSize()` persiston vlerën dhe emetton state; nuk u gjet listener që rillogarit/realign-ojë scroll-offset për të ruajtur fjalen aktive në vendin pikselor. Ekziston `ItemPositionsListener` për evente të tjera, por nuk ka mekanizëm dedikuar për font-change → realign. Rreziku: ajeti i aktivizuar mund të zhvendoset jashtë shikimit. (ref: `quran_script_view.dart`, `quran_script_view_cubit.dart`)
- Extreme verse length (2:282): Renderer krijon shumë `TextSpan`-e por nuk bën per-word centering; paneli i audios është overlay (Stack + SafeArea bottom-right) dhe nuk gjendet kompensim automatik që parandalon mbulimin e fjalës aktive. Pra mund të ndodhë që fjala aktive të mbulohet nga toolbar/audio panel për ajetet shumë të gjata. (ref: `uthmani_page_renderer.dart`, `quran_script_view.dart`)
- Screen Rotation / Split screen: `AyahKeyCubit` persiston `last_ayah_*` në Hive, kështu logjikisht ayah-i i aktivizuar ruhet pas rotacionit. Por nuk ruhet offset-i millisekondor ose pozicioni pikselor; pas rotacionit widget-et rindërtohen dhe pozicioni i pamjes mund të ndryshojë.

4) Njoftimet / Prayer Times / Vendndodhja / Bateria
- Ndryshimi i vendndodhjes: `LocationQiblaPrayerDataCubit.saveLocationData()` ruan vendndodhjen në `SharedPreferences` dhe kalkulon `kaabaAngle`, por nuk gjendet logjikë e qartë që ri-schedulon automatikisht njoftimet kur vendndodhja ndryshon. Scheduling dhe notifikimet platform-specifike duken pjesërisht të paplotësuara (pjesë të `platform_services_io.dart` janë TODO). (ref: `location_data_qibla_data_cubit.dart`, `platform_services_io.dart`)
- Doze / exact alarms: Ka kërkim të lejes `Permission.scheduleExactAlarm` dhe disa mësime për user (l10n warnings) që njoftimet mund të humbasin për shkak të OEM restrictions. Megjithatë integrimi real me `alarm`/`awesome_notifications` është i komentuara/partial kështu nuk ka garanci unike për Doze mode pa implementim shtesë. (ref: `lib/src/core/alarm/request_permission.dart`, `platform_services_io.dart`)

5) "Çfarë ndodh kur çdo gjë shkon keq?" — Përmbledhje e shpejtë
- Pa RAM / Memorie e ulët: App përdor caching on-demand (Hive + `cacheOfAyah`, `segmentsCache`). Nuk ngarkon gjithë bazën në RAM, por krijimi i shumë `TextSpan`-eve për ajetet e gjata mund të shkaktojë OOM/lag gjatë render-it të parë. Rekomandim: chunking/span-chunking, RepaintBoundary, ose pre-baked `TextPainter` për elementë jashtë-shikimit.
- Pa internet: Stream do të dështojë dhe tregohen dialog-e gabimi; downloads do të ndalen (pa retry). Segmente mungojnë → fallback në highlight ajeti (jo per-word). Përdoruesi duhet të rilauzojë download për të rikuperuar.
- Skedarë të korruptuar/partial: `downloadSurah()` fshin partial files në error/cancel; nuk ka auto-repair/resume — përdoruesi duhet të rifillojë.
- Interruption (telefonatë/headset): Since no dedicated audio-focus handlers, behavior mbështetet te platforma/`just_audio` default — mund të rezultojë në pauzë pa rikthim të avancuar nga app.

Vlerësim i qëndrueshmërisë
- Status: "Moderatisht i qëndrueshëm, por me blind-spots".
  - Pozitiv: on-demand caching, persistence e ayah-key, fallback për mungesë segments, dhe progress tracking për downloads.
  - Negativ: mungesë persistimi millisekondash për resume, mungesë audio-focus/becomingNoisy handling, mungesë download-resume, nuk rifreskohet scroll me font-change, dhe notifikimet/alarms pjesërisht të paplota.

Rekomandime prioritare (shkurt):
1. Persistim i `PlayerPosition` në intervals (p.sh., çdo 5-10s) për resume millisekondash.
2. Shto `audio_session` + listener për `becomingNoisy` (headset-unplug) + audio-focus për phone-calls.
3. Implemento download-resume (range requests) + retry policy + checksum verification.
4. Shto listener për font-size change që rillogarit/realign-ojë view-in për të mbajtur fjalen aktive në shikim.
5. Finalizo `platform_services_io` për notifikime/alarme dhe përdor `Permission.scheduleExactAlarm` me fallbacks dhe user guidance për OEM restrictions.

Referenca kryesore (pjesë të kontrolluara):
- `lib/src/core/audio/player/audio_player_manager.dart`
- `lib/src/core/audio/cubit/ayah_key_cubit.dart`
- `lib/src/core/audio/cubit/player_position_cubit.dart`
- `lib/src/screen/settings/cubit/quran_script_view_cubit.dart`
- `lib/src/utils/quran_resources/segmented_resources_manager.dart`
- `lib/src/screen/location_handler/cubit/location_data_qibla_data_cubit.dart`
- `lib/src/screen/audio/download_screen/cubit/audio_download_cubit.dart`
- `lib/src/core/alarm/request_permission.dart`
- `assets/meta_data/surah_name_localization.json`
