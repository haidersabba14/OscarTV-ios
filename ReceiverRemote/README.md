# Receiver Remote for iPhone

This ivory, charcoal and champagne iPhone app talks to a compatible CleanYourTV receiver service over Wi-Fi. It discovers `_ctvremote._tcp` with Bonjour and also accepts a manual IP address. The receiver service must already be installed; this iOS repository branch contains the phone app and its build workflow, not the Android receiver update.

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



## Redesigned interface

The Control tab contains the circular direction dial, OK, Home, Back, volume, mute, wake and Android power-menu controls. The number keypad and its tab have been removed. The More tab contains haptic feedback, keeping the screen awake while actively controlling a paired receiver, shortcut customization, and a connection check with response timing. The Connection tab contains refresh, device information and unpairing. Bonjour discovery, manual IP entry, six-digit pairing, bearer-token handling and Keychain storage retain their existing implementations. The direction dial uses fixed physical positions independent of Arabic text layout.

As requested, the Settings button now targets IPTV Smarters Pro on the Android receiver. This requires an updated receiver service; see [the receiver integration contract](IPTV-Receiver-Integration.md). Older services display a clear update requirement. The phone does not claim to launch the receiver app without server support.

The full-redesign branch builds an unsigned IPA. The separately bounded Intel simulator review tests physical direction taps, command bindings, capability gates, pairing access and the legacy-receiver IPTV requirement. Simulator fixture switches are compiled only into Debug simulator builds. The distributed Release build has no fixture state or command interception. The user's icon and suggested receiver IP are applied locally when preparing the delivered IPA.


## Version 1.2 controls

Three persistent shortcuts are selected from commands supported by the paired receiver. Choosing an already selected shortcut swaps its position instead of creating a duplicate. Unknown stored command names are discarded. Volume buttons send once on touch and repeat while held, with one request in flight per hold. Release, dragging away, losing the active scene, a disabled capability or a failed receiver response stops future repeats. Releasing does not abort a request already sent.

Haptics and the keep-awake preference persist locally. Keep-awake only applies while the paired app is active, and is reset on backgrounding, unpairing, leaving the view or disabling the preference. Connection diagnostics reuse `/v1/info`; no new server endpoint is required. The existing IPTV launch capability guard is unchanged.

`swift test --package-path Core` runs the interaction and shortcut tests on the macOS build host without requiring an iOS Simulator. The IPA workflow also compiles the simulator app and UI tests. Simulator execution is a separate manual review because startup was unavailable in this environment; compile success is not a claim that UI tests ran.
