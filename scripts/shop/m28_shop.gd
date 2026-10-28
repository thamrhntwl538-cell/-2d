extends RefCounted
## Optional, one-time exploration purchases. The free map is never restricted.
## The world commits progress and CombatState together with its normal save.

const KEY := "m28_shop"
const VERSION := 1
const SOCKET_CLAIM := "shop:m28:socket"
const ITEMS := [
	{"id":"atlas","price":24,"kind":"tool","name_ar":"أطلس الممرات","name_en":"Passage Atlas","description_ar":"يضيف رموز المتجر والاستراحات وغرف الزعماء إلى المناطق التي اكتشفتها على الخريطة. خريطتك الأساسية تبقى مجانية.","description_en":"Annotates discovered map areas with the market, rests and boss chambers. Your basic map remains free."},
	{"id":"pagefinder","price":32,"kind":"tool","name_ar":"إبرة الفهرس","name_en":"Index Needle","description_ar":"تشير إلى أقرب صفحة غير مقروءة في الغرفة عندما تصبح قريبة. تخفت أثناء القتال والقراءة.","description_en":"Points toward the nearest unread page when it is nearby in your current room. Fades during combat and reading."},
	{"id":"socket","price":70,"kind":"capacity","name_ar":"حلقة فتيل إضافية","name_en":"Spare Wick Ring","description_ar":"تزيد سعة الفانوس بموضع واحد بشكل دائم. تركيب الفتائل وتغييرها يبقى عند المقاعد فقط.","description_en":"Permanently adds one lantern capacity slot. Fitils are still equipped and changed only at benches."},
	{"id":"kindling","price":40,"kind":"fitil","fitil":"wick","name_ar":"فتيل الاستمداد","name_en":"Kindling Wick","description_ar":"فتيل يضيف قليلًا من الوهج لكل إصابة سيف ناجحة عند تركيبه. لا يُركّب تلقائيًا.","description_en":"A fitil that gains a little more glow from each successful sword hit when equipped. Does not equip automatically."},
	{"id":"stillness","price":65,"kind":"fitil","fitil":"focus","name_ar":"فتيل السكينة","name_en":"Stillness Wick","description_ar":"فتيل يقلّل زمن العلاج عند تركيبه، مع بقاء كلفة الطاقة كما هي. غيّره عند المقعد.","description_en":"A fitil that shortens healing when equipped without changing its energy cost. Change it at a bench."}
]

static func catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in ITEMS: result.append(entry.duplicate(true))
	return result

static func definition(id: String) -> Dictionary:
	for item in ITEMS:
		if str(item.id)==id: return item.duplicate(true)
	return {}

static func _purchases(progress: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = progress.get(KEY,{})
	if not raw is Dictionary or raw.get("version",0)!=VERSION: return result
	var source: Variant = raw.get("purchases",[])
	if not source is Array: return result
	for value in source:
		if value is String and not definition(value).is_empty() and not result.has(value): result.append(value)
	return result

static func sanitize(progress: Dictionary, state: RefCounted) -> void:
	var purchases := _purchases(progress)
	# A valid effect receipt survives even if an older progress block omitted the
	# shop entry. It can never sell the same capacity upgrade a second time.
	if state!=null and SOCKET_CLAIM in state.collected and not purchases.has("socket"):
		purchases.append("socket")
	progress[KEY] = {"version":VERSION,"purchases":purchases}

static func owns(progress: Dictionary, state: RefCounted, id: String) -> bool:
	var item := definition(id)
	if item.is_empty(): return false
	if _purchases(progress).has(id): return true
	if state==null: return false
	if str(item.kind)=="fitil": return state.owns_fitil(str(item.fitil))
	if id=="socket": return SOCKET_CLAIM in state.collected
	return false

static func status(progress: Dictionary, state: RefCounted, id: String) -> Dictionary:
	var item := definition(id)
	if item.is_empty() or state==null:
		return {"id":id,"owned":false,"can_buy":false,"reason":"unknown_item","price":0}
	var owned := owns(progress,state,id)
	var reason := "owned" if owned else "ready"
	if not owned:
		if id=="socket" and (state.capacity>=state.MAX_CAPACITY or state.collected.size()>=state.MAX_CLAIMS): reason="capacity_limit"
		elif state.wallet<int(item.price): reason="insufficient_funds"
	return {"id":id,"owned":owned,"can_buy":reason=="ready","reason":reason,"price":int(item.price),"definition":item}

static func purchase(progress: Dictionary, state: RefCounted, id: String) -> Dictionary:
	var offer := status(progress,state,id)
	if not bool(offer.can_buy):
		return {"ok":false,"changed":false,"code":str(offer.reason),"item":id,"spent":0}
	var item: Dictionary = offer.definition
	# Apply the fallible persistent effect before touching the wallet. No failed
	# or duplicate transaction can remove coins or write a purchase receipt.
	if str(item.kind)=="fitil" and not state.acquire(str(item.fitil)):
		return {"ok":false,"changed":false,"code":"effect_unavailable","item":id,"spent":0}
	if str(item.kind)=="capacity" and not state.increase_capacity(SOCKET_CLAIM,1):
		return {"ok":false,"changed":false,"code":"capacity_limit","item":id,"spent":0}
	state.wallet-=int(item.price)
	var purchases := _purchases(progress)
	purchases.append(id)
	progress[KEY] = {"version":VERSION,"purchases":purchases}
	return {"ok":true,"changed":true,"code":"purchased","item":id,"spent":int(item.price)}

static func feedback(code: String, language: String) -> String:
	var arabic := language=="ar"
	match code:
		"purchased": return "تم الشراء · محفوظ في الفانوس." if arabic else "Purchased · kept with your lantern."
		"owned": return "هذه الأداة بحوزتك بالفعل." if arabic else "You already own this item."
		"insufficient_funds": return "العملات غير كافية. عد بعد الاستكشاف." if arabic else "Not enough coins. Return after exploring."
		"capacity_limit": return "لا يمكن إضافة موضع آخر إلى هذا الفانوس." if arabic else "This lantern cannot hold another slot."
		_: return "هذه القطعة غير متاحة الآن." if arabic else "This item is unavailable right now."
