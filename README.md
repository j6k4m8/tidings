# tidings

Tidings is a native, not-ugly email client for IMAP/SMTP servers, built using Flutter. (Gmail, Exchange, and JMAP are on the roadmap!)

<img width="1236" height="935" alt="Image" src="https://github.com/user-attachments/assets/a5482344-63ad-4df9-aa03-e8e20c47838a" />

More screenshots in [docs/Screenshots.md](docs/Screenshots.md)!

> [!WARNING]
>
> This project is in early development. Expect bugs, crashes, and missing features, maybe don't use it for important messages yet! I'd love your feedback, issues, and contributions in the meantime :)

## Features

-   Multi-account support
-   IMAP account support, with onboarding wizard
-   Threaded inbox + thread detail view, with "chat-style" UX
-   HTML message rendering
-   Rich HTML compose with styling and saved drafts
-   Outbox send queue with instant-send UX (optimistic threading)
-   Undo send (click to undo during the send window)
-   Automatic send retries with exponential backoff + fallback to Drafts
-   IMAP/SMTP connection testing and per-account refresh intervals
-   Folder pinning with background cached folder loading
-   Per-account accent colors
-   Responsive layout for desktop and mobile with folder navigation
-   Configurable appearance settings (theme, palette, density, corner radius, threads)
-   **KEYBOARD SHORTCUTS KEYBOARD SHORTCUTS KEYBOARD SHORTCUTS**

See [Keyboard](docs/Keyboard.md) for all the shortcuts.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features.

## Why

As far as I can tell, there are three types of email clients available today:

-   **Vendorlocked web apps (Gmail, Outlook.com)**. Ads. Tracking. Vendor lock-in. No offline access. No thanks.
-   **FOSS hideous native clients (Thunderbird, etc.)**. Ugly, archaic looks, atrocious UX. No thanks.
-   **Expensive gross AI clients (Superhuman, etc.)**. Subscription fees to your own email. No thanks.

So that's three _no-thankses_ and zero _yes-thankses_. Tidings aims to be a fourth option: FOSS, native, beautiful, no sucky subscription fees.
