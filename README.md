<h1 align=center>
<img src="./docs/tidings.svg" height=200 />
</h1>
<p align="center">
  Tidings is a pretty, FOSS native email client for IMAP/SMTP and Gmail.
</p>
<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS-333333?style=for-the-badge&logo=apple&logoColor=white" alt="macOS Platform"/> &nbsp;
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android Platform"/> &nbsp;
  <img src="https://img.shields.io/badge/Platform-iOS-000000?style=for-the-badge&logo=ios&logoColor=white" alt="iOS Platform"/> &nbsp;
  <img src="https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux Platform"/> &nbsp;
  <br />
  <img alt="GitHub Downloads (all assets, all releases)" src="https://img.shields.io/github/downloads/j6k4m8/tidings/total?style=for-the-badge&logo=github"> &nbsp;
  <img src="https://img.shields.io/badge/Framework-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter Framework"/>&nbsp;
</p>

<img width="1236" height="935" alt="Image" src="https://github.com/user-attachments/assets/a5482344-63ad-4df9-aa03-e8e20c47838a" />

More screenshots in [docs/Screenshots.md](docs/Screenshots.md)!

> [!WARNING]
>
> This project is in development. **While you CAN use it as an email client today,** expect bugs and missing features... maybe don't use it for important messages yet! Seeking motivated folks to contribute and play-test!

## Current Features

-   **Multi-account** support, with **unified inbox**
-   **Message threading** with "chat-style" UI to make inbox zero easy
-   **Undo-send**
-   **Really smart search** with cool stuff like `from:[sender] AND (before:2y OR after:2025)` and saving searches, w0w0w
-   **Per-account accent colors** so you always know which account you're in, great for keeping business and personal separate
-   **KEYBOARD SHORTCUTS KEYBOARD SHORTCUTS KEYBOARD SHORTCUTS!!** (See [docs/Keyboard.md](docs/Keyboard.md) for all the shortcuts, or hit <kbd>?kbd>)

## Plus the obvious features:

-   HTML message rendering
-   Rich HTML compose with styling and saved drafts
-   Outbox send queue with instant-send
-   Automatic send retries with exponential backoff + fallback to Drafts
-   IMAP/SMTP connection testing and per-account refresh intervals
-   Folder pinning with background cached folder loading
-   Responsive layout for desktop and mobile with folder navigation
-   Configurable appearance settings (theme, palette, density, corner radius, threads)

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features.

## Why

As far as I can tell, there are three types of email clients available today:

-   **Vendorlocked web apps (Gmail, Outlook.com)**. Ads. Tracking. Vendor lock-in. No offline access. No thanks.
-   **FOSS but ugly native clients (Thunderbird, etc.)**. Archaic looks, atrocious UX. No thanks.
-   **Expensive gross AI clients (Superhuman, etc.)**. Subscription fees to your own email. No thanks.

So that's three _no-thankses_ and zero _yes-thankses_. Tidings aims to be a fourth option: FOSS, native, beautiful, no sucky subscription fees.

---

# Features

## Search

<img width="691" height="259" alt="Image" src="https://github.com/user-attachments/assets/fbda4757-31f2-40b0-bd87-e7d5fefc464e" />

You can compose search queries and save them for later use. Open search with <kbd>⌘F</kbd> / <kbd>Ctrl+F</kbd>. Queries support boolean operators, field filters, and natural-language dates — and are sent to the server (Gmail or IMAP) so results aren't limited to what's already cached.

### Query syntax

#### Boolean operators

Adjacent terms are implicitly AND'd. Operators are case-insensitive.

| Operator     | Example                                  | Meaning                      |
| ------------ | ---------------------------------------- | ---------------------------- |
| _(implicit)_ | `from:alice subject:invoice`             | Both conditions must match   |
| `AND`        | `from:alice AND subject:invoice`         | Explicit AND (same as above) |
| `OR`         | `from:alice OR from:bob`                 | Either condition matches     |
| `NOT`        | `NOT from:spam@example.com`              | Condition must not match     |
| `(` `)`      | `(from:alice OR from:bob) AND is:unread` | Group sub-expressions        |

Precedence (high → low): `NOT` > `AND` > `OR`, consistent with standard boolean logic.

#### Field filters

| Field      | Example                   | Matches                                          |
| ---------- | ------------------------- | ------------------------------------------------ |
| `from:`    | `from:jordan`             | Sender name or email contains value              |
| `to:`      | `to:jordan@example.com`   | Recipient name or email contains value           |
| `cc:`      | `cc:alice`                | CC'd address name or email contains value        |
| `bcc:`     | `bcc:bob`                 | BCC'd address name or email contains value       |
| `subject:` | `subject:"meeting notes"` | Subject contains value (quote multi-word values) |
| `label:`   | `label:important`         | Same as `subject:` on IMAP; label name on Gmail  |
| `in:`      | `in:inbox`, `in:sent`     | Folder path contains value                       |
| `is:`      | `is:unread`               | Message flag or state (see below)                |
| `has:`     | `has:link`                | Message feature (see below)                      |
| `before:`  | `before:2024-01-01`       | Received before date (exclusive)                 |
| `after:`   | `after:last month`        | Received after date (exclusive)                  |
| `date:`    | `date:today`              | Received on this exact date                      |
| `account:` | `account:gmail.com`       | From a matching account (client-side only)       |

All field values are case-insensitive substring matches, so `from:jor` matches `jordan@example.com`. Wrap multi-word values in quotes: `subject:"cool video"`.

#### `is:` values

| Value               | Matches                   |
| ------------------- | ------------------------- |
| `is:unread`         | Unread threads            |
| `is:read`           | Read threads              |
| `is:starred`        | Starred / flagged threads |
| `is:unstarred`      | Not starred               |
| `is:me` / `is:sent` | Sent by you               |

#### `has:` values

| Value            | Matches                                 |
| ---------------- | --------------------------------------- |
| `has:link`       | Body contains a URL                     |
| `has:attachment` | Has attachments _(not yet implemented)_ |

#### Date formats

All three date fields (`before:`, `after:`, `date:`) accept the same formats:

| Format            | Example                                | Meaning             |
| ----------------- | -------------------------------------- | ------------------- |
| Natural language  | `today`, `yesterday`                   | Today / yesterday   |
| Week/month/year   | `last week`, `this month`, `last year` | Start of the period |
| Relative — days   | `1d`, `7d`                             | N days ago          |
| Relative — weeks  | `1w`, `4w`                             | N weeks ago         |
| Relative — months | `1mo`, `3mo`, `6mo`                    | N months ago        |
| Relative — years  | `1y`, `2y`                             | N years ago         |
| ISO 8601          | `2025-02-21`                           | Exact date          |

#### Free-text search

Any term without a `field:` prefix is matched against the subject, all participant names/emails, and the message body.

### Example queries

```
# Unread mail from a specific person
from:jordan is:unread

# Anything with an invoice in the last six months
subject:invoice after:6mo

# From Alice or Bob, not in Spam
(from:alice OR from:bob) NOT in:spam

# Starred messages you sent before 2024
is:starred is:me before:2024-01-01

# Long-form: mail from a domain with an attachment-like subject
from:@acme.com subject:"Q4 report"
```
