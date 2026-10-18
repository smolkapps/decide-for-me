# Worklog

## 2026-10-16 — Studio CI migration

Goal: preserve the paused release pipeline while moving future compute to the local Studio. Changed runner routing and hosted-image Xcode selection only; original signing/upload steps and triggers remain. The workflow remains disabled. YAML parsing passed; no signing, store upload or release was executed or credited as verified. Repository STUDIO_CI profile variables retain the original hosted label for rollback. Local release credentials and app-specific signing must be verified at an authorized future build.

## 2026-10-16 — Manual unsigned Flutter Studio compile

Add a separate manual compiler-only workflow retaining the release workflow's Flutter3.44.x stable pin, Java17, Xcode selection, disabled Swift Package Manager and dependency command. Reuse the persistent local Flutter SDK and retain cloud caching for hosted rollback. Compile iOS Release with `flutter build ios --release --no-codesign`.

Do not add the unrelated stale template test as a new CI gate: `test/widget_test.dart` references `MyApp` and a counter, while current `lib/main.dart` defines `DecideForMeApp` and no `MyApp`. The original release workflow never ran `flutter test`, so no prior CI test check is removed. App and test files remain unchanged; this compiler-only check earns no test or runtime acceptance credit.

The existing TestFlight workflow remains disabled and unchanged. This workflow does not install signing material, patch signing/app metadata, export, archive or upload. YAML, structural, Bash syntax and trailing-whitespace checks pass; no native build or test was executed during preparation. Actual compilation remains pending.

## 2026-10-16 — Select the compatible installed Studio toolchain

The actual unsigned run38991175942 failed because SDK27.1 rejects the existing iOS13 target. Studio already has native/universal Xcode26.2 at /Applications/Xcode-26.2.0.app; UID503 reads its actual Xcode17C52/SDK26.2 successfully, whose device deployment minimum is12.0. Select this toolchain in the Studio branch of both compile/release workflows, retaining hosted selection, Flutter/dependencies, app/test source and deployment targets. The release workflow stays disabled and is not dispatched. YAML/Bash and exact one-path-only comparisons pass. Rerun the manual compiler check only after this observed host-selection correction; no successful compilation is claimed yet.

## 2026-10-17 — Studio unsigned iOS compiler verified

Current-source run38991845553 (1147bee) completedSUCCESS on Studio, including all post-steps. Xcode26.2/17C52 compiled the actual unsigned Release Runner.app (15.7MB), with Xcode build125.1seconds. This verifies the compatible local toolchain selection, not tests, simulator runtime, signing or store delivery. The disabled release workflow was not dispatched.

Target wording clarification: committed project deployment target is12.0; pinned Flutter normally migrates the disposable build to effective13.0. Earlier app13 wording describes that effective build. No committed target or Flutter migration was changed. App/test/dependency sources remain unchanged.

## Studio distribution trigger

The iOS distribution workflow is now manual-only: removed only automatic push-main triggering. Existing workflow_dispatch, Studio routing/hosted rollback, toolchain selection, all checks, signing and binary-upload commands are unchanged. This source change does not enable/dispatch the workflow or claim signing/build/upload execution; existing disabled state remains until separately reviewed reactivation. Public submission/release authority is unchanged.


## Studio CI trigger preservation — October 18, 2026

Restore the original main-push TestFlight trigger using Studio compute. Automatic distribution requires STUDIO_CI_AUTO_TESTFLIGHT=true after existing candidate checks, signing/privacy readiness and app-owner coordination, and the exact Studio profile (or its absent-variable default). Hosted rollback and unset/false opt-in skip push distribution; manual dispatch retains the complete existing build/sign/validate/upload flow. All build, signing, upload and validation steps are unchanged. No workflow was dispatched and no new signed/uploaded build is claimed. Commit this restoration with [skip ci] to avoid running distribution for the routing change itself.
Repository-level STUDIO_CI_AUTO_TESTFLIGHT=false was explicitly set and read back before this source change, shadowing any uninspectable organization inheritance. Existing readiness checks are incomplete; the switch does not itself verify them.

