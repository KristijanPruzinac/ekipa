# WagZ domain setup

Status recorded **3 October 2026, 09:51 Europe/Zagreb**. **https://wagz.com.hr** is the deployed canonical origin, delegated to Vercel with verified HTTPS. Release `7d9dd21` (deployment `dpl_3bFRNAeGPqx1wHGZG5WJDodcTmej`) passed live custom-origin checks. Some resolver caches were still failing at the latest 09:45 check, so **https://wagz.vercel.app** homepage/API remain available and the old public-page redirect stays disabled.

## Completed configuration

- `wagz.com.hr` is attached to the Vercel project `wagz`.
- At 09:51, both apex and legacy hostname returned homepage/detail **200**, 23 events, and 24 sitemap URLs using the custom origin. Homepage/detail canonicals and the robots sitemap reference name `wagz.com.hr`; editor pages remain noindex, and anonymous admin API reads return 401. The existing `www` 308 still preserves paths/queries. Evidence: `.artifacts/domain-launch-report.json`.
- `www.wagz.com.hr` redirects to `wagz.com.hr` with **308**. At 09:44, a real HTTPS response preserved `/dogadaji/dns-check?source=dns-check` in the redirect target.
- All three parent `com.hr` nameservers returned **`ns1.vercel-dns.com` and `ns2.vercel-dns.com`** at 09:42 (delegation TTL 14400). Both `vercel domains verify` checks subsequently reported correct configuration.
- At 09:44, the apex homepage, `/api/events` and a real published event page returned **200**, with normal hostname/SNI and certificate validation against Google-observed IPv4 answers. The API returned 23 events; the homepage/detail had SSR content and the detail had Event JSON-LD. Their canonicals still named the old Vercel origin at this pre-cutover check.
- Local/default and Cloudflare resolution still returned `SERVFAIL` at 09:45, while Google and authoritative answers worked. These are resolver-specific results, not a claim that every network can already resolve the new hostname.
- Existing Vercel apex/wildcard ALIAS and CAA records were preserved. The supplied Google Search Console TXT was added to the Vercel zone (record `rec_6804e1591bee7caf4d005c5a`) and confirmed on both authoritative nameservers and Google `8.8.8.8` at 09:48. Owner-side Search Console verification and sitemap submission remain incomplete. No mail records were added.

Hosting remains **Vercel + Neon**. Railway is only an alternative to evaluate later if commercial hosting costs warrant it; no migration is decided.

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
4. Click **Verify** in the owner's signed-in Search Console and submit `https://wagz.com.hr/sitemap.xml`; the Google TXT is already publicly visible. DNS publication alone does not complete account-side verification or sitemap submission.
5. After Google ownership is verified, import the property/sitemap into the owner's Bing Webmaster Tools account. DuckDuckGo largely sources traditional results from Bing; this is a discovery route, not guaranteed inclusion. The [SEO review](SEO-REVIEW.md#other-search-engines-and-indexnow) records the official guidance.

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

The historical price/name research is in [domain options](DOMAIN-OPTIONS.md). Runtime deployment instructions remain in [hosting](DEPLOYMENT.md).
