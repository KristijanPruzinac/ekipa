# Izvori i dohvat

WagZ dohvaća javne najave preko **Jina Reader API-ja**. Aplikacija ne preuzima izvorne stranice izravno niti pokreće vlastiti preglednik. Zadana postavka koristi javni endpoint bez ključa; plaćeni račun nije potreban za početni rad. OpenRouter zasebno pretvara nejasan tekst u prijedloge događaja.

## Aktivni izvori

| Izvor                                                      | Stranica                                                                     | Što se preuzima                                                                                                                                                      |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Turistička zajednica Osijeka (`tz-osijek`)                 | [Kalendar manifestacija 2026.](https://www.tzosijek.hr/stranica.php?id=1485) | Jedna godišnja stranica, naslovi i precizni datumi; mjesec bez dana ostaje nerazriješen.                                                                             |
| Kulturni centar Osijek (`kc-osijek`)                       | [Sva događanja](https://kulturni-centar.hr/dogadjanja/sva-dogadjanja)        | Popis se filtrira na aktualne/buduće najave, zatim se čitaju njihove pojedinačne stranice. Objave o upisu pretplate preskaču se.                                     |
| Turistička zajednica Osječko-baranjske županije (`tz-obz`) | [Događaji](https://visitslavoniabaranja.com/dogadaji/)                       | Puni datumi kartica vode na pojedinačne najave sa strukturiranim `Event` podacima. Regija „Osijek i Podunavlje” dodatno se provjerava prema stvarnom gradu događaja. |

To je početni skup za Osijek, ne potpuna pokrivenost grada. Društvene mreže i korisničke poveznice nisu automatski izvori za crawling. Kalendar TZ-a trenutačno je izdanje za 2026.; novu godišnju stranicu treba provjeriti i upisati u registar izvora.

## API, predmemorija i ograničenja

- `GET https://r.jina.ai/{izvorni-https-url}`, `x-respond-with: html`. Reader vraća HTML dokumenta, pa su dostupni izvorni datumi, naslovi, tekst i poveznice. [Službena dokumentacija](https://github.com/jina-ai/reader#using-request-headers).
- Između udaljenih poziva prolazi najmanje 3,1 sekunda. `JINA_API_KEY` je opcionalan; nemoj ga dodavati ako želiš zadržati anonimni način rada. Ograničenja javnog API-ja mogu se promijeniti; HTTP 429 jasno se bilježi kao neuspjeli dohvat.
- Lokalna diskovna predmemorija traje šest sati, u `data/source-cache/` ili direktoriju `WAGZ_FETCH_CACHE_DIR`. Ponovni prolaz kroz cache ne broji se kao udaljeni dohvat. `fetchSource(id, { force: true })` osvježava i lokalni i Jina cache.
- API cache tolerira sadržaj star najviše sat vremena kod običnog dohvata. Zato promjene ili otkazivanja mogu postati vidljivi tek pri idućem osvježavanju.
- Samo šest unaprijed dopuštenih HTTPS hostova izvora (tri domene, s i bez `www`) može se poslati Readeru. Ne prate se proizvoljne korisničke poveznice. Jina redirect, zahtjev dulji od 55 sekundi ili HTML veći od 2 MiB prekidaju dohvat.
- HTML mora sadržavati početak i završetak dokumenta. `x-token-budget` odbija prevelik odgovor; `x-max-tokens`, koji bi ga skratio, nije uključen. Promijenjeni selektori ili prazni glavni blokovi proizvode vidljivu pogrešku.
- Jedno pokretanje obrađuje najviše 30 detalja po izvoru KC/TZ OBŽ, najbliže datume prvo. Ako ih ima više, izričito se bilježi broj neobrađenih. Ograničenje se može promijeniti argumentom `maxDetails` do 50.

Pri provjeri 3. listopada 2026. anonimni Reader vratio je cijeli TZ dokument (61.361 bajt) i KC popis (842.719 bajtova, ukupno 829 redaka, uključujući prošle objave). Naknadni potpuni prolaz obradio je 18 aktualnih KC najava i 10 precizno datiranih budućih TZ stavki. To su rezultati provjere, ne zajamčeni budući brojevi ili kvote.

Statistika `discovered` broji sve pronađene stavke izvora, uključujući prošle događaje. `skipped` uključuje prošle događaje, objave o pretplatama i stavke koje nije bilo moguće obraditi. Ti brojevi ne predstavljaju broj aktualnih događaja u javnom prikazu.

## HeadOnEast i preciznije županijske najave

U gradskom kalendaru 3. listopada 2026. HeadOnEast ima samo oznaku „listopad”, bez dana ili mjesta. Takva stavka opravdano ne stvara javni događaj. [Službena županijska najava](https://visitslavoniabaranja.com/event/headoneast-festival-osijek/) i [stranica festivala](https://headoneastcroatia.com/) potvrđuju 2.–4. listopada 2026. u osječkoj Tvrđi. Novi adapter otkriva najavu kroz županijski popis; u produkciji nema ručno upisanog HeadOnEast događaja, datuma ili njegove posebne putanje.

TZ OBŽ koristi sve kartice iz HTML popisa, uključujući one koje su početno skrivene filtrima stranice. `data-start` i `data-end` služe za odabir aktualnih najava. Pojedinačni `Event` JSON-LD potvrđuje naslov, datume, mjesto i eventualno otkazivanje; datum objave članka nije datum događaja. Grad mora biti izričito naveden kao Osijek u adresi ili bloku informacija. Dalj, Erdut i stavke bez potvrđenog grada ne uvoze se kao Osijek. Identitet se temelji na putanji najave, pa promjena termina ažurira postojeći zapis.

Izvor može navoditi `00:00–00:00` bez objavljenog rasporeda. Taj par ostaje samo datum. Kod višednevnih najava dnevno radno vrijeme nije potvrda završne satnice posljednjeg dana: završetak zato zadržava datum bez vremena. Besplatan podprogram ne znači da je besplatan cijeli događaj; adapter za tu oznaku traži izričite strukturirane podatke o ulazu. Objavljene cijene koje nedostaju ostaju nepoznate.

Izolirana provjera preko anonimnog Jina API-ja 3. listopada 2026. pronašla je 14 kartica, provjerila sedam detaljnih najava iz regije Osijek i Podunavlje te izdvojila pet događaja s potvrđenim gradom Osijekom, uključujući HeadOnEast. Dalj je isključen, a Korođvar ostaje izvan uvoza jer detalj ne potvrđuje grad. Provjera je koristila privremeni cache, bez promjene baze aplikacije i bez OpenRouter poziva. To je zabilježeno stanje izvora, ne obećanje potpune pokrivenosti.

## Strukturirani podaci i OpenRouter

Jasni datumi iz kalendara i KC metapodataka čitaju se deterministički. Poznato mjesto i besplatan ulaz preuzimaju se samo kada su izričito navedeni u naslovu ili tekstu najave. Svi događaji zadržavaju URL izvora. Ne izmišlja se adresa, cijena, satnica ili lokacija.

Javni opis je kratak, izvorno sastavljen sažetak kategorije, potvrđenog mjesta i eventualno besplatnog ulaza, s uputom na službenu najavu za program. Članak izvora ne kopira se u javni opis niti reže usred rečenice. Kategorija se određuje iz cijelog teksta prije sastavljanja sažetka. Cijeli tekst služi kao privatni dokaz za izdvajanje podataka i, prema potrebi, AI obradu.

Za KC i TZ OBŽ najave s nerazriješenim mjestom, cijenom ili kategorijom parser vraća kompaktan tekst s naslovom, izvornim datumom i tekstom najave u `extractionPages`. TZ stavke bez preciznog dana ostaju upozorenja i ne šalju se AI-ju: izdvajanje nema pretraživanje kojim bi moglo pronaći nedostajući datum. OpenRouter čita tekstove kada je ključ konfiguriran i postoji proračun. Aplikacija upravlja AI predmemorijom, validacijom, potrošnjom i objavom. Tekst dulji od 12.000 znakova ne skraćuje se tiho za AI, nego se preskače uz upozorenje.

AI izdvajanje s iste stranice prvo se uspoređuje s determinističkim događajem. Jednoznačno podudaranje naslova i termina dopunjava samo nepoznata polja, uz očuvanje izvornog identiteta, preciznog datuma, naslova, statusa i dokaza o publici. Nepotvrđena druga satnica, nejasno podudaranje više izvedbi ili proturječni AI prijedlozi stvaraju upozorenje i preskaču se. Zasebni izričito datirani događaji ostaju odvojeni. AI predmemorija uključuje verziju validacije kako stare interpretacije ne bi zaobišle pooštrenu provjeru datuma.

Bez OpenRouter ključa nastavlja raditi dohvat i deterministički uvoz. TZ stavke bez potvrđenog mjesta ostaju nacrti. Mjesec poput „listopad” nije dovoljan za izmišljanje dana održavanja. Datum bez satnice ostaje `YYYY-MM-DD`. Poznate satnice pretvaraju se prema zoni `Europe/Zagreb`, uključujući ljetno/zimsko računanje vremena. Nejednoznačni sati pri promjeni sata ostaju bez satnice.

KC identitet događaja temelji se na putanji njegove stranice, pa promjena datuma ili sata ne stvara novi događaj. TZ nema pojedinačne identifikatore: koristi se normalizirani naslov i redni broj ponavljanja istog naslova u cijelom godišnjem kalendaru. To razdvaja, primjerice, mjesečne sajmove. Promjene redoslijeda istovjetnih ponavljanja mogu zahtijevati urednički pregled.

Testovi su lokalni i ne trebaju API ključeve ili mrežu: `npx tsx --test server/ingestion/*.test.ts`. Provjeravaju datume, DST, nepoznata polja, identitet nakon promjene termina, promjenu HTML strukture, dopuštene hostove i cache. Županijske regresije dodatno provjeravaju višednevne događaje koji već traju, HTML entitete u JSON-LD naslovima, nepoznatu satnicu, grad, otkazivanje i API dohvat detalja bez hardkodiranih događaja.

## Relevantnost i daljnji izvori

Oznake publike trebaju dolaziti iz izričitog poziva, programa ili pogodnosti u najavi, uz poveznicu na dokaz. Žanr, dob izvođača i mjesto nisu dokaz da je događaj za određenu dobnu skupinu. Festivalski format je provjerljiva oznaka programa; sam po sebi ne dokazuje popularnost ili posjećenost.

Deterministička pravila za publiku zanemaruju negirane tvrdnje i nedostupne pogodnosti unutar iste rečenice ili surečenice. Zaseban potvrdan poziv ostaje valjan. Sam izraz „seniori” nije dokaz starije publike jer označava i sportske kategorije; traži se izričit navod umirovljenika, starijih osoba ili treće životne dobi. Nejasne tvrdnje ostaju bez oznake.

Predmemorija izvora sadrži HTML, a ne izračunate oznake publike. Svaki rutinski dohvat ponovno parsira i sadržaj iz predmemorije te zamjenjuje prethodne dokaze istog izvora. AI dopuna čuva te svježe oznake, a za zasebno izdvojene događaje ponovno primjenjuje ista pravila. Promjena ovih pravila zato ne traži promjenu verzije AI predmemorije ni novi plaćeni poziv; primjenjuje se pri sljedećem uspješnom prolazu kroz izvor. Ručno uređeni događaji i dalje zadržavaju uredničke izmjene.

Za buduće proširenje studentskih izvora dostupni su [kalendar Akademije za umjetnost i kulturu](https://www.uaos.unios.hr/my-calendar/?format=list), [sveučilišne najave za studente](https://www.unios.hr/category/vijesti/studenti-i-studiranje/) i [fakultetske objave, primjerice Dani brucoša na EFOS-u](https://www.efos.unios.hr/dani-brucosa-1-2-10-2026/). Ti izvori još nisu aktivni adapteri. Sveučilišne vijesti uključuju prošle događaje, natječaje i događaje u drugim gradovima, pa za uvoz treba potvrditi datum održavanja, mjesto i vrstu objave.

Ako se uvede oznaka veličine događaja, treba pohraniti konkretan podatak, godinu i izvor. Primjerice, [službeni program rada TZ OBŽ za 2026.](https://visitslavoniabaranja.com/wp-content/uploads/2025/12/Program-rada-s-financijskim-planom-TZ-OBZ-za-2026.-godinu.pdf) navodi oko 30.000 posjetitelja HeadOnEasta u 2025. To je povijesna procjena organizatora, a ne potvrđena posjećenost izdanja 2026. ili dokaz osobne relevantnosti.
