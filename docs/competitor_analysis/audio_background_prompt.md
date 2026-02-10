### Prompt: Analizë e thellë e Arkitekturës së Background Audio dhe Media Notification

Roli: Ju jeni një Senior Flutter Engineer me ekspertizë në "Audio Streaming" dhe "System Integration".
Objektivi: Analizoni në detaje implementimin e audios në këtë aplikacion, me fokus specifik se si arrihet që audio të luajë në background pa ndërprerje dhe si sinkronizohet me njoftimet (notifications) e sistemit operativ.

Te lutem analizo skedarët e projektit (sidomos folderin `core/audio`, `audio_player_manager.dart`, `audio_service.dart` dhe `main.dart`) për të nxjerrë këtë informacion:

1. Konfigurimi i Shërbimit të Background (Background Service)
- Si inicializohet shërbimi i audios në `main.dart`? A përdoret `AudioService.init` apo ndonjë metodë tjetër?
- Cila është libraria kryesore për menaxhimin e njoftimeve në background? (psh. `just_audio_background`, `audio_service`, apo një implementim manual me `MethodChannels`?)
- Gjej klasën që trashëgon (inherits) nga `BaseAudioHandler`. Dokumento të gjitha metodat që mbishkruhen (overridden) si `play`, `pause`, `seek`, `skipToNext`.

2. Menaxhimi i Metadata-ve dhe MediaItem
- Si ndërtohet objekti `MediaItem` për çdo ajet/sure?
- Si kalohen detajet si: Emri i sures (Title), Recituesi (Artist), dhe Imazhi i recituesit (artUri) te njoftimi i sistemit?
- A përdoren `extras` brenda `MediaItem` për të ruajtur informacione specifike si ID e sures apo numri i ajetit për t'u përdorur nga shërbimi i background-it?

3. Sinkronizimi i State-it (Background ↔ Foreground)
- Kur përdoruesi rihap aplikacionin, si e merr UI "gjendjen" aktuale të audios nga shërbimi që po luan në background?
- Analizo përdorimin e `PlaybackStateStream` dhe `PositionStream`. Si sigurohet aplikacioni që Slider-i në UI është në sinkron të plotë me Slider-in në Notification?

4. Audio Focus dhe Audio Session
- Analizo konfigurimin e `AudioSession`. Çfarë parametrash përdoren për `androidAudioAttributes` (psh. `usage: AudioUsage.media`, `contentType: AudioContentType.music`)?
- Si e trajton aplikacioni "Ducking" (uljen e volumit kur vjen një njoftim tjetër) dhe si reagon kur hiqen kufjet (`becomingNoisyEventStream`)?

5. Arkitektura e Playlist-ës
- Si menaxhohet kalimi nga një ajet te tjetri në background? A përdoret `ConcatenatingAudioSource` i `just_audio` apo ka një logjikë manuale që dëgjon fundin e ajetit për të ngarkuar URL-në tjetër?

Kërkesa finale:
Bëni një listë me "Dependencies & Boilerplate". Çfarë paketash specifike duhet të shtojmë në `pubspec.yaml` dhe çfarë konfigurimesh duhen bërë në `AndroidManifest.xml` dhe `Info.plist` (për iOS) që ky sistem të funksionojë si në video?

---

Checklista e implementimit për ekipin tonë:
1. Lejet në nivel OS: Android (`FOREGROUND_SERVICE`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`) dhe iOS (Enable Background Modes: Audio, AirPlay, Picture in Picture).
2. Audio Handler: një klasë dedikuar që lidh Flutter me njoftimet e sistemit (p.sh. `BaseAudioHandler` implementation).
3. Image Caching: shkarkim i artUri në skedar lokal për t'u përdorur në notifications.
4. Isolate Communication: si komunikohet provider-i kryesor me isolate-in e audios.

Analizoni dhe ktheni një raport të detajuar që përfshin: klasat kryesore, rrjedhat e eventeve (play/pause/seek/complete), stream-et që përdoren, dhe çdo rekomandim për përmirësim ose rrezik integrimi në platforma Android/iOS.

Përzgjedhja e skedarëve për t'u shqyrtuar: `lib/src/core/audio/**`, `lib/src/core/audio/player/audio_player_manager.dart`, `lib/src/core/audio/audio_service.dart`, dhe `lib/main.dart`.

Ky prompt duhet të përdoret si input i drejtpërdrejtë për agjentin AI që do të ekzekutojë analizën.
