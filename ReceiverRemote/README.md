# Receiver Remote for iPhone

This black-and-gold iPhone app talks to a compatible CleanYourTV receiver service over Wi-Fi. It discovers `_ctvremote._tcp` with Bonjour and also accepts a manual IP address. The receiver service must already be installed; this iOS repository branch contains the phone app and its build workflow, not the Android receiver update.

## First pairing

1. Install a CleanYourTV receiver build that advertises `_ctvremote._tcp` on port `8765`, then open **iPhone Remote** on the TV to display its six-digit code.
2. On the TV, choose **Open accessibility settings** and enable **Remote Accessibility**. This is an Android-controlled permission and must be approved on the receiver.
3. Install and open **Receiver Remote** on an iPhone connected to the same trusted Wi-Fi network. Allow Local Network access if iOS asks.
4. Select the discovered CleanYourTV device, enter the six-digit TV code, and tap **Pair**.

Pairing issues a bearer token stored in the iOS Keychain. The endpoint is local-only and pairing codes expire after ten minutes; five failed code attempts temporarily pause pairing for one minute. The HTTP control channel is not encrypted, so do not use it on an untrusted shared network. Use **Unpair / new code** on the TV to revoke the current token.

## Controls this Android launcher can provide

- Accessibility-enabled navigation and OK use Android's accessibility focus and click APIs. Some apps do not expose focusable controls; those apps may not respond like they would to a hardware remote.
- Home, Back, Settings, and the Android power menu use system accessibility actions.
- Volume and mute use Android AudioManager. Wake can wake a receiver that is still in networked standby.
- Number keys enter digits only in an editable field exposed by Accessibility.

The launcher is an Android home app, not receiver firmware. Android has no general third-party API to inject D-pad/channel key events, tune an unknown vendor's channels, shut down arbitrary hardware, or power it on after Wi-Fi has shut down. Channel controls remain disabled for this build; the power control opens Android's power menu, and wake only works if the receiver keeps networking during standby. A genuine channel/power implementation needs the receiver vendor's control API, a supported TV-input service, or privileged/system firmware integration.

## GitHub Actions and IPA installation

The `Build Receiver Remote IPA` workflow runs on pushes to `codex/receiver-remote-ipa` and can also be started from **Actions → Run workflow**. It creates an unsigned `Receiver-Remote.ipa` and uploads it as the `Receiver-Remote-IPA` artifact. Download the artifact ZIP from the workflow run and extract the IPA. As in the earlier iOS project, the IPA is unsigned; sign it with Sideloadly or an Apple certificate before installing it on an iPhone.

