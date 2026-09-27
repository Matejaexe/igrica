# Godot MCP — lokalna integracija, 27.09.2026.

## Instalirano i provereno

Primarni je [hybridindie/godot-mcp](https://github.com/hybridindie/godot-mcp), verzija 2026.09.23, commit `61d3036f161d1620cb628dbc5b05d0042ff5cef9`. Originalan addon je u `addons/godot_mcp`, sa MIT licencom i zapisom izvora. `project.godot` uključuje plugin i `MCPRuntimeProbe`; probe ne radi van debug sesije. Postojeći `godot-hybrid` Codex server je očuvan i koristi korisnikov Steam executable:

```sh
'/home/exe/.local/share/Steam/steamapps/common/Godot Engine/godot.x11.opt.tools.64' --editor --path '/home/exe/Documents/Codex/2026-09-24/referenced-chatgpt-conversation-this-is-an/outputs/SpiderCity'
```

Bridge `ws://127.0.0.1:9080` je potvrđeno povezan; inspection vraća pravi projekat i Godot 4.7.2. `godot_debug_workflow` je proverio parsiranje i pokrenuo glavnu scenu headless, uz očekivani prekid na granici od 8 s. To nije dokaz odigrane misije; zaseban gameplay snimak i testovi su u `validation/`.

Codex konfiguracija `~/.codex/config.toml` sada ima podrazumevane primary toolsetove `inspection,runtime,input,testing,scripts`. Postojeća komanda/argumenti i Blender MCP su očuvani. Privatni backup: `~/.codex/config.toml.spider-city-20260927-195638.bak` (nije deo javnog repoa). Trenutna sesija vidi raniji katalog alata; ponovo pokreni Codex kada želiš novoprošireni katalog. Toolset pravilo i dalje važi: prvo server info, zatim list toolsets, pa enable samo onoga što nedostaje.

Alternativa je [satelliteoflove/godot-mcp](https://github.com/satelliteoflove/godot-mcp), 4.1.11, commit `c7328651d6d64cae541d79c398e3cc1ca1f4f9f4`. Izgrađena lokalno u `../../work/integrations/satellite/server`; Codex zapis `godot-satellite` postoji sa `enabled = false`. Node je `/usr/bin/node`, server `dist/cli.js`, host 127.0.0.1, port 6550. Lokalni usage log je isključen. Potrebno je uključiti taj zapis i ponovo učitati Codex samo kada se koristi alternativna test-kopija.

## Sukobi i granice

**Oba upstreama instaliraju `addons/godot_mcp`. Ne instalirati jedan preko drugog.** Različiti portovi ne rešavaju isti folder, imena GDScript klasa i debugger kanale. Glavni projekat sadrži samo hybrid. Satellite radi isključivo u `../../work/SpiderCity-satellite-test` i automatski dodaje svoj `MCPGameBridge` samo tamo. To je kopija za test, nije druga grana razvojnog projekta; njene izmene se ne vraćaju automatski.

Ne pokretati drugi hybrid server na 9080, niti dva editora nad istim folderom. Sačuvati trenutnu scenu pre zatvaranja editora. Pre svakog automatizovanog testa proveriti project path; priloženi test odbija drugi projekat.

## Rezultati

- Primarni: živa veza sa editorom, project info/scene tree, parse check i ograničeni headless launch potvrđeni.
- Glavni projekat sa dodatkom: 20 game smoke + 12 combat + 9 patrol provera prolazi.
- Alternativa: svi protocol smoke testovi prošli; server/addon verzije se podudaraju.
- Stvarni test alternative: frozen launch, koraci do menija, F za free roam, 800 ms kretanja (brzina preko 18 m/s), pokretanje patrole inputom, potvrda wave=1/remaining=2 i snimak. Test završava stop komandom.
- Produkcijske npm zavisnosti: kompatibilno ažuriran lockfile; audit 0 prijavljenih ranjivosti na datum provere. Četiri prijave ostaju u razvojnim zavisnostima upstream build alata; nisu u produkcijskom dependency skupu. Sačuvan lockfile korišćen u testu, bez node_modules u Git-u.
- Poznati game null-material i audio shutdown resource dijagnostički zapisi ostaju. Editor u izolovanom XDG profilu prijavljuje i ObjectDB snapshot directory grešku; nije blokirala bridge niti test. MCP dodatak nije popravka tih ranijih/render problema.

## Ponovljiva priprema alternative (iz korena SpiderCity)

Koristi NOV folder za checkout i NOV folder za kopiju. Sledeći primer neće pregaziti postojeću instalaciju:

```sh
git clone https://github.com/satelliteoflove/godot-mcp.git /tmp/spider-satellite-source
git -C /tmp/spider-satellite-source checkout c7328651d6d64cae541d79c398e3cc1ca1f4f9f4
cp tools/mcp/satellite-package-lock.json /tmp/spider-satellite-source/server/package-lock.json
(cd /tmp/spider-satellite-source/server && npm ci --ignore-scripts && npm run build && npm run test:protocol)
python tools/mcp/prepare_alternative.py --satellite-source /tmp/spider-satellite-source --destination /tmp/SpiderCity-satellite-new
'/home/exe/.local/share/Steam/steamapps/common/Godot Engine/godot.x11.opt.tools.64' --headless --editor --path /tmp/SpiderCity-satellite-new --import
XDG_DATA_HOME=/tmp/spider-satellite-saves '/home/exe/.local/share/Steam/steamapps/common/Godot Engine/godot.x11.opt.tools.64' --editor --path /tmp/SpiderCity-satellite-new
```

U drugom terminalu, dok test-editor radi:

```sh
node tools/mcp/verify_alternative.mjs /tmp/spider-satellite-source/server /tmp/SpiderCity-satellite-new
```

Ovaj test koristi sopstveni kratkotrajni stdio klijent; isključi Codex `godot-satellite` dok ga pokrećeš jer satellite prihvata samo jednog klijenta. Primarni može ostati registrovan, sa svojim projektom na 9080.

[Zvanična Codex MCP konfiguracija](https://learn.chatgpt.com/docs/extend/mcp?surface=cli) dokumentuje `enabled = false`, STDIO komandne argumente i environment podešavanja. Ne objavljivati privatnu globalnu konfiguraciju u Git-u.
