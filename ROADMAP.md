# Tidings Roadmap

## Backend Representation (Server-First + Optional Local Files)

-   [x] Start with a mock provider as the MVP source of truth while online; never finalize state locally without server ack.
-   [x] Add IMAP provider after mock; keep server-first invariant unchanged.
-   [ ] Add Gmail provider, still server-first.
-   [ ] Choose local on-disk format for optional filesystem storage:
    -   [ ] Use Maildir (RFC 5322 raw message per file) with a metadata sidecar for UID/flags/account mapping; rationale: standard, CLI-editable, one-file-per-message, safe for concurrent updates.
    -   [ ] Specify folder layout for multi-account (per-account root with Maildir subfolders).
-   [ ] Document the server-first invariant and how caches are invalidated when online.

## Sync, Offline, and Queueing

-   [ ] Implement mock-provider sync with deterministic UID/UIDVALIDITY and flags to validate queue behavior.
-   [ ] Implement IMAP sync with UID/UIDVALIDITY tracking; prefer CONDSTORE/QRESYNC when available.
-   [ ] Implement Gmail sync layer after IMAP (provider adapter, server-first semantics).
-   [ ] Define local cache schema (SQLite or embedded KV) for headers, thread links, and message bodies.
-   [ ] Implement offline queue (append-only ops: send, move, flag, delete, draft update).
-   [ ] Replay queue on reconnect with conflict handling (server wins; local rebase if possible).
-   [ ] Add explicit "offline" UI state and queued-ops indicator.

## Core Email Features

-   [x] Multi-account setup flow (mock provider first, then IMAP/SMTP creds, then Gmail OAuth).
-   [ ] Unified inbox with per-account filtering and accent color mapping.
-   [x] Threading engine (RFC 5322 References/In-Reply-To; subject fallback).
-   [x] chat-style editor (threaded compose, inline reply, rich shortcuts).
-   [ ] reply to non-last message in thread.
-   [x] Send/Reply/Forward with correct headers and threading preservation.

## Testing

-   [x] Unit tests for mock provider sync logic (UID tracking, flags, offline replay).
-   [ ] Unit tests for IMAP sync logic (UID tracking, modseq, conflict handling).
-   [ ] Unit tests for Gmail provider adapter (label mapping, thread consistency).
-   [ ] Unit tests for offline queue replay (ordering, idempotency).
-   [ ] Unit tests for threading parser.
-   [ ] Golden UI tests for key layouts (light/dark, account accents).
-   [ ] Integration test for send/reply flow with a test IMAP server.
-   [ ] Integration test for Gmail send/reply flow (mocked or sandboxed account).

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
