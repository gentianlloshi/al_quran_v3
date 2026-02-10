## Analizë e thellë — Background Audio & Media Notification

Ky dokument përmbledh zbulimet mbi implementimin e audios në projekt, e fokusuar në si menaxhohet playback në background dhe si sinkronizohet me njoftimet e sistemit.

1) Konfigurimi i Shërbimit të Background
- Inicializimi: Aplikacioni përdor `just_audio_background`. Në [`lib/main.dart`](lib/main.dart) thirret `JustAudioBackground.init(...)` me `androidNotificationChannelId`, `androidNotificationChannelName` dhe `androidNotificationOngoing: true`. Nuk përdoret `audio_service` ose `AudioService.init` në kodin burim; nuk gjendet klasë që trashëgon `BaseAudioHandler`.
- Implementim: Nuk ka një background handler me `audio_service` — për njoftimet dhe kontrollin e media playback përdoret kombinimi `just_audio` + `just_audio_background` (desktop përdor `just_audio_media_kit`). Kjo do të thotë se njoftimet dhe kontrolli i media përmes notification/lockscreen menaxhohen nga `just_audio_background` automatikisht duke u mbështetur te `MediaItem` tags.

2) Menaxhimi i Metadata-ve dhe `MediaItem`
- Ndërtimi i `MediaItem`: Kur krijohen `AudioSource`-et (shiko `getAudioSourceFromAyahKey()` në `lib/src/core/audio/player/audio_player_manager.dart`) i vendoset `tag: MediaItem(...)`. `MediaItem` përmban të paktën `id`, `album` (reciter.name) dhe `title` (emri i sures). Për playback fjalë-për-fjalë (`playWord`) tag përdor `MediaItem(id: wordKey, title: wordKey)`.
- ArtUri & extras: Nuk gjeta përdorim të fushës `artUri` në objektet `MediaItem` aktuale; as `extras` nuk duket të përdoren për të transmetuar ID të veçanta (p.sh., numrin e ajetit). Kjo kufizon sa metadata shtesë përzgjidhet drejt njoftimit; megjithatë `MediaItem.id` përdoret për identifikim dhe sinkronizim.
- Rekomandim praktik: Shtoni `artUri` me rrugë lokale (file://) kur doni që njoftimi të shfaqë imazhe; nëse jepni URL remote, shkarkojini paraprakisht dhe përdorni path lokal.

3) Sinkronizimi i State-it (Background ↔ Foreground)
- Burimet e të dhënave: `AudioPlayerManager` subscribohet në disa stream-e të `AudioPlayer` (`positionStream`, `bufferedPositionStream`, `durationStream`, `playerEventStream`, `processingStateStream`, `currentIndexStream`) dhe i mapon në `Bloc`-et e aplikacionit (`PlayerPositionCubit`, `PlayerStateCubit`, `AyahKeyCubit`, `AudioUiCubit`). Kjo krijon një pipeline ku UI merr state nga këto cubits.
- Rihapja e aplikacionit: Kur përdoruesi rihap app, UI do të lexojë statet e ruajtura (p.sh., `AyahKeyCubit` ruan `last_ayah_*` në Hive) dhe do t'i shikojë cubits që janë të sinkronizuar në runtime nga `AudioPlayer`. Në mungesë të një `AudioHandler` të dedikuar, sinkronizimi i UI me background varet nga fakti nëse process-i i audio-s është ende i gjallë dhe nëse `AudioPlayer` instanca vazhdon të ekzistojë në process. Për sesionet ku app është ndaluar plotësisht, nuk ka persistim millisekondash të pozicionit — kështu UI/notification mund të mos rikthejnë pozicionin e sakët pa mekanizëm shtesë.
- Slider sync me Notification: `positionStream` përditëson `PlayerPositionCubit` dhe UI lexon nga ai cubit për të vendosur slider-in. `just_audio_background` përditëson notification bazuar në `AudioPlayer` intern; praktika e përputhjes kërkon që MediaItem tags dhe position stream të mbahen të sinkronizuara — kjo realizohet aktualisht nga `audioPlayer.positionStream` dhe `await audioPlayer.play()` etj.

4) Audio Focus dhe Audio Session
- Gjendja aktuale: Nuk u gjet përdorim i paketës `audio_session` në kod. Nuk ka konfigurim eksplicit të `AudioSession` me `androidAudioAttributes` (`usage`, `contentType`) apo `setActive()`/`setActiveFalse()` me policy për ducking.
- Ducking / becomingNoisy: Nuk u gjet referencë për `becomingNoisyEventStream` ose handler të `AudioSession`/`audio_service`. Për momentin, sjellja e ducking/interruptions mbetet ajo default e platformës dhe e `just_audio` pa opsione të specializuara për trajtim (p.sh., automatik pause on phone call, ducking policy). Për rritje të besueshmërisë rekomandohet shtimi i `audio_session` dhe konfigurimi i audio attributes + `becomingNoisy` handler për të kapur headset-unplug events.

