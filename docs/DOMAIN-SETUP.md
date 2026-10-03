# WagZ domain setup

Status recorded **3 October 2026**, after search-account setup. **https://wagz.com.hr** is the deployed canonical origin, delegated to Vercel with verified HTTPS. Release `7d9dd21` (deployment `dpl_3bFRNAeGPqx1wHGZG5WJDodcTmej`) passed live custom-origin checks. Google Search Console and Bing Webmaster Tools are verified and each successfully read the sitemap with **24 discovered pages/URLs**. Some resolver caches still fail, so **https://wagz.vercel.app** homepage/API remain available and the old public-page redirect stays disabled. Actual indexing remains unconfirmed.

## Completed configuration

- `wagz.com.hr` is attached to the Vercel project `wagz`.
- At 09:51, both apex and legacy hostname returned homepage/detail **200**, 23 events, and 24 sitemap URLs using the custom origin. Homepage/detail canonicals and the robots sitemap reference name `wagz.com.hr`; editor pages remain noindex, and anonymous admin API reads return 401. The existing `www` 308 still preserves paths/queries. Evidence: `.artifacts/domain-launch-report.json`.
- `www.wagz.com.hr` redirects to `wagz.com.hr` with **308**. At 09:44, a real HTTPS response preserved `/dogadaji/dns-check?source=dns-check` in the redirect target.
- All three parent `com.hr` nameservers returned **`ns1.vercel-dns.com` and `ns2.vercel-dns.com`** at 09:42 (delegation TTL 14400). Both `vercel domains verify` checks subsequently reported correct configuration.
- At 09:44, the apex homepage, `/api/events` and a real published event page returned **200**, with normal hostname/SNI and certificate validation against Google-observed IPv4 answers. The API returned 23 events; the homepage/detail had SSR content and the detail had Event JSON-LD. Their canonicals still named the old Vercel origin at this pre-cutover check.
- During search-account setup, local/default and Cloudflare resolution still returned `SERVFAIL`, while Google and Vercel authoritative answers worked. The parent authority confirmed the Vercel delegation (TTL 14400); Cloudflare still consulted the old `213.191.128.2/.3` authorities, which returned `REFUSED`. No DS/DNSKEY records or DNSSEC validation failure were observed. Googlebot-user-agent GETs using Google-resolved addresses passed normal TLS validation: sitemap/robots returned 200, the sitemap contained 24 unique valid canonical URLs, and robots allowed crawling. These checks show residual resolver differences; they do not establish access from every network.
- **Access check, 10:31 Zagreb:** all three parent authorities returned the correct Vercel nameservers, and the strict-TLS launch matrix passed through Google resolution for apex/legacy hosts (23 events, 24 sitemap URLs). Google `8.8.8.8` and Quad9 `9.9.9.9` resolved the domain; Cloudflare `1.1.1.1` also resolved after its public NS/A cache purge. Ordinary local requests to the custom domain still failed while `https://wagz.vercel.app` returned 200.
- **Exact ISP cache diagnosis, 10:41:27 Zagreb:** both configured A1 resolvers, `212.91.108.21` and `212.91.108.22`, returned `SERVFAIL` for recursive A queries. Nonrecursive NS queries exposed the old cached delegation to `dns.iskon.hr` and `dns2.iskon.hr`, with **9809 seconds (2h 43m 29s)** remaining on both NS records. The observed entries are expected to expire around **13:25 Zagreb on 3 October**, an estimate for these caches rather than a guarantee of recovery or worldwide propagation. The parent/Vercel configuration is already correct; flushing Windows DNS cannot clear A1's upstream cache. Evidence: `.artifacts/domain-isp-cache-2026-10-03-1041.json`.
- Existing Vercel apex/wildcard ALIAS and CAA records were preserved. The Google Search Console TXT was added to the Vercel zone (record `rec_6804e1591bee7caf4d005c5a`) and confirmed on both authoritative nameservers and Google `8.8.8.8` at 09:48. The signed-in Google domain property is verified. At **10:16 Europe/Zagreb**, the live homepage test reported **URL je dostupan Googleu / Stranica se može indeksirati**; the homepage indexing request was accepted (**Indeksiranje zatraženo**, priority queue). After one sitemap resubmission, its status changed from the earlier fetch failure to **Uspješno**, last read 3 October, with **24 discovered pages and zero videos**. An accepted indexing request and successful sitemap processing do not confirm indexing.
- Bing ownership was verified directly through CNAME `e735a92fec7cfc52ba866db880503060.wagz.com.hr` → `verify.bing.com`, published in Vercel (record `rec_f3340ef5505eddd00651864d`) and checked through `8.8.8.8`. The canonical sitemap was submitted; its final status is **Success**, last crawled 3 October, with **24 discovered URLs, zero errors and zero warnings**. Google property import and a broad Search Console OAuth grant were not used. No mail records were added.

Hosting remains **Vercel + Neon**. Railway is only an alternative to evaluate later if commercial hosting costs warrant it; no migration is decided.

For immediate access, use **https://wagz.vercel.app**. Retry the custom domain after approximately **13:30 Zagreb**; if it still fails, ask [A1 support](https://www.a1.hr/podrska/kontakti) to flush the `wagz.com.hr` NS/delegation cache on the two resolvers above, replacing the cached Iskon pair with `ns1.vercel-dns.com` / `ns2.vercel-dns.com`. A browser-only alternative is selecting Cloudflare or Google as Chrome's Secure DNS provider; this bypasses the affected cache for that browser, without repairing A1's cache. [Official browser instructions](https://developers.cloudflare.com/1.1.1.1/encryption/dns-over-https/encrypted-dns-browsers/). No machine/browser DNS settings, hosts file or registrar records were changed by this diagnostic, and no A1 support request was sent.

