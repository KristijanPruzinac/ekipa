# Izvori i dohvat

WagZ dohvaća javne najave preko **Jina Reader API-ja**. Aplikacija ne preuzima izvorne stranice izravno niti pokreće vlastiti preglednik. Zadana postavka koristi javni endpoint bez ključa; plaćeni račun nije potreban za početni rad. OpenRouter zasebno pretvara nejasan tekst u prijedloge događaja.

## Aktivni izvori

| Izvor                                      | Stranica                                                                     | Što se preuzima                                                                                                                  |
| ------------------------------------------ | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Turistička zajednica Osijeka (`tz-osijek`) | [Kalendar manifestacija 2026.](https://www.tzosijek.hr/stranica.php?id=1485) | Jedna godišnja stranica, naslovi i precizni datumi; mjesec bez dana ostaje nerazriješen.                                         |
| Kulturni centar Osijek (`kc-osijek`)       | [Sva događanja](https://kulturni-centar.hr/dogadjanja/sva-dogadjanja)        | Popis se filtrira na aktualne/buduće najave, zatim se čitaju njihove pojedinačne stranice. Objave o upisu pretplate preskaču se. |

To je početni skup za Osijek, ne potpuna pokrivenost grada. Društvene mreže i korisničke poveznice nisu automatski izvori za crawling. Kalendar TZ-a trenutačno je izdanje za 2026.; novu godišnju stranicu treba provjeriti i upisati u registar izvora.

## API, predmemorija i ograničenja

- `GET https://r.jina.ai/{izvorni-https-url}`, `x-respond-with: html`. Reader vraća HTML dokumenta, pa su dostupni izvorni datumi, naslovi, tekst i poveznice. [Službena dokumentacija](https://github.com/jina-ai/reader#using-request-headers).
- Između udaljenih poziva prolazi najmanje 3,1 sekunda. `JINA_API_KEY` je opcionalan; nemoj ga dodavati ako želiš zadržati anonimni način rada. Ograničenja javnog API-ja mogu se promijeniti; HTTP 429 jasno se bilježi kao neuspjeli dohvat.
- Lokalna diskovna predmemorija traje šest sati, u `data/source-cache/` ili direktoriju `WAGZ_FETCH_CACHE_DIR`. Ponovni prolaz kroz cache ne broji se kao udaljeni dohvat. `fetchSource(id, { force: true })` osvježava i lokalni i Jina cache.
- API cache tolerira sadržaj star najviše sat vremena kod običnog dohvata. Zato promjene ili otkazivanja mogu postati vidljivi tek pri idućem osvježavanju.
- Samo četiri unaprijed dopuštena HTTPS hosta izvora mogu se poslati Readeru. Ne prate se proizvoljne korisničke poveznice. Jina redirect, zahtjev dulji od 55 sekundi ili HTML veći od 2 MiB prekidaju dohvat.
- HTML mora sadržavati početak i završetak dokumenta. `x-token-budget` odbija prevelik odgovor; `x-max-tokens`, koji bi ga skratio, nije uključen. Promijenjeni selektori ili prazni glavni blokovi proizvode vidljivu pogrešku.
- Jedno pokretanje obrađuje najviše 30 KC detalja, najbliže datume prvo. Ako ih ima više, izričito se bilježi broj neobrađenih. Ograničenje se može promijeniti argumentom `maxDetails` do 50.

Pri provjeri 3. listopada 2026. anonimni Reader vratio je cijeli TZ dokument (61.361 bajt) i KC popis (842.719 bajtova, ukupno 829 redaka, uključujući prošle objave). Naknadni potpuni prolaz obradio je 18 aktualnih KC najava i 10 precizno datiranih budućih TZ stavki. To su rezultati provjere, ne zajamčeni budući brojevi ili kvote.

Statistika `discovered` broji sve pronađene stavke izvora, uključujući prošle događaje. `skipped` uključuje prošle događaje, objave o pretplatama i stavke koje nije bilo moguće obraditi. Ti brojevi ne predstavljaju broj aktualnih događaja u javnom prikazu.

## Strukturirani podaci i OpenRouter

Jasni datumi iz kalendara i KC metapodataka čitaju se deterministički. Poznato mjesto i besplatan ulaz preuzimaju se samo kada su izričito navedeni u naslovu ili tekstu najave. Svi događaji zadržavaju URL izvora. Ne izmišlja se adresa, cijena, satnica ili lokacija.

Javni opis je kratak, izvorno sastavljen sažetak kategorije, potvrđenog mjesta i eventualno besplatnog ulaza, s uputom na službenu najavu za program. Članak izvora ne kopira se u javni opis niti reže usred rečenice. Kategorija se određuje iz cijelog teksta prije sastavljanja sažetka. Cijeli tekst služi kao privatni dokaz za izdvajanje podataka i, prema potrebi, AI obradu.

Za KC najave s nerazriješenim mjestom, cijenom ili kategorijom parser vraća kompaktan tekst s naslovom, izvornim datumom i tekstom najave u `extractionPages`. Isto vrijedi za nerazriješene datume TZ-a. OpenRouter čita te tekstove kada je ključ konfiguriran i postoji proračun. Aplikacija upravlja AI predmemorijom, validacijom, potrošnjom i objavom. Tekst dulji od 12.000 znakova ne skraćuje se tiho za AI, nego se preskače uz upozorenje.

Bez OpenRouter ključa nastavlja raditi dohvat i deterministički uvoz. TZ stavke bez potvrđenog mjesta ostaju nacrti. Mjesec poput „listopad” nije dovoljan za izmišljanje dana održavanja. Datum bez satnice ostaje `YYYY-MM-DD`. Poznate satnice pretvaraju se prema zoni `Europe/Zagreb`, uključujući ljetno/zimsko računanje vremena. Nejednoznačni sati pri promjeni sata ostaju bez satnice.

KC identitet događaja temelji se na putanji njegove stranice, pa promjena datuma ili sata ne stvara novi događaj. TZ nema pojedinačne identifikatore: koristi se normalizirani naslov i redni broj ponavljanja istog naslova u cijelom godišnjem kalendaru. To razdvaja, primjerice, mjesečne sajmove. Promjene redoslijeda istovjetnih ponavljanja mogu zahtijevati urednički pregled.

Testovi su lokalni i ne trebaju API ključeve ili mrežu: `npx tsx --test server/ingestion/ingestion.test.ts`. Provjeravaju datume, DST, nepoznata polja, identitet nakon promjene termina, promjenu HTML strukture, dopuštene hostove i cache.
