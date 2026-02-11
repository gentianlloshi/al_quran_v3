---
title: Analizë e Audio Player UI — Verse-Based Slider (Deep Dive)
date: 2026-02-11
---

## Përmbledhje

Ky dokument përmbledh zbulimet nga analiza e komponentëve audio që lidhen me slider-in "verse-based" në aplikacionin Kurani Fisnik. Kodet e studiuara kryesore janë:

- `lib/src/widget/audio/audio_controller_ui.dart`
- `lib/src/core/audio/player/audio_player_manager.dart`
- `lib/src/core/audio/cubit/player_position_cubit.dart`

Përmbledhja kryesore: aplikacioni përdor dy mekanizma të progresit — një bar kohor (`ProgressBar` nga `audio_video_progress_bar`) dhe një `Slider` diskret për navigim midis ajetave të një sureje (ose playlist-i). Sinkronizimi bëhet përmes streameve të `just_audio` (`positionStream`, `currentIndexStream`, etj.) dhe Cubits (`PlayerPositionCubit`, `AyahKeyCubit`, `PlayerStateCubit`).

---

## 1) Arkitektura e Slider-it (Discrete vs Continuous)

- Continuous (kohor): `ProgressBar` nga package `audio_video_progress_bar` tregon `currentDuration`, `buffered` dhe `total`.
- Discrete (verse-based): `Slider` standard i Flutter me `divisions` të vendosur (`divisions: ayahList.length - 1`). Nuk përdoret komponent i personalizuar për snap — `divisions` ofron snapping diskret.

Si funksionon snapping në praktikë:

- Slider vlerësohet me `value: ayahList.indexOf(state.current).toDouble()`.
- `onChanged` merr `value` dhe e rrumbullakos me `.toInt()` për të përftuar `verseIndex`.
- Pastaj thirret `AudioPlayerManager.audioPlayer.seek(Duration.zero, index: value.toInt());` për t'u zhvendosur te ajo njësi audio.

Matematika e mapimit ms → verseIndex (nëse kërkohet):

Nëse kemi kohët e secilit item (D_i) dhe t_ms është pozicioni aktual në ms,
$$
verseIndex = \min\{k \mid \sum_{i=0}^{k} D_i > t_{ms}\}
$$

Ky lloj mapping kërkon boundary/ duration për çdo item; në mungesë të një tabele të përpiluar, duhet të mblidhen `duration` për secilën `AudioSource` ose të ruhet si metadata.

---

## 2) UI i Progresit (Surah:Ayah Label)

- Labeli i progresit (p.sh. `3:200`) renditet direkt në `playerSliders()` përmes `Text(state.current)`.
- `AyahKeyCubit` mban `AyahKeyManagement` me `start`, `end`, `current`, `ayahList`.
- `AudioPlayerManager.currentIndexStream` dëgjon `audioPlayer.currentIndexStream` dhe bën `ayahKeyCubit.changeCurrentAyahKey(ayahKeyCubit.state.ayahList[event])` — kjo mban etiketen `current` të sinkronizuar me index-in e playlist.

Dual-Track display:
- Shtresa e sipërme: `ProgressBar` tregon kohën (`currentDuration` / `totalDuration`).
- Shtresa e poshtme: `Row` me `Text(state.current)` — `Slider` — `Text(ayahList.last)` që tregon përkatësinë Surah:Ayah dhe range-in.

---

## 3) Struktura e Mini-Player dhe Expanded Player

- Komponent kryesor: `AudioControllerUi` (StatefulWidget).
- Gjendja kontrollohet nga `AudioUiCubit` (fusha: `showUi`, `isInsideQuranPlayer`, `isExpanded`).
- Animacionet: kombinim `TweenAnimationBuilder<double>` (për `borderRadius`) dhe `AnimatedContainer` (për `height`, `width`, dhe dekor).
- Mini view: ikonë e vetme play/pause (kur `!state.isExpanded`).
- Expanded view: `getFullAudioControllerUI` që kthen `Row` (landscape) ose `Column` (mobile) me `playerSliders()` dhe `playerControllers()`.
- Ndërmjetësimi mini ↔ expanded bëhet me `AudioUiCubit.expand(true/false)` (onTap dhe butoni close).

---

## 4) Sinkronizimi i Komandave (User Input)

