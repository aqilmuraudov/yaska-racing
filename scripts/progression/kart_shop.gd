class_name KartShop
extends RefCounted
## Kart shop (0.9.0). Each racer + kart pair is one item. ONE TABLE to edit:
## price in qəpik (100 qəpik = 1 ₼) and the suggested buying order.
## Prices were tuned with Economy.simulate_karts (docs/TUNING.md "Kart shop").
## 0.17.4: since 0.14.4 the first launch gives ONE free kart of the player's
## choice; HavHav is no longer owned by everyone, so its old price 0 made it
## a free second kart for anyone who picked another starter.

const PRICES := {
	"havhav": 850, ## Buddy Rally — the all-round kart, cheapest buy
	"posi": 900, ## 1st buy (0.9.1: prices rise with ORDER; same 64 ₼ total)
	"leloyun": 950,
	"bicok": 1000,
	"mestan": 1100,
	"cepis": 1150,
	"yaska": 1300, ## the best kart, last and most expensive
}
## Buying order used by the simulation and the docs.
const ORDER := ["posi", "leloyun", "bicok", "mestan", "cepis", "yaska"]


## Every kart the shop can offer, cheapest first (ORDER assumes the HavHav
## starter; HavHav is offered first when another kart was the starter).
static func shop_order() -> Array:
	return [RacerRoster.DEFAULT_ID] + ORDER


static func price(racer_id: String) -> int:
	return int(PRICES.get(racer_id, 0))


## Qəpik still missing to buy (0 when affordable).
static func missing(racer_id: String, balance: int) -> int:
	return maxi(price(racer_id) - balance, 0)
