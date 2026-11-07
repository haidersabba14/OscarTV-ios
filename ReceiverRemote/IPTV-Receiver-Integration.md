# IPTV Smarters Pro receiver integration

The redesigned iPhone Settings button now requests IPTV Smarters Pro on the **Android receiver**, as requested. It never opens an iPhone URL or the old Android settings action.

A receiver implementation is still required. The existing iOS source does not include that Android service, and the supplied private LAN IP was unreachable from the build environment. No receiver APK has been changed or tested.

The client extension is deliberately gated: `/v1/info` or `/v1/pair` must advertise `capabilities.openIPTVSmarters: true`. Only then does the client send the existing authenticated `/v1/command` envelope with `action: OPEN_IPTV_SMARTERS_PRO`. Older receivers keep their existing capabilities and receive no unknown launch command. The phone instead displays an update requirement.

When the receiver source/APK is available, its authenticated command dispatcher must implement this action using Android PackageManager launch/leanback intents for the **installed** IPTV Smarters Pro package. Common editions have different package IDs; the receiver must discover or verify the installed package instead of assuming one. Declare package visibility as needed, launch with `FLAG_ACTIVITY_NEW_TASK`, report app-not-installed distinctly, and advertise this capability only when supported. Keep all existing pairing, token checks and accessibility commands intact.
