# Spider City — razvoj preuzet 24.09.2026.

## Polazno stanje, provereno

- GitHub `Matejaexe/igrica`, grana `main`, preuzeti commit `8e68bad`.
- GitHub konekcija potvrdila pristup pre preuzimanja; repo je trenutno public.
- Projekat traži Godot 4.7; pokrenut i proveravan na **4.7.2.stable.official.ed1daf0bf** (Linux, Compatibility). Lokalni Blender: **5.2.2 LTS**.
- `Main.tscn` je ulaz; `main.gd` već gradi 132 zgrade, meni, izbor lika i misije. Postoje dronovi/borba, graffiti, muzika, SFX i čuvanje rekorda/audio podešavanja. To nije novo napravljeno u ovom koraku.
- Poslednji upstream commit prešao je na Blender `SpideyCleanRig` sa samo run klipom. Ostala stanja su zamrzavala poslednju run pozu. Stara dokumentacija o retargetovanju opisuje prethodnu putanju, koja više nije vlasnik vidljive animacije.
- Referencirani razgovor je pročitan, ali API vraća reference umesto stvarnog teksta ranijih odgovora. Korisnikov preneti opis i dokumentacija repozitorijuma korišćeni su kao stvarni kontekst.

## Implementirano

- Vazdušno kretanje bez automatskog gubitka horizontalnog zamaha; usmeravanje zadržava zarađenu brzinu.
- Mreža počinje stvarnom dužinom od tela do sidra, bez veštačkog početnog impulsa. Jednosmerno ograničenje brzine uklanja udaljavanje od zategnute mreže, zadržava tangentu i ograničava korekciju istezanja. Nema teleportovanja kroz kolizije.
- Provera vidljivosti sidra i od tela, ne samo od kamere. Namotavanje W/S, postojeći pump i ograničenje brzine ostaju.
- 120 ms tolerancije za skok posle ivice i pamćenje skoka; wall-jump iz wall-run stanja zadržava tangentu. Respawn briše zaostala traversal stanja.
- SpringArm kamera sa kolizijom.
- Prenosivi `assets/characters/spidey/spidey_traversal.glb`: originalni run + prototipski idle/walk/jump/fall/land/wall-run/zip/levi i desni swing. Prelazi 0.14 s; nema zamrzavanja run poze u vazduhu.
- Jedan AnimationPlayer piše kosti; `player.gd` zadržava fiziku i vizuelni root. Mreža kreće iz finalnog položaja odabrane šake.
- Izvorni `.blend` i zaštićeni `models/spidey/spidey_funk_alt_v2.glb` ostali su neizmenjeni. Izvoz je ponovljiv preko `tools/build_traversal_clips.py`. Automatski Blender import isključen jer igra sada koristi GLB i ne zahteva instaliran Blender.
- `scenes/traversal_block.tscn`: kompaktan blok sa krovovima, fasadama, kolizijama, pet markera, HUD-om, zvukom, štopericom, restartom i trajnim rekordom.
- **T** na glavnom meniju otvara Flow Block; **Tab** vraća grad; **R** ponavlja blok.
- Novi podrazumevani raspored prema prenetom zahtevu: **LMB mreža / RMB zip / J i K borba**. Shift/Q takođe ostaju dostupni. **F2** vraća prethodni raspored sa LMB/RMB borbom. Izbor traje tokom sesije.

## Validacija

`tests/traversal_test.gd`: 11 provera, sve prošle. Između ostalog: vazdušni momentum, slack/taut mreža, simulacije 8 sekundi na 30/60/120 Hz (maksimalno istezanje približno 9/2/1 mm), dostupnost 10 animacionih stanja, stvarna promena položaja šake, kontinualni run kroz 30 sekundi i respawn.

`tests/game_smoke.gd`: 13 provera, sve prošle i pri grafičkom pokretanju na RTX 3080. Meni, 132 zgrade, sva četiri lika, ulazak u misiju, stvarni input/kretanje/skok, inicijalizacija ring i combat misija, završavanje checkpoint logike i ponovno učitavanje rekorda.