5) Arkitektura e Playlist-ës
- Menaxhimi i playlist-ës: Kur luhet një rang ajetesh, `playMultipleAyahAsPlaylist()` krijon listë `listOfAudioSource` dhe thërret `audioPlayer.setAudioSources(listOfAudioSource, ...)`. `just_audio` pranon një listë audio sources dhe e menaxhon intern concatenation/shuffle; në praktikë ajo është ekuivalente me përdorimin e një `ConcatenatingAudioSource` pas skenarit që përdor `setAudioSources`.
- Kalimi automatik: `processingStateStream` dhe `currentIndexStream` dëgjohen në `AudioPlayerManager` — kur `currentIndex` ndryshon, `AyahKeyCubit` azhurnohet për t'iu përgjigjur ndryshimit. Kjo nënkupton që kalimi mes ajeve menaxhohet automatikisht nga `just_audio` në kombinim me stream-et që e propagojnë ndryshimin në UI.

6) Mungesa të rëndësishme & Rekomandime
- Nuk ka `AudioHandler` (`audio_service`) / `BaseAudioHandler` implementation: për funksionalitete të avancuara background (p.sh., që shërbimi të vazhdojë pavarësisht se Flutter engine-u është kill-uar), rekomandohet përdorimi i `audio_service` i cili ofron `BaseAudioHandler` dhe një lifecycle të qartë të background worker.
- Persistim millisekondash: Ruajtja periodike (p.sh., çdo 5–10s) e pozicionit aktual në Hive ose në `AyahKeyCubit` do të lejonte resume të saktë kur process-i ndalet dhe përdoruesi rihap app.
- Audio focus & ducking: Shto `audio_session` dhe konfiguroni `androidAudioAttributes` me `usage: AudioUsage.media` dhe `contentType: AudioContentType.speech` ose `music` sipas rastit; implemento `becomingNoisy` dhe `interruption` handlers.
- Metadata & artUri: Shto `artUri` (file:// path) në `MediaItem` dhe shkarko imazhet e recituesve lokalisht. Kjo përmirëson shfaqjen e imazheve në njoftime.
- Download-resume & integrity: `downloadSurah()` përdor `Dio().download` pa resume. Për skedarë të mëdhenj rekomandohet `range`-based resume dhe verifikim checksum.

7) Dependencies & Boilerplate të rekomanduar
- `pubspec.yaml` (të mbani/shtoni):
  - just_audio
  - just_audio_background
  - just_audio_media_kit (desktop, optional)
  - audio_session (rekomanduar)
  - permission_handler (për notifications/permissions)
  - dio (për download)

- `AndroidManifest.xml` (shtesa të nevojshme):
  - `<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />`
  - `<uses-permission android:name="android.permission.WAKE_LOCK" />`
  - `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />`
  - Siguroni se `android:exported` është i vendosur sipas rregullave kur shtoni `BroadcastReceiver` për boot (nëse e përdorni).
  - Konfiguroni kanal njoftimi në native layer ose përdorini opsionet e `JustAudioBackground.init`.

- `Info.plist` (iOS):
  - Shto `UIBackgroundModes` → `audio` (Audio), `remote-notification`/`fetch` sipas nevojës.
  - Për artUri remote, sigurohuni që `NSAppTransportSecurity` lejon kërkesat nëse domain-i nuk përdor HTTPS.

8) Checklist implementimi (për ekipin tuaj)
- Shtoni `audio_session` dhe konfiguroni `AudioSession.instance.configure(...)` për policy-et e audio.
- Implementoni `BaseAudioHandler` nëse dëshironi kontroll të plotë të lifecycle të background (p.sh., support për playback edhe kur Flutter engine-u mbyllet).
- Shtoni shkarkimin e artUri dhe ruajten si file local; përdorni këto paths në `MediaItem.artUri`.
- Persistoni `PlayerPosition` periodikisht dhe ripopulloni `audioPlayer.seek()` gjatë rifillimit.
- Shtoni boot receiver (opsional) për të ristartuar njoftimet pas boot nëse duhet.

Përmbledhje e shkurtër
- Implementimi aktual përdor `just_audio` + `just_audio_background` dhe mbështetet te MediaItem tags + position/player streams për sinkronizim. Nuk përdoret `audio_service` ose `AudioHandler`, as `audio_session`. Kjo zgjidhje është e thjeshtë dhe e mjaftueshme për shumicën e përdorimeve, por ka blind-spot-e për edge-cases (interruptions, resume pas kill, artUri remote handling). Për një shërbim më të besueshëm background rekomandohet kombinuar `audio_service` + `audio_session` me persisitim pozicioni dhe image caching.

Referenca e vendosur për shqyrtim në kod:
- `lib/main.dart`
- `lib/src/core/audio/player/audio_player_manager.dart`

Fundi i analizës
