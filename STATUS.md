# Spider City — stanje 27.09.2026.

## Dovršeno
- Sačuvan ceo dosadašnji rad; grana `codex/spider-city-patrol-mcp-20260927`, početni checkpoint `13e632d`. Main nije menjan.
- Potpuni ZIP pre nastavka: `../backups/SpiderCity-before-resume-20260927-174441.zip`; 624 fajla, svaki proveren SHA-256 manifestom, uključujući Git istoriju i Godot cache.
- Nastavljena prethodno započeta patrola: tri talasa dronova, combo animacije, najava napada, izbegavanje, XP i trajni rekord.
- Završena grafička provera u Steam Godotu 4.7.2: pobeda kroz stvarni input, 18.8 s, +150 XP; snimak `docs/validation/patrol-gameplay.mp4`.
- Ispravljen respawn pri prelasku iz patrole u misiju. 12 combat + 9 patrol provera prolazi. Ranije traversal/flight/city provere sačuvane, nisu rađene ispočetka.

## U toku
- MCP checkpoint: postojeći hybrid server radi, editor bridge još nije povezan. Priprema primarnog addona i odvojene test-kopije za satellite.
- Oba addona koriste `addons/godot_mcp`; nikada ih ne kopirati jedan preko drugog. Blender konfiguraciju sačuvati.

## Sledeće
1. Povezati i proveriti primary MCP u stvarnom projektu; alternativu u izolovanoj kopiji.
2. Sačuvati završni checkpoint na istoj grani i napraviti najnoviji kompletan ZIP.
3. Sledeći gameplay korak: ručno proceniti dodge/combo, popraviti kontakte/siluetu borbe i povezati traversal sa patrolom kroz autorski osmišljenu rutu. Ne povećavati grad ponovo pre toga.

## Ograničenja
Animacije i scena su prototip, ne 1:1 Insomniac materijal. Postojeća null-material upozorenja pri inicijalizaciji i retained audio resource pri gašenju ostaju. Model/licence za komercijalni release nisu rešeni. Izvorni Blender i zaštićeni GLB nisu menjani.
