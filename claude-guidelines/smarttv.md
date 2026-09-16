# Platform checklist — Smart TV (Preact monorepo: webOS, Tizen, Vizio, Vidaa, WhaleTV)

`packages/core` holds the application; `apps/<platform>` are thin shells.
Lint, format and types are covered by `npm run lint` and `npm run format`.

## Monorepo boundaries

- New feature code belongs in `packages/core`. Code under `apps/<platform>/`
  is only justified when it cannot exist without that platform's SDK
  (Tizen, webOS, Vidaa APIs). Flag feature logic that leaked into an app shell.
- Platform branching goes through `services/platform.js`
  (`isSamsungPlatform()` and friends) and the `Platform` enum, not through
  ad-hoc user-agent sniffing or `VITE_PLATFORM` string comparisons scattered
  in components.
- All five apps build into the same root `build/` directory. Flag build
  script changes that assume per-platform output directories.

## TV constraints

- **Focus and navigation are the whole UX.** Any new interactive element must
  be reachable with the D-pad and must not create a focus trap. Flag new
  clickable elements with no keyboard/remote handling.
- Keycodes differ per platform and come from committed `.env` values
  (`VITE_KEYCODE_BACK`, etc.). Hardcoded numeric keycodes in a component are
  a defect.
- TV browsers are old and slow. Flag newly introduced use of APIs that are
  not safe on 2018-era webOS/Tizen engines, heavy per-frame work, and large
  synchronous loops in render paths.
- Memory is tight. Images and video elements that are mounted and never
  released will kill a session after a few hours of browsing.

## Playback

- Player state must survive backgrounding and the screensaver. Samsung wraps
  `<Base />` with a `ScreenSaverProvider` — new playback code should respect it.
- DRM and streaming errors need a user-visible path, not just a console log.

## Testing

Vitest covers `packages/core`. If the PR changes logic under `packages/core`
that has neighbouring tests and adds none, say which behavior is now untested.
