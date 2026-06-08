# Tidings Roadmap

Unfinished work only. Shipped user-facing capabilities live in [Features.md](Features.md).

## Critical

-   [ ] No active critical items.

## High

-   [ ] [HIGH] Make IMAP account edits transactional.
    -   Current risk: editing an account persists the new config/provider before validation and can leave a broken account if validation fails.
    -   Fix target: validate first, then commit config/provider atomically, with rollback on failures.
-   [ ] [HIGH] Replace placeholder tests with meaningful coverage.
    -   Current risk: `test/widget_test.dart` only asserts `true`, so regressions in core flows are unprotected.
    -   Fix target: add focused tests for provider behavior, search parsing/evaluation, send queue semantics, and high-risk UI flows.
-   [ ] [HIGH] Add a crash/error reporting strategy with privacy guidelines.
-   [ ] [HIGH] Run an accessibility audit across contrast, keyboard-only workflows, and focus states.

## Medium

-   [ ] [MEDIUM] Apply persisted Gmail settings during startup.
    -   Current risk: parsed Gmail config is not passed into the provider, so refresh interval defaults to 5 minutes after restart.
-   [ ] [MEDIUM] Fix Gmail outbox edge cases.
    -   Current risk: provider status does not special-case outbox selection and message IDs diverge from undo/detail expectations.
-   [ ] [MEDIUM] Complete starred/flagged mail support.
    -   Current risk: the model/search UI advertises starred behavior, but the thread detail star button is effectively a no-op and providers lack a mutation API.
-   [ ] [MEDIUM] Either implement attachment search or remove the advertised/stubbed syntax.
    -   Current risk: README/search suggestions imply attachment filtering, but query evaluation/serialization do not implement it.
-   [ ] [MEDIUM] Clean up release-readiness scaffold leftovers.
    -   Current risk: Android release signing still falls back to debug keys and `pubspec.yaml` keeps the default Flutter description.
-   [ ] [MEDIUM] Define a local cache schema for headers, thread links, and message bodies.
-   [ ] [MEDIUM] Implement an offline operation queue for send, move, flag, delete, and draft updates.
-   [ ] [MEDIUM] Replay queued offline operations on reconnect with conflict handling.
-   [ ] [MEDIUM] Add explicit offline UI state and a queued-operations indicator.
-   [ ] [MEDIUM] Add a 5-second undo snackbar after archive or move-to-folder.
    -   Undo should issue the reverse server move, reinsert the thread locally, roll back on failure, and define a policy for stacked undo windows.
-   [ ] [MEDIUM] Support replying to a non-latest message in a thread.
-   [ ] [MEDIUM] Add font choices UI and wire font assets into the build.

## Low

-   [ ] [LOW] Choose and document an optional local on-disk mail format.
    -   Candidate: Maildir with metadata sidecars for UID/flags/account mapping and per-account roots.
-   [ ] [LOW] Document the server-first invariant and how caches are invalidated when online.
-   [ ] [LOW] Reduce duplicated provider and thread UI implementations.
