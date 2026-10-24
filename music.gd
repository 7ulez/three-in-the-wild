class_name Music
extends RefCounted
## Das Titellied "Three in the Wilds" im Spiel (Abspann). Im Browser per HTML-Audio, sonst per AudioStreamPlayer.

static var _player: AudioStreamPlayer = null


static func play_song(host: Node) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
(function(){
  var a = window.__mmSong;
  if (!a) { a = window.__mmSong = new Audio('menu.mp3'); a.loop = true; }
  if (window.__mm) { window.__mm.stop(); }
  a.volume = 0;
  var p = a.play();
  if (p && p.catch) p.catch(function(){});
  var t0 = Date.now();
  var iv = setInterval(function(){
    var k = Math.min(1, (Date.now() - t0) / 3000);
    a.volume = 0.45 * k;
    if (k >= 1) clearInterval(iv);
  }, 50);
})();
""", true)
		return
	var st = load("res://assets/music/menu.ogg")
	if st == null:
		return
	st.loop = true
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		host.get_tree().root.add_child(_player)
	_player.stream = st
	_player.volume_db = -60.0
	_player.play()
	_player.create_tween().tween_property(_player, "volume_db", -8.0, 3.0)


static func stop_song(host: Node) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
(function(){
  var a = window.__mmSong; if (!a) return;
  var from = a.volume, t0 = Date.now();
  var iv = setInterval(function(){
    var k = Math.min(1, (Date.now() - t0) / 2500);
    a.volume = from * (1 - k);
    if (k >= 1) { clearInterval(iv); a.pause(); }
  }, 50);
})();
""", true)
		return
	if _player != null and is_instance_valid(_player):
		var pl := _player
		var tw := pl.create_tween()
		tw.tween_property(pl, "volume_db", -60.0, 2.5)
		tw.tween_callback(pl.stop)
