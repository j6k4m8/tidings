<h1 align=center>Tidings</h1>
<p align="center">
  Tidings is a native, not-ugly email client for IMAP/SMTP servers, built using Flutter. (Gmail, Exchange, and JMAP are on the roadmap!)
</p>
<p align="center">
  <!-- <img src="https://img.shields.io/badge/Platform-macOS-333333?style=for-the-badge&logo=apple&logoColor=white" alt="macOS Platform"/> &nbsp;
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android Platform"/> &nbsp;
  <img src="https://img.shields.io/badge/Platform-iOS-000000?style=for-the-badge&logo=ios&logoColor=white" alt="iOS Platform"/> &nbsp;
  <img src="https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux Platform"/> &nbsp; -->
  <br />
  <img alt="GitHub Downloads (all assets, all releases)" src="https://img.shields.io/github/downloads/j6k4m8/tidings/total?style=for-the-badge&logo=github"> &nbsp;
  <img src="https://img.shields.io/badge/Framework-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter Framework"/>&nbsp;
</p>


<img width="1236" height="935" alt="Image" src="https://github.com/user-attachments/assets/a5482344-63ad-4df9-aa03-e8e20c47838a" />

More screenshots in [docs/Screenshots.md](docs/Screenshots.md)!

> [!WARNING]
>
> This project is in early development. Expect bugs, crashes, and missing features, maybe don't use it for important messages yet! Seeking motivated folks to contribute and play-test!

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
