## NO-64: is there a connection? ASKED OF THE PHONE, not learned from a failed
## request or a ping (Max's ruling, 2026-09-13 — chosen knowing it means native
## code that only a device can verify).
##
## Godot 4.7 has no such API. What each platform offers instead:
## - ANDROID: no plugin. JavaClassWrapper + the AndroidRuntime singleton (both
##   shipped in 4.7) reach ConnectivityManager directly. Needs
##   ACCESS_NETWORK_STATE, set in export_presets.cfg.
## - iOS: the vendored `Connectivity` plugin (game/ios/plugins/src/connectivity),
##   an NWPathMonitor whose latest verdict this reads.
##
## POLLED BY THE CALLER, not subscribed. Android's push callbacks
## (NetworkCallback, BroadcastReceiver) are abstract classes, and
## JavaClassWrapper.create_proxy can only implement interfaces — so a real
## subscription there would need a Java plugin to save one cheap binder call a
## second. On iOS the native side already IS the subscription.
##
## FAILS OPEN. Anything that cannot answer — desktop, a missing plugin, a
## missing permission — reports online, which is exactly the behaviour before
## this existed: the controls stay live and fail per request as they always did.
## A control wrongly greyed is worse than one wrongly live.

## Tests set this to true/false to fake the state at the seam; null asks the platform.
static var override: Variant = null

static var _cm: Variant = null # Android ConnectivityManager, fetched once

## NetworkCapabilities.NET_CAPABILITY_VALIDATED: the OS has confirmed the
## network actually reaches the internet — false behind an unanswered captive
## portal, where INTERNET (12) alone would still say yes.
const _NET_CAPABILITY_VALIDATED := 16


static func online() -> bool:
	if override != null:
		return override
	match OS.get_name():
		"Android":
			return _android()
		"iOS":
			return not Engine.has_singleton("Connectivity") \
				or Engine.get_singleton("Connectivity").is_online()
	return true


static func _android() -> bool:
	if _cm == null:
		var rt := Engine.get_singleton("AndroidRuntime")
		var ctx = rt.getApplicationContext() if rt != null else null
		_cm = ctx.getSystemService("connectivity") if ctx != null else null
		if _cm == null:
			return true
	var net = _cm.getActiveNetwork()
	if net == null:
		# null is the answer "no network" — unless the call threw (no permission),
		# which is "cannot tell", and that fails open.
		return JavaClassWrapper.get_exception() != null
	var caps = _cm.getNetworkCapabilities(net)
	return caps != null and caps.hasCapability(_NET_CAPABILITY_VALIDATED)
