# Spider City — stanje 27.09.2026.

## Dovršeno
- Nastavljen prekinuti zadatak: patrola na krovu, combo/dodge animacije i tri talasa dronova. Nije ponovo građen projekat.
- Završena grafička provera u Steam Godotu 4.7.2: pobeda kroz input za 18.8 s, +150 XP; `docs/validation/patrol-gameplay.mp4`.
- Ispravljen respawn pri prelasku iz patrole u misiju. Izvorni Blender i zaštićeni GLB nisu menjani.
- Sa dodatkom prolazi 20 game smoke + 12 combat + 9 patrol provera. Prethodni traversal/flight/city testovi i rezultati sačuvani.
- Hybrid MCP 2026.09.23 dodat glavnom projektu: editor veza, inspection, parse check i ograničen headless launch potvrđeni.
- Satellite 4.1.11 izgrađen i proveren u odvojenoj kopiji: freeze/step, F, kretanje, patrola i screenshot. Codex zapis postoji, podrazumevano isključen. Blender zapis očuvan.

## Sačuvano
- GitHub grana `codex/spider-city-patrol-mcp-20260927`. Main nije menjan. Checkpointi: `13e632d` (sve prethodne izmene), `583e2ec` (dovršena patrola); završni MCP checkpoint je vrh iste grane.
- Pre nastavka kompletan ZIP: `../backups/SpiderCity-before-resume-20260927-174441.zip`, 624 fajla, provereni CRC i svaki SHA-256. Uključeni untracked fajlovi, Git i Godot cache.
- Najnoviji završni ZIP naveden je u `../backups/LATEST.txt`, sa `.sha256` i manifestom unutar ZIP-a. Ponovljivo: `python tools/snapshot_project.py --output-dir ../backups --label checkpoint`.
- Privatni backup Codex konfiguracije ostaje u `~/.codex/`; putanja i lokalne komande su u `docs/GODOT_MCP_SETUP.md`.

## Sledeće (bez rekonstrukcije konteksta)
1. Otvoriti ovaj projekat u Steam Godotu. Ponovo učitati Codex za prošireni primary katalog: runtime/input/testing/scripts. Koristiti hybrid kao glavni MCP.
2. Nastaviti gameplay: ručno proceniti dodge/combo, popraviti kontakte i siluetu borbe, zatim povezati traversal sa patrolom kroz autorski osmišljenu rutu. Ne povećavati grad ponovo pre toga.
3. Otkloniti null-material inicijalizaciju i audio-resource shutdown; potom Linux export i test van editora.

## Granice i važne putanje
- Oba MCP-a koriste `addons/godot_mcp`; ne prepisivati ih međusobno. Satellite kopija: `../../work/SpiderCity-satellite-test`; server: `../../work/integrations/satellite/server`. U stvarnom projektu je samo hybrid.
- Animacije i arena su prototip, ne 1:1 Insomniac materijal. Komercijalna prava za model/teksture nisu potvrđena. Prolaz testova nije potvrda završne igre.
- Postojeći null-material i retained audio resource ostaju. Editor u izolovanom XDG profilu prijavljuje ObjectDB snapshot directory grešku; nije blokirala testove.
- Detalji ovog nastavka: `docs/PATROL_BUILD.md`, `docs/GODOT_MCP_SETUP.md`. Stariji handoff dokumenti su istorijski; ovaj STATUS je poslednja kontrolna tačka.
