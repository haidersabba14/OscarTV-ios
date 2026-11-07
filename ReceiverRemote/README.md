# Receiver Remote for iPhone

This companion app talks to the CleanYourTV launcher over the receiver's local Wi-Fi network. The TV-side launcher adds an **iPhone Remote** tile. Open it to view a six-digit pairing code, then pair from the iPhone app. The TV advertises `_ctvremote._tcp` with Bonjour, so the iPhone can find it automatically; an IP field is available as a fallback.

## First pairing

1. Install the updated CleanYourTV APK on the Android TV receiver and open **iPhone Remote** from the app grid.
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

## GitHub Actions and IPA signing

The **Build Receiver launcher APK** workflow builds the Android TV APK. The **Build Receiver Remote for iOS** workflow uses macOS 26 and Xcode to build an unsigned simulator app and an unsigned device IPA on every run. The unsigned IPA follows the packaging approach used by the earlier iOS GitHub project; it is not signed and cannot install directly until you sign it with a sideloading tool or an Apple certificate. It also exports a signed `Receiver-Remote.ipa` when all signing secrets below are configured:

- `IOS_CERTIFICATE_P12_BASE64`
- `IOS_CERTIFICATE_P12_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_TEAM_ID`
- optional `IOS_EXPORT_METHOD` (`ad-hoc` by default; use the distribution method matching the provisioning profile)

Both workflows can be started from **Actions → Run workflow**. The iOS workflow also runs when the `codex/receiver-remote-ipa` branch is pushed. Give a `release_tag` to attach the resulting files to a GitHub Release, or publish a Release to trigger both builders. The simulator ZIP is not an installable iPhone IPA.
