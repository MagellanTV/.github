# Platform checklist — Android / Fire TV

## Lifecycle and leaks

- Coroutines launched outside `viewModelScope` / `lifecycleScope` outlive the
  screen. Flag `GlobalScope` and bare `CoroutineScope(...)` in UI code.
- Listeners, `BroadcastReceiver`s, `ExoPlayer` instances and `MediaSession`s
  registered in `onStart`/`onResume` must be released in the matching
  `onStop`/`onPause`. A retained player is the most common OOM on TV devices.
- Holding a `Context`, `Activity` or `View` reference in anything longer-lived
  than the screen is a leak.

## Concurrency

- Network, disk and database work on the main thread. Flag it.
- `StateFlow`/`LiveData` collected without a lifecycle-aware collector keeps
  emitting to a dead view.

## Compatibility

- New API usage above the project's `minSdk` needs a version guard. Fire TV
  devices sit on old API levels for years.
- Leanback / D-pad: on TV, every new interactive composable or view needs
  focus handling. Touch-only affordances are a defect on Fire TV.

## Playback

- ExoPlayer error paths (`onPlayerError`) must surface something to the user.
- Track selection, bitrate ladder and DRM changes are high risk — call them
  out even when the diff looks small.

## Data and storage

- Schema changes to Room, DataStore or SharedPreferences need a migration.
  Devices in the field carry old data.
- Do not log account identifiers or entitlement responses.
