# tidings

Tidings is a native, not-ugly email client for IMAP/SMTP servers, built using Flutter. (Gmail, Exchange, and JMAP are on the roadmap!)

<img width="1292" height="1016" alt="image" src="https://github.com/user-attachments/assets/9d27db7e-78c5-4789-ab28-1571f542a950" />

More screenshots in [docs/Screenshots.md](docs/Screenshots.md)!

> [!WARNING]
>
> This project is in early development. Expect bugs, crashes, and missing features, maybe don't use it for important messages yet! I'd love your feedback, issues, and contributions in the meantime :)

## Features

-   IMAP account onboarding with multi-account support
-   Mock inbox for exploring the UI without a server
-   Threaded inbox + thread detail view with HTML rendering
-   Rich HTML compose with inline replies and draft saving
-   IMAP/SMTP connection testing and per-account refresh intervals
-   Folder pinning with background cached folder loading
-   Per-account accent colors and glass UI styling
-   Responsive layout for desktop and mobile with folder navigation
-   Appearance settings (theme, palette, density, corner radius, threads)

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features.

## Why

As far as I can tell, there are three types of email clients available today:

-   **Vendorlocked web apps (Gmail, Outlook.com)**. Ads. Tracking. Vendor lock-in. No offline access. No thanks.
-   **FOSS hideous native clients (Thunderbird, etc.)**. Ugly, archaic looks, atrocious UX. No thanks.
-   **Expensive gross AI clients (Superhuman, etc.)**. Subscription fees to your own email. No thanks.

So that's three _no-thankses_ and zero _yes-thankses_. Tidings aims to be a fourth option: FOSS, native, beautiful, no sucky subscription fees.
