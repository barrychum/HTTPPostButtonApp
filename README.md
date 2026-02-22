# QikPOST — HTTP POST Buttons for iOS

> One tap. One request. Done.

**QikPOST** is an iOS app that lets you create a collection of one-tap buttons, each firing a pre-configured HTTP POST request. Whether you're triggering a home automation webhook, calling an internal API, or sending a command to a remote service — QikPOST gets it done without opening a browser or writing a line of code.

---

## 📲 Download on the App Store

<a href="https://apps.apple.com/app/YOUR_APP_ID">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" height="50">
</a>

> ⚠️ *Replace the link above with your actual App Store URL once your app is live.*

---

## ✨ Features

### 🔘 Configurable Buttons
Create as many buttons as you need, each with its own URL, HTTP headers, and request body. Buttons can be colour-coded from a palette of 12 iOS system colours so you can tell them apart at a glance.

### 📄 Pages / Tabs
Organise your buttons into named pages, each with a custom SF Symbol icon and colour. Switch between pages from the navigation bar — ideal for grouping buttons by project, location, or service.

### 🔐 Security
- **Face ID / Touch ID** — optionally require biometric authentication before a button fires, keeping accidental or unauthorised taps in check
- **Confirmation prompt** — add a custom confirmation message that must be acknowledged before the request is sent

### 📬 Response Options
- **Show Response** — view the full HTTP response body and status code in a popup after sending
- **Auto-dismiss** — set a timeout (1–30 seconds) so the response popup closes itself automatically
- **Silent mode** — turn off Show Response for fire-and-forget buttons; a brief iOS banner notification confirms the tap instead

### 🔑 Secrets Manager
Store sensitive values (API keys, tokens, passwords) securely in the iOS Keychain. Reference them anywhere in your request body or headers using `{{KEY_NAME}}` placeholder syntax — secrets are never stored in plain text.

### 🕐 OTP / TOTP Support
Generate time-based one-time passwords (TOTP, RFC 6238) locally on-device, with no third-party dependency. Add `{{OTP}}` anywhere in your request body and QikPOST injects a fresh 6-digit code at send time. Supports Base32, hex, and plain-text secrets.

### 📱 iOS Shortcuts & Siri
Every button you create is automatically available as an action in the iOS Shortcuts app and via Siri. Trigger your requests from automations, widgets, or voice — biometric authentication and confirmation prompts are enforced even when called from Shortcuts.

### 🔔 Native Notifications
When a button is set to silent mode, QikPOST delivers a native iOS banner notification labelled with the button name so you always know the command registered — even when the app is in the foreground.

---

## 📸 Screenshots

> *Screenshots coming soon.*

---

## 🚀 How It Works

1. **Create a page** — give it a name and pick an icon from the SF Symbols library
2. **Add a button** — enter a URL, set your headers and JSON body
3. **Configure options** — choose a colour, enable OTP, add a confirmation prompt, or require Face ID
4. **Tap to send** — one tap fires the POST request; the response appears in a popup or as a notification

---

## 🔒 Privacy

QikPOST takes your privacy seriously:

- **No account required** — the app works entirely on-device with no sign-up
- **No analytics or tracking** — your button configurations, URLs, and secrets never leave your device
- **Keychain storage** — all secret values are stored in the iOS Keychain, not in plain text or iCloud
- **OTP generation** — TOTP codes are generated on-device; your secret keys are never transmitted

---

## 🛠 Requirements

| | |
|---|---|
| **Platform** | iOS 18.6 or later |
| **Device** | iPhone |
| **Biometrics** | Face ID or Touch ID (optional) |
| **Notifications** | Required for "Command sent" banner (optional feature) |

---

## 📬 Support & Feedback

Have a feature request or found a bug? Feedback is welcome via the App Store review page, or open an issue here on GitHub.

---

## 👤 About

QikPOST is independently developed by **Barry**.

---

*QikPOST is not affiliated with Apple Inc. App Store and Face ID are trademarks of Apple Inc.*
