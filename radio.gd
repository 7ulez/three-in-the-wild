class_name Radio
extends Node
## Radio mit echten Internet-Radio-Streams. Der Ton läuft über das Audio-Element des Browsers
## (JavaScriptBridge), weil Godot selbst keine Streams abspielen kann. Gilt nur für den Web-Export.
## Das Radio ist ein Gegenstand (Item "Radio"): an/aus mit F, Sender wechseln mit Z.
## Lautstärke nach Abstand zum Gerät. An/aus und Sender werden mit den Mitspielern geteilt.

const STATIONS: Array = [
	{"name": "Radio Session", "urls": ["https://stream.laut.fm/radiosession"]},
	{"name": "Sunshine Live", "urls": ["https://stream.sunshine-live.de/live/mp3-192/stream.sunshine-live.de/", "https://sunshinelive.hoerradar.de/sunshinelive-live-mp3-hq"]},
	{"name": "Country (laut.fm)", "urls": ["https://stream.laut.fm/country"]},
	{"name": "Lo-Fi (laut.fm)", "urls": ["https://stream.laut.fm/lofi"]},
	{"name": "Rock Antenne", "urls": ["https://s1-webradio.rockantenne.bayern/rockantenne-bayern/stream/mp3", "https://stream.rockantenne.de/rockantenne/stream/mp3"]},
	{"name": "Fritz", "urls": ["https://dispatcher.rndfnk.com/rbb/fritz/live/mp3/mid"]},
	{"name": "Radio 21", "urls": ["https://radio21.streamabc.net/radio21-hannover-mp3-192-3735655", "https://radio21.streamabc.net/radio21-hannover-mp3-192-3735655?sABC=621564pn%230%238382opo5qn0q0898sq0650qo9522s456%23gjyerqverpg&amsparams=playerid:twlredirect;skey:1645569226"]},
]

static var on: bool = false
static var idx: int = 0
static var volume: float = 0.7     # 0..1, wird mit allen geteilt

var main: Node
var player: Player
var _web: bool = false
var _t: float = 0.0
var _last_state: String = ""
var _vol: float = 0.0


func start(p_main: Node, p_player: Player) -> void:
	main = p_main
	player = p_player
	_web = OS.has_feature("web")
	if _web:
		JavaScriptBridge.eval("""
(function(){
 var R = window.__radio = {a:null, urls:[], i:0, state:'idle', vol:0};
 R.load = function(){
  if (R.a) { R.a.onerror = null; try { R.a.pause(); R.a.removeAttribute('src'); R.a.load(); } catch(e) {} R.a = null; }
  if (R.i >= R.urls.length) { R.state = 'error'; return; }
  var a = new Audio(); a.preload = 'none'; a.volume = R.vol;
  a.onerror = function(){ R.i++; R.load(); };
  a.onplaying = function(){ R.state = 'playing'; };
  a.onwaiting = function(){ if (R.state == 'playing') R.state = 'buffering'; };
  a.src = R.urls[R.i]; R.a = a; R.state = 'loading';
  var p = a.play();
  if (p && p.catch) p.catch(function(e){
   if (e && e.name == 'NotAllowedError') { R.state = 'blocked'; }
   else if (e && e.name != 'AbortError') { R.i++; R.load(); }
  });
 };
 R.play = function(urls){ R.urls = urls; R.i = 0; R.load(); };
 R.stop = function(){ if (R.a) { R.a.onerror = null; try { R.a.pause(); R.a.removeAttribute('src'); R.a.load(); } catch(e) {} R.a = null; } R.state = 'idle'; };
 R.setvol = function(v){ R.vol = v; if (R.a) R.a.volume = v; };
})();
""", true)


static func station_name() -> String:
	return str(STATIONS[idx]["name"])


## Alle Radios in der Welt
func _radios() -> Array:
	return get_tree().get_nodes_in_group("radio_item")


## Das Radio, das man gerade hält oder anschaut (zum Bedienen)
static func target_of(pl: Player) -> Item:
	if pl.held != null and pl.held.item_name == "Radio":
		return pl.held
	var c: Object = pl._reach_target()
	if c is Item and (c as Item).item_name == "Radio":
		return c as Item
	return null


## F: an/aus
func toggle(local: bool = true) -> void:
	on = not on
	_apply()
	if local and player != null:
		player.toast("Radio an: %s" % station_name() if on else "Radio aus.", 2.5)
		_send()


## Z: nächster Sender
func next_station(local: bool = true) -> void:
	idx = (idx + 1) % STATIONS.size()
	on = true
	_apply()
	if local and player != null:
		player.toast("Radio: %s" % station_name(), 2.5)
		_send()


## +/-/Mausrad: Lautstärke in 10er-Schritten (gilt für alle Mitspieler)
func change_volume(step: int) -> void:
	volume = clampf(snappedf(volume + step * 0.1, 0.1), 0.0, 1.0)
	if player != null:
		player.toast("Radio-Lautstärke: %d%% (für alle)" % int(round(volume * 100.0)), 1.5)
		_send()


func remote_set(p_on: bool, p_idx: int, p_vol: float = 0.7) -> void:
	volume = clampf(p_vol, 0.0, 1.0)
	var changed := p_on != on or p_idx != idx
	on = p_on
	idx = clampi(p_idx, 0, STATIONS.size() - 1)
	if changed:
		_apply()


func _send() -> void:
	if Net.instance != null:
		Net.instance.send_radio(on, idx, volume)


func _apply() -> void:
	if not _web:
		return
	if on:
		JavaScriptBridge.eval("window.__radio.play(%s);" % JSON.stringify(STATIONS[idx]["urls"]), true)
	else:
		JavaScriptBridge.eval("window.__radio.stop();", true)
	_last_state = ""


func _process(delta: float) -> void:
	_t += delta
	# Lautstärke nach Abstand zum nächsten Radio
	var vol := 0.0
	if on and player != null and is_instance_valid(player):
		var best := 1e9
		for r in _radios():
			var d: float = (r as Node3D).global_position.distance_to(player.global_position)
			if player.held == r:
				d = 0.5
			best = minf(best, d)
		if best < 1e8:
			vol = pow(clampf(1.0 - (best - 1.5) / 20.0, 0.0, 1.0), 1.6)
			if main != null and main.get("_in_cave") == true:
				vol *= 0.4
	_vol = lerpf(_vol, vol, minf(delta * 5.0, 1.0))
	if _web:
		JavaScriptBridge.eval("window.__radio.setvol(%.3f);" % (_vol * 0.9 * volume), true)
	# Beschriftung der Geräte
	for r in _radios():
		var it := r as Item
		if it.label != null:
			it.label.text = "Radio ♪ %s" % station_name() if on else "Radio"
	if _web and on and _t > 1.0:
		_t = 0.0
		var st := str(JavaScriptBridge.eval("window.__radio ? window.__radio.state : ''", true))
		if st != _last_state:
			_last_state = st
			if st == "error" and player != null:
				player.toast("%s lässt sich nicht laden. Z: anderer Sender." % station_name(), 4.0)
			elif st == "blocked" and player != null:
				player.toast("Der Browser blockt den Ton - noch einmal F drücken.", 4.0)
			elif st == "buffering" and player != null:
				player.toast("Radio puffert ...", 1.5)
