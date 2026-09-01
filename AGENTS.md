# Receipt Scanner Development Guidelines

## Project Principles

- Keep changes small, focused, and directly related to the requested behavior.
- Prefer robust, language-independent receipt handling over retailer-specific or language-specific rules.
- Keep receipt images and OCR processing on-device. Do not add cloud processing without an explicit user request and clear privacy documentation.
- Preserve legitimate repeated purchased items. Remove text only when a multi-line sequence at adjacent photo boundaries proves it is an OCR overlap.
- Do not silently discard uncertain receipt data. Prefer displaying a candidate for user review over making an unsupported assumption.
- Do not add backward-compatibility code unless persisted data or an external consumer requires it.

## Flutter and Dart

- Target idiomatic, null-safe Dart and use `dart format` after code changes.
- Keep `main.dart` limited to application startup, theme, and routing configuration.
- Separate concerns into focused files:
  - `lib/models/` for immutable domain data.
  - `lib/services/` for OCR, parsing, image processing, storage, and platform integrations.
  - `lib/pages/` for screens and screen-local state.
  - Add `lib/widgets/` only for reusable UI components used by multiple pages.
- Keep widgets small. Extract a widget when it has a distinct responsibility or is reused; do not extract trivial one-off fragments unnecessarily.
- Use `const` constructors and widgets wherever possible.
- Avoid `dynamic`, unchecked casts, global mutable state, and business logic embedded in widget build methods.
- Dispose controllers, recognizers, streams, and other resources in all success and error paths.
- Guard asynchronous UI updates with `mounted` after `await` before calling `setState`, navigating, or showing UI feedback.
- Prefer clear domain names over abbreviations. Private implementation details start with `_`.
- Use ASCII when editing source files unless the domain data requires Unicode.

## Receipt Processing

- Retain ML Kit OCR bounding boxes and process receipt content in visual reading order.
- Model receipt data structurally (`ReceiptLine`, `ReceiptItem`, `ReceiptSegment`) instead of passing raw text through the app.
- Infer products through layout and numerical structures, such as a description aligned with a price, rather than words from a specific language.
- Support currency symbols and ISO currency codes without treating any specific currency as mandatory.
- Treat totals, taxes, discounts, deposits, and payment lines as separate candidates. Only classify or remove them when the numerical and positional evidence is sufficient.
- Keep parser logic deterministic and independently testable; UI code must not parse OCR strings itself.
- For receipt image stitching, detect overlap from image content. Never use a fixed percentage crop as the primary join strategy.
- Account for orientation, differing capture widths, and small horizontal offsets. If an overlap match is unreliable, preserve image content instead of cutting text away.

## UI and Accessibility

- Respect system light and dark mode using Material 3 and the established teal theme.
- Make primary actions clear and keep destructive actions distinct.
- Ensure layouts remain usable on narrow mobile screens and large desktop windows.
- Use readable labels, semantic icons, adequate touch target sizes, and text that explains recovery from failures.
- Show actionable errors. Do not replace a useful platform or OCR exception with an unexplained generic message during diagnosis.

## Android and Dependencies

- Keep Android permissions minimal and document why each permission is needed.
- Do not commit signing files, keystores, generated build outputs, or secrets.
- Update dependencies deliberately. Check changelogs for Android, ML Kit, Kotlin, and Flutter compatibility before upgrades.
- Keep release shrinking rules narrowly scoped unless a plugin requires broader rules that are documented and verified.

## Verification and Git

- Run `dart format` on changed Dart files and `git diff --check` before declaring code complete.
- Run `flutter analyze` and the relevant tests when the user permits builds/tests. Do not run builds or tests when the user explicitly asks not to.
- For Android release changes, use `./build.sh apks1` when a signed ARM64 split APK is requested.
- Inspect `git status`, `git diff`, and recent commits before committing.
- Never commit secrets, signing configuration, or unrelated user changes.
- Use concise imperative commit messages that describe the completed change.
