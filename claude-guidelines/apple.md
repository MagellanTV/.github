# Platform checklist — Apple (iOS / tvOS)

## Memory and lifecycle

- Closures capturing `self` strongly inside a retained object create cycles.
  Check every new escaping closure for `[weak self]`.
- `Combine` cancellables and `Task` handles stored on a view model must be
  cancelled when it goes away.
- `AVPlayer` and `AVPlayerItem` observers (`addObserver`, `addPeriodicTimeObserver`)
  must be removed. A leaked time observer keeps the player alive.

## Concurrency

- UI mutation off the main actor. Flag it — `@MainActor` or `DispatchQueue.main`.
- `async let` and `TaskGroup` work that is never awaited or cancelled.

## Correctness

- Force unwraps (`!`) and `try!` on anything derived from the network or from
  disk. Each one is a crash waiting for a bad response.
- `guard let` chains that silently return, hiding a real failure.

## tvOS specifics

- Focus engine: every new interactive view needs to be focusable and reachable
  with the Siri Remote. Custom focus guides need a reason.
- Top Shelf, deep links and universal links parse untrusted input.

## Compatibility

- New API usage needs `@available` guards against the project's deployment
  target. Apple TV boxes stay on old tvOS versions.
- Changes to persisted models (`Codable`, Core Data, Keychain keys) need a
  migration path for installs already in the field.
