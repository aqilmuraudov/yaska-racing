class_name RewardedAds
extends RefCounted
## Single hook for future rewarded ads ("double reward", "bonus manat").
## No ad SDK is linked: `is_available()` is false, so the UI hides the
## offer. A future SDK plugs in here: show the ad, then call `on_done(true)`;
## the reward itself is granted by SaveManager.claim_ad_bonus (once per race).

static var provider: Callable = Callable() ## func(kind: String, on_done: Callable)


static func is_available() -> bool:
	return provider.is_valid()


static func show(kind: String, on_done: Callable) -> void:
	if not provider.is_valid():
		on_done.call(false)
		return
	provider.call(kind, on_done)