- Slider (verse-based) `onChanged`: përftohet `ayahKey = ayahList[value.toInt()]`.
- Në playlist-mode: thirret `AudioPlayerManager.audioPlayer.seek(Duration.zero, index: value.toInt())`.
- Në single-ayah-mode (kur `ayahList.length == 1`), për të luajtur ayah tjetër, kodi thërret `AudioPlayerManager.playSingleAyah(...)` për të ndërtuar burimin audio për atë ayah.
- Time-based `ProgressBar.onSeek`: `AudioPlayerManager.audioPlayer.seek(duration)` — ndryshon pozicionin brenda item-it aktual.

Streams & sinkronizim:
- `positionStream` → `playerPositionCubit.changeCurrentPosition(event)` për rifreskimin e `ProgressBar`.
- `currentIndexStream` → `ayahKeyCubit.changeCurrentAyahKey(...)` për rifreskimin e `Slider` dhe etiketeve.
- `playerEventStream` + `processingStateStream` → `PlayerStateCubit` për përditësimin e ikonave dhe gjendjeve.

---

## 5) Vizualizimi (Waveform / Icons)

- Nuk u gjet përdorim i paketave të dedikuara për waveforms në këto skedarë. UI përdor `audio_video_progress_bar` për track visualization.
- Ikonat Play/Pause variojnë sipas `PlayerStateCubit.state.isPlaying`.
- `AudioPlayerManager.processingStateStream` shkruan `processingState` në `PlayerStateCubit` — kjo mund të përdoret për të treguar `loading` kur `ProcessingState.loading`.

---

## Rekomandime të Shkurtra

1. Për një "global verse slider" (për gjithë Kur'anin), krijoni një `List<int> cumulativeStartMs` (ose map `verseKey -> startMs`) dhe përdorni binsearch për ms → verseIndex (O(log n)).
2. Përdorni `onChangeStart` / `onChangeEnd` në `Slider` për të ndaluar play gjatë drag (mos nxjerr gjendje të papritura) dhe ri-play pas drop sipas preferencës.
3. Nëse doni waveform, integroni `audio_waveforms` ose `waveform_flutter` dhe ruani precomputed waveform data për çdo ayah.
4. Për performancë: shmangni `ayahList.indexOf(state.current)` në loops të shpeshta; ruani `currentIndex` si integer në Cubit.

---

## Code Blueprint — `VerseSlider` (i thjeshtuar)

Shembull i një widget-i të thjeshtë që pranon `totalVerses`, `currentVerseIndex` dhe callback `onVerseSelected`.

```dart
import 'package:flutter/material.dart';

typedef VerseSelected = void Function(int verseIndex);

class VerseSlider extends StatelessWidget {
  final int totalVerses;
  final int currentVerseIndex;
  final VerseSelected onVerseSelected;
  final String? leftLabel;
  final String? rightLabel;

  const VerseSlider({
    Key? key,
    required this.totalVerses,
    required this.currentVerseIndex,
    required this.onVerseSelected,
    this.leftLabel,
    this.rightLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final max = (totalVerses > 0) ? (totalVerses - 1).toDouble() : 0.0;
    final value = currentVerseIndex.clamp(0, totalVerses - 1).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (leftLabel != null) Text(leftLabel!, style: TextStyle(fontSize: 12)),
            Spacer(),
            if (rightLabel != null) Text(rightLabel!, style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: max,
            divisions: totalVerses > 1 ? totalVerses - 1 : null,
            onChanged: (v) {
              onVerseSelected(v.toInt());
            },
            onChangeEnd: (v) {
              onVerseSelected(v.toInt());
            },
          ),
        ),
      ],
    );
  }
}
```

### Integrim me `AudioPlayerManager`

Për playlist-mode:

```dart
AudioPlayerManager.audioPlayer.seek(Duration.zero, index: verseIndex);
```

Për single-ayah-mode:

```dart
AudioPlayerManager.playSingleAyah(ayahKey: selectedAyahKey, reciterInfoModel: reciter, isInsideQuran: true);
```

---

## Çfarë u bë dhe hapat e mëtejshëm

- U lexuan dhe u analizuan `audio_controller_ui.dart`, `audio_player_manager.dart`, `player_position_cubit.dart`.
- U nxorën logjika e slider/time sync, metoda të kërkuara për seek, dhe rekomandime implementimi.

Opsionale (mundohem t'i implementoj nëse kërkon):

- Ndërtim i `GlobalVerseMapper` (cumulative durations) për ms → verseIndex.
- Refaktorim i `audio_controller_ui.dart` për `onChangeStart`/`onChangeEnd` behavior.
- Shtim i një mini-integration example me `VerseSlider` dhe `AudioPlayerManager.seek(...)`.

---

Dokument i ruajtur si `docs/competitor_analysis/verse_slider_deep_dive.md`.
