# Spider City — veći grad i novi traversal, 25.09.2026.

Ovaj korak nastavlja lokalne izmene iz `DEVELOPMENT_HANDOFF.md`. Originalni Blender izvor, zaštićeni GLB i centralne misijske zgrade ostali su sačuvani. Nema commit/push promena.

## Pokretanje

Godot 4.7.2 → `project.godot` → Run, ili `./run-linux.sh` na Linuxu sa instaliranim Godotom (podržava i Steam putanju).

- **F** iz glavnog menija: slobodno istraživanje grada.
- **Enter**: izbor lika i postojeće misije.
- **T**: mali Flow Block za vežbanje.
- **LMB / Shift**: mreža; **RMB / Q**: zip; **W/S**: namotavanje/otpuštanje dužine mreže.
- **Space**: skok / odvajanje od mreže ili zida; **J/K**: borba; **F2**: prethodni raspored miša za borbu.

## Šta je stvarno dodato

**Kretanje i animacije**

- Pomoć hvatanju kroz mali lepezasti niz zraka u smeru kamere. Bira stvarne uzdignute površine, uz dodatnu proveru od tela: nema zakačinjanja za prazno nebo ili kroz prepreku.
- Tirkizni indikator dostupnog hvata i oznaka izabranog sidra.
- Različite rastegnute i skupljene swing poze zavisno od brzine/uspona; release, dive, udarac i vertikalni wall-run. Ukupno 16 stanja animacije.
- Završni `SkeletonModifier3D` usmerava odabrani lanac rame–lakat–šaka ka sidru. Mreža koristi položaj šake posle modifikacije, a izvorni bind/rest nisu promenjeni.
- Bezbedan brzi izlazak iz mreže može pokrenuti jednu prezentacionu akrobaciju. Kolizija, brzina i kamera ne rotiraju sa njom; sledeća radnja je prekida.
- Brz frontalni prilaz zidu sa ulazom ka zidu daje kratak uspon. Bočni prilaz zadržava bočni wall-run. Uspon ima budžet od 1,4 s i ne daje beskonačno penjanje.

**Grad i ljudi**

- Površina grada povećana sa 540 × 540 m na **900 × 900 m**, sa **320 zgrada** umesto 132.
- Oko **25.190 dodatnih elemenata**, grupisanih u **418 prostornih grupa**: trotoari, ivičnjaci, prelazi, izlozi/vrata/nadstrešnice, nazivi prodavnica, klupe, kante, drveće/saksije, stajališta, parkirani automobili, požarne stepenice/balkoni, parapeti i solarni paneli.
- Krupni rekviziti (stabla, automobili, zakloni) imaju koliziju. Sitan dekor ostaje bez kolizije da ne zapinje traversal.
- **280 stilizovanih pešaka** raspoređeno je na **128 ruta** koje ne presecaju zgrade. Hodaju različitim brzinama, zastaju, okreću se na uglovima, staju pred igračem i drže razmak od pešaka ispred na istoj ruti.
- Pokretni laktovi i kolena, različite boje odeće/tena, frizure i rančevi. To su jednostavni originalni proceduralni modeli; nisu završni detaljni NPC likovi sa licima, dijalogom ili dnevnim rasporedom.
- Udaljeni pešaci ne troše punu cenu ažuriranja prikaza; elementi ulice koriste deljene instance. Fasade ostaju vidljive do udaljenosti siluete zgrade.
- Ublaženi osvetljenje i magla; ispravljeni ponavljajući tekstovi zgrada i dva graffiti UI upozorenja.

## Provera i dokazi

Godot **4.7.2**, Linux, Compatibility renderer, NVIDIA RTX 3080, 1280 × 720.

- 11 postojećih physics/regression provera: prošle.
- 13 novih traversal provera: prošle (stvarno sidro, prazan prostor, položaj šake, očuvanje brzine pri triku, prekid trika i wall-run budžet).
- 20 provera igre/grada: prošle (broj zgrada/ljudi, rute bez presecanja zgrada, grupisanje detalja, kolizije rekvizita, pomeranje pešaka, sva četiri lika, free roam, misije i čuvanje rezultata).
- Dodatna stvarna physics simulacija frontalnog kontakta sa zidom: wall-run se aktivirao, doneo **5,66 m uspona**, nije prošao kroz zid i zatim je istekao. Ovo nije samo poziv funkcije sa ručno unetim stanjem kontakta.
- Renderovani i pregledani panorama, ulica sa pešacima i nove swing/wall-climb poze. Slike su u `docs/validation/`.
- Poslednji uzorak od 180 frejmova na jednom uličnom kadru: **medijana 7,00 ms**, **95. percentil 8,38 ms**, 675 draw poziva i 29 vidljivih pešaka. Ovo nije kompletan benchmark svih delova grada, niti obećanje performansi na drugom računaru.
- `git diff --check` prolazi.

Testovi:

```sh
XDG_DATA_HOME=/tmp/spider-city-tests ./run-linux.sh --headless --script tests/traversal_test.gd
XDG_DATA_HOME=/tmp/spider-city-tests ./run-linux.sh --headless --script tests/traversal_v2_test.gd
XDG_DATA_HOME=/tmp/spider-city-tests ./run-linux.sh --headless --script tests/game_smoke.gd
XDG_DATA_HOME=/tmp/spider-city-tests ./run-linux.sh --headless --script tests/wall_run_playback.gd
```

## Šta još nije završeno

- Novi grad je igrivi razvojni nivo, a ne završna profesionalna art produkcija: potrebni su detaljnije ručno oblikovani blokovi, manje ponavljanja arhitekture, bolja signalizacija ruta i dalji rad na likovima/animacijama.
- Pešaci prate proverene petlje; nema kompletnog navigacionog AI-ja, razgovora ili reagovanja na borbu. Automobili su parkirani; saobraćaj još ne vozi.
- Sidro/šaka/trik imaju automatske provere, ali treba još duži ručni test svih prelaza kroz ceo grad.
- Godot povremeno ispisuje `material is null` tokom učitavanja glavne scene; još nije otklonjeno. Pri brzom testnom gašenju ostaju WAV/playback resursi uprkos eksplicitnom zaustavljanju muzike. Ne predstavljati build kao potpuno čist.
- Nije napravljen samostalan Linux export niti Steam build. Raniji asset/licence audit i dalje važi za postojeći Spider placeholder; novi ulični rekviziti i pešaci nastaju iz projekta bez novih spoljnih asseta.

Sledeći smislen korak: ručno doterati nekoliko reprezentativnih blokova i jednu kompletnu traversal rutu, zatim povezati saobraćaj/NPC reakcije i borbeni izazov, uz profilisanje tokom stvarnog kretanja.
