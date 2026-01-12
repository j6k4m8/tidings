# Tidings MVP Roadmap

## Bugs / Papercuts

-   [ ] make the settings icon always a gear in responsive mobile too
-   [ ] settings page switches should be refactored out into their own component, and should be styled with the accent color
-   [x] mobile: header (subject) is white on white. get rid of header and just put a back button on mobile in front of the subject in the thread box card title.
-   [ ] corner radius setting in settings, do the same thing as margins selector where it wraps to the next line if the screen is too narrow

## Product Definition

-   [ ] Define MVP scope (multi-account, threaded editor, keyboard-first UX, offline queue, server-first sync).
-   [ ] Identify top 3 email workflows to optimize (triage, reply, compose).
-   [ ] Lock brand direction: spotify-ish layout, strong typography, light/dark, accent by account ID.

## Backend Representation (Server-First + Optional Local Files)

-   [ ] Start with a mock provider as the MVP source of truth while online; never finalize state locally without server ack.
-   [ ] Add IMAP provider after mock; keep server-first invariant unchanged.
-   [ ] Add Gmail provider after IMAP (OAuth + Gmail API as needed), still server-first.
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

-   [ ] Multi-account setup flow (mock provider first, then IMAP/SMTP creds, then Gmail OAuth).
-   [ ] Unified inbox with per-account filtering and accent color mapping.
-   [ ] Threading engine (RFC 5322 References/In-Reply-To; subject fallback).
-   [ ] Superhuman-style editor (threaded compose, inline reply, rich shortcuts).
-   [ ] Send/Reply/Forward with correct headers and threading preservation.

## UI/UX (Spotify-ish)

-   [ ] Define type scale and font pairing; integrate into theme system.
-   [ ] Create dark/light themes with shared spacing and component tokens.
-   [ ] Accent color per account ID (deterministic mapping, accessible contrast).
-   [ ] Design main layout: left nav, message list, thread view, compose panel.
-   [ ] Implement keyboard navigation + discoverable shortcut overlay.

## Data Model and API

-   [ ] Define message model (raw RFC 5322, parsed headers, body parts, flags).
-   [ ] Define thread model and caching strategy.
-   [ ] Define account + mailbox models (capabilities, folder mappings).
-   [ ] Create backend interface for:
    -   [ ] Fetching messages/threads (mock first, then IMAP, then Gmail).
    -   [ ] Sending messages (mock first, then IMAP/SMTP, then Gmail).
    -   [ ] Flag/move/delete operations (mock first, then IMAP, then Gmail).
    -   [ ] Queueing offline operations.
    -   [ ] Optional filesystem sync (Maildir read/write).

## Testing

-   [ ] Unit tests for mock provider sync logic (UID tracking, flags, offline replay).
-   [ ] Unit tests for IMAP sync logic (UID tracking, modseq, conflict handling).
-   [ ] Unit tests for Gmail provider adapter (label mapping, thread consistency).
-   [ ] Unit tests for offline queue replay (ordering, idempotency).
-   [ ] Unit tests for threading parser.
-   [ ] Golden UI tests for key layouts (light/dark, account accents).
-   [ ] Integration test for send/reply flow with a test IMAP server.
-   [ ] Integration test for Gmail send/reply flow (mocked or sandboxed account).

## Docs

-   [ ] Architecture overview: server-first sync, offline queue, Maildir optional storage.
-   [ ] Developer setup guide (mock provider first, then IMAP test server, then Gmail OAuth setup).
-   [ ] Shortcut reference for keyboard-first workflows.
-   [ ] Theming guide (tokens, typography, accent mapping).

## Backlog

-   [ ] Persist UI settings (theme mode, palette source, layout density, corner radius).
-   [ ] Add font choices UI and wire font assets into the build.

## MVP Release Checklist

-   [ ] Performance targets (initial sync time, search latency, UI responsiveness).
-   [ ] Crash/error reporting strategy with privacy guidelines.
-   [ ] Accessibility audit (contrast, keyboard-only, focus states).
-   [ ] Beta distribution plan and feedback loop.
