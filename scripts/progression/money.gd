class_name Money
extends RefCounted
## In-game currency: Azerbaijani manat (₼). 1 manat = 100 qəpik.
## Every amount is stored and passed around as an integer number of qəpik;
## only this class turns it into text (Azerbaijani format, comma decimal):
##   format(250)        -> "2,50 ₼"
##   format_delta(80)   -> "+80 qəpik"
##   format_delta(120)  -> "+1,20 ₼"

const SYMBOL := "₼"
const QEPIK_PER_MANAT := 100
## Save v2 → v3: one old "coin" becomes 2 qəpik (100 coins → 2,00 ₼). Chosen
## so an old 1st-place payout (100 coins) lands near the new one (1,20 ₼ +
## driving bonuses) and old balances buy roughly the same share of upgrades.
const COINS_TO_QEPIK := 2


static func format(qepik: int) -> String:
	var neg := qepik < 0
	var q := absi(qepik)
	var manat := q / QEPIK_PER_MANAT
	var txt := "%s,%02d %s" % [_group(manat), q % QEPIK_PER_MANAT, SYMBOL]
	return ("-" + txt) if neg else txt


## Signed gain/loss; small amounts read as qəpik.
static func format_delta(qepik: int) -> String:
	var sg := "+" if qepik >= 0 else "-"
	var q := absi(qepik)
	if q < QEPIK_PER_MANAT:
		return "%s%d %s" % [sg, q, TranslationServer.translate("MONEY_QEPIK")]
	return sg + format(q)


## Thousands grouped with a space (Azerbaijani convention): 12 345.
static func _group(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


static func from_old_coins(coins: int) -> int:
	return maxi(coins, 0) * COINS_TO_QEPIK
