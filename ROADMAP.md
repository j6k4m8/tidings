# Tidings Roadmap

## Deep Review Remediation

### Critical

-   [x] [CRITICAL] Harden Gmail raw MIME generation in `GmailEmailProvider`.
    -   Current risk: Gmail sends/drafts interpolate raw `From`, `To`, `Cc`, `Bcc`, `In-Reply-To`, and `References` headers directly from user-controlled or remote-controlled strings.
    -   Fixed: Gmail sends/drafts now use a centralized MIME builder that rejects CRLF/control characters in structured headers, validates send recipients before queueing, documents Gmail Bcc routing semantics, and has regression tests.

### High

-   [ ] [HIGH] Add email-client privacy controls to HTML message rendering.
    -   Current risk: the regex sanitizer only strips scripts and quoted event handlers, still allows remote-capable media/frames, and URI launch handling is too permissive.
    -   Fix target: block remote loads by default, restrict supported URI schemes, remove dangerous elements/attributes with a parser-backed sanitizer, and add a per-message "load remote content" affordance.
-   [ ] [HIGH] Replace QR account transfer payloads that expose IMAP passwords in base64/plain text.
    -   Current risk: QR transfer serializes credentials in recoverable form.
    -   Fix target: require an encrypted transfer format, explicit expiry, and clear UX around credential scope.
-   [ ] [HIGH] Remove the global `FlutterError` overflow suppression in `main.dart`.
    -   Current risk: real layout bugs can be hidden in production and during review.
    -   Fix target: fix offending layouts directly and keep framework errors visible.
-   [ ] [HIGH] Make IMAP account edits transactional.
    -   Current risk: editing an account persists the new config/provider before validation and can leave a broken account if validation fails.
    -   Fix target: validate first, then commit config/provider atomically, with rollback on failures.
-   [ ] [HIGH] Replace placeholder tests with meaningful coverage.
    -   Current risk: `test/widget_test.dart` only asserts `true`, so regressions in core flows are unprotected.
    -   Fix target: add focused tests for provider behavior, search parsing/evaluation, send queue semantics, and high-risk UI flows.

### Medium

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

### Low

-   [ ] [LOW] Reduce duplicated provider and thread UI implementations.
    -   Current risk: large parallel implementations in IMAP/Gmail providers and home/thread views are likely to drift.

## Backend Representation (Server-First + Optional Local Files)

-   [x] Start with a mock provider as the MVP source of truth while online; never finalize state locally without server ack.
-   [x] Add IMAP provider after mock; keep server-first invariant unchanged.
-   [x] Add Gmail provider, still server-first.
-   [ ] Choose local on-disk format for optional filesystem storage:
    -   [ ] Use Maildir (RFC 5322 raw message per file) with a metadata sidecar for UID/flags/account mapping; rationale: standard, CLI-editable, one-file-per-message, safe for concurrent updates.
    -   [ ] Specify folder layout for multi-account (per-account root with Maildir subfolders).
-   [ ] Document the server-first invariant and how caches are invalidated when online.

## Sync, Offline, and Queueing

-   [x] Implement mock-provider sync with deterministic UID/UIDVALIDITY and flags to validate queue behavior.
-   [x] Implement IMAP sync with UID/UIDVALIDITY tracking; prefer CONDSTORE/QRESYNC when available.
-   [x] Implement Gmail sync layer after IMAP (provider adapter, server-first semantics).
-   [ ] Define local cache schema (SQLite or embedded KV) for headers, thread links, and message bodies.
-   [ ] Implement offline queue (append-only ops: send, move, flag, delete, draft update).
-   [ ] Replay queue on reconnect with conflict handling (server wins; local rebase if possible).
-   [ ] Add explicit "offline" UI state and queued-ops indicator.

## Core Email Features

-   [x] Multi-account setup flow (mock provider first, then IMAP/SMTP creds, then Gmail OAuth).
-   [x] Unified inbox with per-account filtering and accent color mapping.
-   [x] Threading engine (RFC 5322 References/In-Reply-To; subject fallback).
-   [x] chat-style editor (threaded compose, inline reply, rich shortcuts).
-   [ ] reply to non-last message in thread.
-   [x] Send/Reply/Forward with correct headers and threading preservation.

## Undo for Archive / Move

-   [ ] 5-second undo snackbar after archive or move-to-folder.

IMAP has no native undo — an "undo" is simply a second `UID MOVE` in reverse, back to the original folder. This means:

-   The source folder path and the moved UIDs must be captured at action time and held for the undo window.
-   The move fires immediately on the server; the undo window is a grace period to trigger a reverse move, not a delayed commit. A concurrent client could act on the message during those 5 seconds.
-   The optimistic UI (thread removed from cache immediately, `_lastMutationAt` blocking background refreshes from resurrecting it) must be mirrored for the undo: re-inserting the thread locally requires a symmetric `_reinsertThreadIntoCache` path and another `_lastMutationAt` bump, otherwise the next background fetch wipes the re-insertion before the reverse IMAP move completes.
-   If the reverse move fails (network drop, UID no longer valid), the local re-insertion must be rolled back and an error shown — otherwise the UI shows a thread that doesn't exist on the server.
-   Stacking undos (archive A, then archive B before A's window expires) requires a policy decision; simplest is one undo slot at a time, with a new action cancelling the previous opportunity.

## Backlog

-   [x] Persist UI settings (theme mode, palette source, layout density, corner radius).
-   [ ] Add font choices UI and wire font assets into the build.

## MVP Release Checklist

-   [ ] Crash/error reporting strategy with privacy guidelines
-   [ ] Accessibility audit (contrast, keyboard-only, focus states)
