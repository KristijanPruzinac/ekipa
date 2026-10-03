# WagZ domain options

Checked: **3 October 2026 (Europe/Zagreb)**. Research only: no registration, account, payment, DNS change or hosting change was made.

## Recommendation

If WagZ is the name to keep, `wagz.hr` is a sensible public address for this Croatian project. Budget roughly **€75–80 per year including VAT** at the two registrars with explicit registration and renewal prices below. For minimum recurring cost, `wagz.com.hr` is a reasonable alternative at **€6.64 per year including VAT** through REGica, subject to availability. These are naming recommendations, not claims that either name is reserved.

A custom domain is not a prerequisite for beginning SEO work: Google's technical requirements concern accessible, indexable pages. Choose the long-term address before substantial promotion, then configure canonical URLs and redirects once. A country domain signals the intended country; it does not guarantee rankings. [Google technical requirements](https://developers.google.com/search/docs/essentials/technical), [country targeting](https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites), [domain migration](https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes).

The domain can point to the existing Vercel project; a second web-hosting package is unnecessary for this setup. Vercel documents adding a domain registered elsewhere and using the project's displayed DNS records. [Vercel domain setup](https://vercel.com/docs/domains/working-with-domains/add-a-domain).

## Published prices

EUR, one year, standard ASCII `.hr` names longer than two characters, such as `wagz`. Prices are a dated comparison, not a checkout quote. The listed registrars appear in [CARNET's authorized registrar directory](https://www.domene.hr/portal/home/registrars).

| Registrar / extension                                         | Registration, excluding VAT |    Registration, including VAT | Annual renewal, including VAT | Notes                                                                                                                                                    |
| ------------------------------------------------------------- | --------------------------: | -----------------------------: | ----------------------------: | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [REGica REG-Silver .hr](https://www.regica.net/hr/cjenik)     |                      €59.72 |                         €74.65 |                        €74.65 | Ordinary account; renewal is also €59.72 excluding VAT.                                                                                                  |
| [Orbis .hr](https://orbis.hr/domene-hrvatske/)                |                      €63.57 |                         €79.46 |                        €79.46 | Renewal is also €63.57 excluding VAT.                                                                                                                    |
| [Plus .hr](https://plus.hr/domene)                            | €50.15 advertised promotion | €62.69 calculated with 25% VAT |   **Not verified separately** | Page also displays a regular €59.00 excluding VAT (€73.75 including VAT); do not assume this is a confirmed renewal quote or that the promotion repeats. |
| [REGica REG-Silver .com.hr](https://www.regica.net/hr/cjenik) |                       €5.31 |                          €6.64 |                         €6.64 | Low recurring-cost alternative; its availability was not checked.                                                                                        |

REGica's cheaper REG-Gold tier requires a minimum prepaid balance of €134.05 excluding VAT; it is not the baseline recommendation for one domain. Compare the total renewal price and optional add-ons at checkout, not just a promotional headline. [REGica terms and prices](https://www.regica.net/hr/cjenik).

## Who can use free or paid .hr

- **Free `.hr`:** one per Croatian-registered legal entity, including a company or association, or a person carrying out registered independent activity in Croatia. The name must meet CARNET's rules for the registered name, shortened name or permitted abbreviation; an arbitrary project brand does not automatically qualify. A private individual without qualifying registered activity is not eligible simply because they live in Croatia. [CARNET free-domain rules](https://www.domene.hr/portal/register/info-free-hr).
- **Paid `.hr`:** EU-established legal entities and individual EU citizens who have a Croatian OIB may register through an authorized registrar. The user's eligibility has not been established in this research. [CARNET paid-domain rules](https://www.domene.hr/portal/register/info-paid-hr).
- **`.com.hr`:** available to all legal and natural persons. Free `.hr` registrations still require annual renewal/confirmation of details. [CARNET FAQ](https://www.domene.hr/portal/faq).

## Exact-name check

A single public query for `wagz.hr` to CARNET's official `whois.dns.hr` service on 3 October 2026 returned **`%ERROR: No entries found`**. This means the query found no registration record; it is not a reservation or a guarantee that registration will succeed. Confirm availability and eligibility with the selected registrar at the time of registration. No registrant personal data was retained. [Official WHOIS service documentation](https://www.domene.hr/portal/about/whois).

## Queued after a name is chosen

Register using the project owner's account; confirm the renewal amount and keep renewal reminders active. Connect DNS to Vercel, choose one canonical hostname, redirect the alternate hostname and old public website URLs, update share links and the Flutter API configuration as appropriate, then verify the chosen domain in Search Console. Preserve existing public API compatibility during a hostname migration. These changes have not been performed; see the [release review queue](RELEASE-QUEUE.md).