**Subsequent approved PC workaround, verified 10:49:43 Zagreb:** with the user's approval, Ethernet DNS was changed to Google **8.8.8.8 / 8.8.4.4** and the local DNS cache cleared; DHCP IP assignment and IPv6 settings were unchanged. Ordinary DNS and HTTPS then returned homepage **200** with valid TLS and **24 sitemap URLs**, without an IP/resolver override; the custom-domain browser page also loaded **23 events**. This fixes access on this PC but does not purge A1's cache for other users; the earlier **13:25** expiry remains an estimate. Ignored evidence: [original DNS configuration and rollback](../.artifacts/windows-dns-before.json), [ordinary DNS/HTTPS verification](../.artifacts/windows-dns-google-verification.json).

## Registrar change and earlier DNS history

The owner saved this nameserver pair at REGica; the parent delegation now confirms it:

| Field             | Value                |
| ----------------- | -------------------- |
| First DNS server  | `ns1.vercel-dns.com` |
| Second DNS server | `ns2.vercel-dns.com` |

Vercel's default ALIAS records serve the website. The external-provider A/CNAME alternative below was not used. Nameserver changes can take up to 48 hours to propagate. [Vercel nameservers](https://vercel.com/docs/domains/managing-nameservers)

**Historical preflight, 09:34 Zagreb / 07:34 UTC:** all three parent servers still returned `dns.iskon.hr` and `dns2.iskon.hr`; those servers refused direct domain queries, recursive lookups failed, and Vercel checks reported invalid external configuration. Existing Iskon mail/verification records could not be established. This was superseded by the 09:42 delegation and 09:44 HTTPS results above. The names `dns1.com.hr`, `dns2.com.hr` and `dns-ez-1.carnet.hr` belong to the parent `com.hr` zone, not the current delegated zone. The initial Vercel preflight found no MX/TXT records, before the later Google verification TXT addition.

REGica's Croatian FAQ gives a **24–48 hour** activation window and says WHOIS/ROOT publication runs once daily. Its English FAQ gives 24–72 hours. The documented domain form procedure does not mention a second confirmation step; the current delay is not evidence that the owner needs to repeat the edit. [REGica FAQ](https://www.regica.net/hr/faq), [English FAQ](https://www.regica.net/en/faq?locale=en)

## Historical alternative: external DNS provider (not used)

Before the registrar change, Vercel recommended these external-provider records for this project. They are the unused alternative, not instructions to change the active Vercel zone:

| Type  | Name  | Value                                 |
| ----- | ----- | ------------------------------------- |
| A     | `@`   | `216.198.79.1`                        |
| A     | `@`   | `64.29.17.1`                          |
| CNAME | `www` | `cae9f53892f4c2e5.vercel-dns-017.com` |

Any future DNS-provider migration must use the project's then-current recommended values and preserve unrelated mail/verification records. The current setup uses Vercel nameservers. [Vercel domain setup](https://vercel.com/docs/domains/working-with-domains/add-a-domain)

## Remaining launch checks

1. Continue checking ordinary local/public recursive DNS until cached failures clear; delegation, authoritative resolution, Vercel configuration and strict HTTPS have passed.
2. Keep the old homepage available during propagation. Canonical/share/sitemap deployment has passed; enable an old public-page redirect only after resolver readiness is confirmed. Preserve paths/queries and keep `https://wagz.vercel.app/api/*` working directly for existing mobile clients.
3. Repeat the route/header matrix after any later redirect change, including a missing-event 404 and the old mobile API. The 09:51 live matrix already passed the current root/detail canonicals, `www` 308 and admin protections. [Vercel domain redirects](https://vercel.com/docs/domains/working-with-domains/deploying-and-redirecting)
4. Review actual index coverage in Google Search Console after its successful sitemap processing and accepted homepage indexing request; discovery and live-test eligibility do not establish indexing.
5. Review actual Bing index coverage after its successful sitemap processing. DuckDuckGo largely sources traditional results from Bing; this is a discovery route, not guaranteed inclusion. The [SEO review](SEO-REVIEW.md#other-search-engines-and-indexnow) records the official guidance.

Verification commands:

```powershell
Resolve-DnsName wagz.com.hr -Type A
Resolve-DnsName www.wagz.com.hr -Type A
Resolve-DnsName wagz.com.hr -Type A -Server ns1.vercel-dns.com
Resolve-DnsName www.wagz.com.hr -Type A -Server ns2.vercel-dns.com
vercel domains verify wagz.com.hr
vercel domains verify www.wagz.com.hr
```

Read-only evidence is in ignored `.artifacts/domain-dns-preflight.json` (historical), `.artifacts/domain-delegation-latest.json` (09:42 delegation), and `.artifacts/domain-https-latest.json` (09:44 strict TLS/HTTP). With Vercel DNS, `www` resolves through its wildcard ALIAS and need not return an explicit CNAME.

Search-account evidence is in ignored `.artifacts/search-setup-2026-10-03/`: `google-indexing-request.png`, `google-sitemap-success.png` and `bing-sitemap-success.png`. The earlier `bing-sitemap.png` records its intermediate Processing status.

The historical price/name research is in [domain options](DOMAIN-OPTIONS.md). Runtime deployment instructions remain in [hosting](DEPLOYMENT.md).
