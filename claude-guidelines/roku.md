# Platform checklist — Roku (BrightScript / SceneGraph)

Deployable source lives under `dist/`. Lint and format are enforced by
`bslint` and `npm run format` — do not review what those already catch.

## Language

- BrightScript has no compile-time type checking. Every field read off an
  `roAssociativeArray` or a node can be `invalid`. Guard with `isValid()` /
  type checks before dotting into it.
- `m.top` fields must be declared in the component's XML `<interface>` before
  they are set from BrightScript. A field set but never declared silently
  does nothing.
- Function names are global across the whole channel. A new global function
  with a common name can shadow another one. Prefer component-scoped helpers.
- `invalid` compared with `=` behaves differently from most languages. Flag
  equality checks against `invalid` that should be `<>` or type checks.

## SceneGraph

- Observers registered with `observeField` must be removed with
  `unobserveField` when the component is destroyed, or the callback fires
  against a dead node.
- Work that touches the network or the filesystem belongs in a `Task` node,
  never on the render thread. Anything blocking in a component's
  `init()` or in a field observer will stutter the UI.
- Task nodes must have their `control` field set to `"RUN"` and should be
  stopped explicitly. Flag tasks that are created per keypress and never
  reused or cancelled.
- Node creation in a loop (`CreateObject("roSGNode", ...)`) is expensive on
  low-end devices. Prefer reusing children or `RowList`/`MarkupGrid` content.

## Playback and remote

- Video node state transitions (`buffering`, `playing`, `paused`, `error`)
  need an `error` path. A missing error observer means a black screen with no
  message on the TV.
- `onKeyEvent` must return `true` only for keys it actually handled.
  Returning `true` unconditionally swallows Back and traps the user.
- Deep links arrive through `roInput` and the launch args; treat both as
  untrusted strings.

## Certification

- Channels must respond to Back from every screen and exit cleanly from the
  root. Flag any new screen that cannot be backed out of.
- Do not log entitlement or account identifiers to the telnet console; those
  logs are readable on the device.
