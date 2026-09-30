# Spider City — poslednja kontrolna tačka, 30.09.2026.

## Dovršeno u ovom nastavku
- Nastavljen tačno sledeći zadatak posle `1c679b9`: oslonac stopala i težina tela u borbi. Postojeći Blender + AnimationTree pipeline je očuvan.
- U radnom `.blend` dorađeni samo Punch, PunchLeft i Finisher: širi stav, stopala ostaju na mestu, kukovi se spuštaju u pripremi i podižu pri kontaktu. Ostalih 29 akcija i mesh/skin podaci provereno su identični pređašnjim.
- Godot dodaje ograničen IK oslonac za Idle i spore normalne udarce, uključujući nagib podloge. Redosled: AnimationTree → oslonac nogu → swing arm IK. Sudarno telo, momentum i swing fizika ostaju kod kontrolera.
- 116 provera prolazi. Pregledano 19 slika iz tri ugla: 225 frejmova oslonca/udaraca i 90 frejmova prelaza u trčanje. Korekcija kukova se postepeno gasi za oko 0.1 s pri kretanju; noge se odmah oslobađaju IK oslonca. Grafička patrola odigrana stvarnim inputom: tri talasa, pobeda za 24.1 s, +150 XP. To je funkcionalna provera, ne benchmark balansa.
- Originalni `.blend`, zaštićeni GLB, nazivi kostiju i rig contract ostali su neizmenjeni.

## Sačuvano / orijentiri
- GitHub grana: `codex/spider-city-patrol-mcp-20260927`; main se ne menja.
- Pre ovog koraka kompletan snapshot: `../backups/SpiderCity-hybrid-animation-20260927-203022.zip` (checkpoint 1c679b9). Dodatno sačuvan radni `.blend` pre izmene.
- Najnoviji završni ZIP naveden u `../backups/LATEST.txt`, sa SHA-256 i manifestom. Ponovljivo: `python tools/snapshot_project.py --output-dir ../backups --label checkpoint`.
- Detalji poslednjeg rada: `docs/GROUND_SUPPORT.md`. Pipeline: `docs/HYBRID_ANIMATION_PIPELINE.md`.
- Snimci: `docs/validation/support-animation-review.mp4` i `support-patrol-gameplay.mp4`; logovi `support-*.txt`.
- Hybrid MCP ostaje primarni; Satellite izdvojen i isključen; Blender MCP očuvan. `docs/GODOT_MCP_SETUP.md`.

## Sledeći zadaci — nastaviti ovde
1. Doraditi palac/šaku i prepoznatljiviji završetak trećeg udarca u postojećim Blender akcijama. Palčevi još previše štrče; ovaj korak ih nije menjao.
2. Dorađivati faze oslonca pri trčanju i landing animacije; sadašnji ground IK namerno pokriva samo Idle i spore udarce. Zatim nastaviti fizički swing/wall-run, uz import i vizuelnu proveru svakog izmenjenog klipa.
3. Povezati traversal i patrolu autorskom rutom/encounterom; ne povećavati grad ponovo.
4. Otkloniti null-material/audio-resource dijagnostiku, pa Linux export.

## Ograničenja / ne ponavljati
Ne pokretati prototype builder preko radnog `.blend`; normalan izvoz je `tools/export_character_animations.py`. `tools/refine_combat_support.py` je jednokratna migracija i odbija ponavljanje. Ne regenerisati rig_contract.json. Oslonac na pokretnim platformama i pun gait foot locking nisu urađeni. Posebni napadi nemaju nove klipove; hit query je domet/zid, ne swept fist collider. Postojeći render/audio/export warning-i ostaju. Nema 1:1 Insomniac animacija; komercijalna prava za izvorne modele/teksture nisu potvrđena.
