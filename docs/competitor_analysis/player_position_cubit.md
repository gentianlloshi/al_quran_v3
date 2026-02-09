# PlayerPositionCubit

Source: lib/src/core/audio/cubit/player_position_cubit.dart

## State
- `AudioPlayerPositionModel` (fields inferred):
  - `currentDuration` (Duration?)
  - `bufferDuration` (Duration?)
  - `totalDuration` (Duration?)

## Triggers (methods)
- `changeCurrentPosition(Duration? position)`
- `changeBufferPosition(Duration? position)`
- `changeTotalDuration(Duration? duration)`
- `changeData(AudioPlayerPositionModel audioPositionData)`

## Dependencies
- No direct external services in cubit file. Values are typically fed by the audio player callbacks in `AudioPlayerManager`.

## Cross-Cubit Interaction
- Consumed by UI and logic that maps audio position -> ayah/word (together with `SegmentedQuranReciterCubit` and `AyahKeyCubit`).

## Sync role
- Provides the canonical playback positions used to compute progress percentage and to look up the matching audio segment mapping (if segmented recitations are present).