# Projekt-Regeln

- **Maximal 1000 gleichzeitig sichtbare Objekte** (MeshInstance3D, MultiMesh, CSG, Label3D, Sprite3D, Partikel). Im Browser (WebGL) wird darüber gar nichts mehr gezeichnet.
  Neue Deko deshalb als MultiMesh bündeln, per Batcher zusammenfassen oder nur in der Nähe des Spielers zeichnen (siehe Cull-Block in `main.gd::_process`, `Massif.CaveDecor`).
  Vor dem Export messen (`visible` Geometrie am Spawn muss deutlich unter 1000 bleiben).
- Nach jedem Deploy: "Bitte auf Unraid updaten und im Browser Strg+F5 drücken."
- Berichte kurz auf Deutsch; nach Änderungen committen und pushen.
