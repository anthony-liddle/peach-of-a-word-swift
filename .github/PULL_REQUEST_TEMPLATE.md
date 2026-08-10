## What this changes

<!-- What it does and why. If it fixes something, describe the behaviour that
     was wrong, not only the fix. -->

## Type of change

- [ ] feat: new behaviour
- [ ] fix: a bug
- [ ] docs / chore / ci: no change to how the app behaves
- [ ] refactor: same behaviour, different shape

## Related issues

<!-- Closes #123, or "none". -->

## Testing

- [ ] `swift test` passes
- [ ] The app builds (`xcodegen generate` then `xcodebuild`)
- [ ] Ran it on a simulator or a device, if this touches the app

<!-- What you actually checked by hand, and on what. "Ran it" is not a test
     report; what did you look at and what did it do? -->

## Screenshots

<!-- Required for anything visual. A simulator capture is enough:
     xcrun simctl io booted screenshot shot.png -->

## Checklist

- [ ] Conventional Commits, and no em dashes anywhere including the commit body
- [ ] Project settings changed in `project.yml`, not in Xcode's UI, since the
      `.xcodeproj` is generated and not committed
- [ ] No debug code, no unused imports, no leftover files
- [ ] Any new user-facing string uses the cute vocabulary, not letterpress
      (`AppVocabularyTests` will catch this)
- [ ] The web repo at `anthony-liddle/peach-of-a-word` is untouched