**Granice testa:** checkpoint test namenski postavlja igrača na markere; nije dokaz da je čovek odigrao celu rutu. Matematički test mreže nije kompletan test svih kontakata sa zidom. Ručni gameplay i procena osećaja kretanja još su potrebni.

`tests/capture_traversal.gd` renderuje stvarne Godot kadrove u `docs/validation/`; pregledani idle, run, jump, swing i grad. Tokom pregleda ispravljen je smer podizanja/spuštanja ruku. Ove animacije su početne poze/ciklusi, ne završni animatorski rad; hvatajuća ruka još nema IK do proizvoljnog sidra.

`git diff --check` prolazi. Glavna scena i dalje prijavljuje postojeća upozorenja o graffiti UI anchorima, a pri završetku pojedinih testova ostaje jedan resource u upotrebi. Headless renderer dodatno prijavljuje null material; grafički test nema taj problem. Povremeno okruženje prijavljuje nedostupan shader cache. Ovo nije označeno kao potpuno čist produkcijski build.

Pokretanje provera (koristi izolovane save fajlove):

```sh
XDG_DATA_HOME=/tmp/spider-city-tests godot --headless --path . --script tests/traversal_test.gd
XDG_DATA_HOME=/tmp/spider-city-tests godot --headless --path . --script tests/game_smoke.gd
```

## Konkretni sledeći zadaci

- [x] Pristup, preuzimanje, pregled trenutne arhitekture i verzije.
- [x] Očuvanje izvornog modela i Blender run animacije.
- [x] Prva popravka momentuma, mreže, kamere i prelaza animacija.
- [x] Igrivi test-blok sa aktivnošću, zvukom i rekordom.
- [x] Automatske provere i snimci iz pokrenutog Godota.
- [ ] Ručno odigrati ceo Flow Block za sva četiri lika; izmeriti promašene hvate, sudare kamere i prekide toka.
- [ ] Uvesti izbor stvarnih sidara u malom konusu oko nišana i jasan indikator dostupnosti. Ne kačiti mrežu u prazno nebo.
- [ ] IK šake prema sidru, pravilna animacija promene zida i mekši landing blend u trčanje; vizuelna provera front/side/3-quarter.
- [ ] Fino podesiti 3–5 traversal ruta pre daljeg povećavanja grada; markere pretvoriti u jasnu trening aktivnost.
- [ ] Proveriti borbu/dronove kroz punu misiju, dodati vidljive attack klipove novom rigu i povezan traversal/combat izazov.
- [ ] Sačuvati misijski napredak (trenutno postoje samo rekordi/audio podešavanja), proširiti pause/settings.
- [ ] Otkloniti postojeća UI/resource upozorenja i profilisati puni grad na CachyOS-u.
- [ ] Linux export preset/build i test izvan editora; Steam priprema tek posle asset/licence provere i originalnog identiteta.
- [ ] NPC/saobraćaj i eventualni multiplayer posle stabilne osnovne petlje.

## Asset/licence pregled

| Resurs | Dokaz u repou | Status |
|---|---|---|
| `third_party/godot_platformer/player.glb` | `SOURCE.md` navodi zvanični Godot demo i pinned commit; `LICENSE.md` je priložen | Izvor i licenca evidentirani; nije trenutni vidljivi rig |
| `models/spidey/*`, Blender izvor, `art/spidey/*` | Postojeći Spider/BRC placeholderi; zasebna dozvola za komercijalnu distribuciju nije pronađena | Sačuvano za prototip; Steam prava nisu potvrđena |
| Novi traversal GLB | Izveden iz postojećeg korisnikovog Blender izvora | Nasleđuje ista ograničenja; novi klipovi ne rešavaju poreklo modela/teksture |
| Muzika/SFX/graffiti/fasade | README opisuje muziku kao originalnu; posebni license fajlovi nisu pronađeni | Dokumentovati autorstvo i dozvole pre objave |

Rad je lokalno u ovoj kopiji. Nisu napravljeni commit/push niti promena grane, u skladu sa `AGENTS.md`.
