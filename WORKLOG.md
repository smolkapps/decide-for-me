# Worklog

## 2026-10-16 — Studio CI migration

Goal: preserve the paused release pipeline while moving future compute to the local Studio. Changed runner routing and hosted-image Xcode selection only; original signing/upload steps and triggers remain. The workflow remains disabled. YAML parsing passed; no signing, store upload or release was executed or credited as verified. Repository STUDIO_CI profile variables retain the original hosted label for rollback. Local release credentials and app-specific signing must be verified at an authorized future build.

## 2026-10-16 — Manual unsigned Flutter Studio compile

Add a separate manual compiler-only workflow retaining the release workflow's Flutter3.44.x stable pin, Java17, Xcode selection, disabled Swift Package Manager and dependency command. Reuse the persistent local Flutter SDK and retain cloud caching for hosted rollback. Compile iOS Release with `flutter build ios --release --no-codesign`.

Do not add the unrelated stale template test as a new CI gate: `test/widget_test.dart` references `MyApp` and a counter, while current `lib/main.dart` defines `DecideForMeApp` and no `MyApp`. The original release workflow never ran `flutter test`, so no prior CI test check is removed. App and test files remain unchanged; this compiler-only check earns no test or runtime acceptance credit.

The existing TestFlight workflow remains disabled and unchanged. This workflow does not install signing material, patch signing/app metadata, export, archive or upload. YAML, structural, Bash syntax and trailing-whitespace checks pass; no native build or test was executed during preparation. Actual compilation remains pending.
