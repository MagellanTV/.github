# Platform checklist — Web

## Correctness

- `useEffect` dependency arrays that are wrong cause stale closures or infinite
  loops. Check every new effect.
- Async work started in a component must be cancelled or ignored on unmount
  (`AbortController`, a mounted flag, or the framework's own mechanism).
- Anything derived from `window`, `document` or `localStorage` breaks during
  SSR or prerender. Flag unguarded access in code that runs on the server.

## Security

- Any new `dangerouslySetInnerHTML`, `innerHTML`, or HTML built from API data
  is an XSS vector. Blocker unless the input is provably sanitized.
- URLs built from user input or deep-link parameters need validation before
  being used in a redirect.
- Secrets never belong in client-side code. Anything in a `NEXT_PUBLIC_` /
  `VITE_` variable is public by definition — flag credentials placed there.

## Performance and delivery

- New dependencies that ship to the client need a reason. Note bundle impact
  for anything large added to a critical path.
- Images without dimensions, and lists rendered without keys or windowing,
  are the usual layout-shift and jank sources.

## Accessibility

- Interactive elements built from `div`/`span` need a role, a tab index and
  keyboard handlers, or they should be a `button`/`a`.
- New form inputs need labels.
