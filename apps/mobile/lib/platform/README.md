# Platform differences live here, and only here

iOS is deferred, not abandoned (Q-BUILD, `docs/v3/09_OPEN_QUESTIONS.md` C-3). The
risk of "later" is that Android-only assumptions get baked in silently, so the
mitigation is structural rather than scheduled:

- No `Platform.isAndroid` / `Platform.isIOS` branch may appear anywhere in
  `apps/mobile/lib/` **except** this folder. `tools/lint` rule
  `PLATFORM-BRANCH-CONFINED` fails the build otherwise.
- Every platform difference sits behind one interface, in one place, and is
  therefore **countable** on the day iOS resumes — which is the whole point. A
  difference you cannot count is a port you cannot estimate.
- No Android-only package without a stated iOS equivalent in the same PR.
