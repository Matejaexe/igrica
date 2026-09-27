# Spider City — poslednja kontrolna tačka, 27.09.2026.

## Dovršeno u ovom nastavku
- Nastavljena borba/patrola uz novo korisnikovo Blender + Godot uputstvo; projekat nije ponovo građen.
- Radni `spidey_animation_working.blend` sadrži postojeći model/rig i sve akcije. Originalni `.blend` i zaštićeni GLB ostali su neizmenjeni.
- Normalan izvoz sada je `tools/export_character_animations.py`: čuva ručne Blender izmene, proverava skelet, izvozi GLB bez ponovnog generisanja poza. Prototype builder traži eksplicitan rebuild i pravi backup radnog fajla.
- AnimationTree preuzeo 31 stanje i blendovanje; AnimationPlayer služi kao biblioteka. Kontroler zadržava kretanje, swing IK se primenjuje posle animacije. Hod/trčanje/sprint čuvaju fazu koraka.
- Dorađena tri udarca (priprema/kontakt/oporavak + prsti); dodat Sprint iznad 22 m/s, bez nove kontrole. Šteta se primenjuje na 40% klipa, uz ponovnu proveru dometa/zida; dodge prekida udarac.
- 111 provera prolazi. Pregledano 12 slika iz tri ugla i sačuvan animacioni snimak. Patrola odigrana inputom u headless (21.0 s) i grafičkom Godotu (37.6 s), +150 XP.

## Sačuvano / orijentiri
- Aktivna GitHub grana: `codex/spider-city-patrol-mcp-20260927`; main ostaje neizmenjen.
- Pre ovog koraka kompletan snapshot: `../backups/SpiderCity-patrol-mcp-final-20260927-200257.zip` (checkpoint 4cc0c10).
- Najnoviji završni ZIP naveden u `../backups/LATEST.txt`, sa SHA-256 i manifestom. Ponovljivo: `python tools/snapshot_project.py --output-dir ../backups --label checkpoint`.
- Novi izvor istine: `docs/HYBRID_ANIMATION_PIPELINE.md`; snimci `docs/validation/hybrid-animation-review.mp4` i `hybrid-patrol-gameplay.mp4`.
- Hybrid MCP je glavni i instaliran u projektu. Satellite ostaje isključen i izdvojen u test-kopiji; Blender MCP konfiguracija očuvana. Lokalna uputstva: `docs/GODOT_MCP_SETUP.md`.

## Sledeći zadaci — nastaviti ovde
1. Fino doraditi kontakt stopala, težinu tela i položaj palca/šake tokom udaraca. Animacije jesu vizuelno pregledane, ali još nisu završni animatorski kvalitet.
2. Na istom rigu dalje dorađivati idle/run/jump/fall/landing, fizički swing i wall-run. Svaki izmenjen klip ponovo importovati, proveriti prelaze i vizuelno pregledati tokom igranja.
3. Povezati traversal i patrolu autorskom rutom/encounterom; ne povećavati grad ponovo.
4. Otkloniti null-material/audio-resource dijagnostiku, pa Linux export.

## Ograničenja
Nema 1:1 Insomniac animacija. Posebni napadi još nemaju zasebno dorađene klipove; udarci proveravaju domet/zid, ne swept fist collider. Komercijalna prava za izvorne modele/teksture nisu potvrđena. Postojeći render/audio i Blender export warning-i ostaju. Ne regenerisati rig_contract.json da bi se sakrila nekompatibilnost.
