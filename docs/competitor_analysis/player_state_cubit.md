# PlayerStateCubit

Source: lib/src/core/audio/cubit/player_state_cubit.dart

## State
- `PlayerState`:
  - `ProcessingState? state` (from `just_audio`)
  - `bool isPlaying`

## Triggers (methods)
- `changeState({ProcessingState? processingState, bool? isPlaying})` — updates processing state and play/pause flag.

## Dependencies
- Uses `just_audio` type `ProcessingState` only; actual audio control lives elsewhere (`AudioPlayerManager`).

## Cross-Cubit Interaction
- Drives play/pause visuals and logic in UI. Often used together with `PlayerPositionCubit` and `AudioUiCubit` to represent playback status.

## Notes
- Small wrapper around audio processing state; designed to decouple UI from audio implementation details.