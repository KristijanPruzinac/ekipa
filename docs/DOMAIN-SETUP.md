# WagZ domain setup

Status recorded **3 October 2026**. The working production address is still **https://wagz.vercel.app**. `wagz.com.hr` is the selected future primary hostname; DNS and HTTPS verification are pending, so no cutover is claimed.

## Completed configuration

- `wagz.com.hr` is attached to the Vercel project `wagz`.
- `www.wagz.com.hr` is attached with a redirect to `wagz.com.hr`; Vercel API configuration confirms status **308**. The public redirect cannot be verified until DNS/HTTPS work.
- The current delegation is **`dns.iskon.hr` and `dns2.iskon.hr`**, confirmed by the parent zone and Vercel. The previously recorded `dns1.com.hr`, `dns2.com.hr` and `dns-ez-1.carnet.hr` are the **parent `com.hr` zone's** nameservers, not the delegated nameservers for `wagz.com.hr`.
- Both Iskon servers refuse direct queries for this domain; public recursive lookups return `SERVFAIL`. Existing A/CNAME, MX and TXT records are **unknown**, not proven absent. Obtain any existing mail/verification records from the owner or Iskon before moving the zone.
- Vercel's DNS zone already has its default apex and wildcard ALIAS records plus three certificate-authority CAA records. Direct queries to **both** `ns1.vercel-dns.com` and `ns2.vercel-dns.com` resolve the apex and `www` to Vercel IPv4 addresses (TTL 1800). No DNS records were added or deleted. No MX/TXT records are present in this Vercel zone.

Hosting remains **Vercel + Neon**. Railway is only an alternative to evaluate later if commercial hosting costs warrant it; no migration is decided.

## Registrar nameserver change

If the REGica form only offers DNS servers, use these exact values after checking whether the domain has any existing mail, verification or other service records to copy into Vercel:

| Field             | Value                |
| ----------------- | -------------------- |
| First DNS server  | `ns1.vercel-dns.com` |
| Second DNS server | `ns2.vercel-dns.com` |

Replace the Iskon pair; enter hostnames without `https://` or IP addresses. Preserve every existing Vercel record. Its default ALIAS records already serve the website, so the external-provider A/CNAME records below do not need adding to Vercel. Nameserver changes are made at the registrar and can take up to 48 hours to propagate. [Vercel nameservers](https://vercel.com/docs/domains/managing-nameservers)

The owner reports saving the Vercel nameservers manually at REGica after Windows computer-use could not connect. At **07:34 UTC on 3 October 2026**, direct queries to all three parent `com.hr` servers still returned the Iskon delegation (TTL 14400); Cloudflare/Google recursive lookups and ordinary HTTPS resolution still failed. Both `vercel domains verify` checks report invalid external configuration. Registrar publication and subsequent propagation are pending; no further nameserver or record edits were made. Vercel's zone preflight is separate from public DNS and HTTPS verification.

REGica's Croatian FAQ gives a **24–48 hour** activation window and says WHOIS/ROOT publication runs once daily. Its English FAQ gives 24–72 hours. The documented domain form procedure does not mention a second confirmation step; the current delay is not evidence that the owner needs to repeat the edit. [REGica FAQ](https://www.regica.net/hr/faq), [English FAQ](https://www.regica.net/en/faq?locale=en)

## Alternative: keep an external DNS provider

If the owner can restore the Iskon zone and access its record editor, preserve that delegation and add the records currently recommended by `vercel domains verify` for this project:

| Type  | Name  | Value                                 |
| ----- | ----- | ------------------------------------- |
| A     | `@`   | `216.198.79.1`                        |
| A     | `@`   | `64.29.17.1`                          |
| CNAME | `www` | `cae9f53892f4c2e5.vercel-dns-017.com` |

Use both apex A records from the current recommendation. Preserve all unrelated records, including mail and verification records. If the provider requires a full name, use `wagz.com.hr` for `@` and `www.wagz.com.hr` for `www`. Use the project's current recommended values if Vercel changes them later; generic example records are not a substitute. Vercel supports changing website A/CNAME records at an external DNS provider without moving the rest of the zone. [Vercel domain setup](https://vercel.com/docs/domains/working-with-domains/add-a-domain)

## Remaining launch checks

1. Complete one DNS approach above, preserving any existing service records. Verify the public delegation, authoritative answers and Vercel domain status for both hostnames.
2. Confirm valid HTTPS certificates and anonymous access to the homepage, a published event page and `/api/events` on the apex hostname. Confirm `www` redirects with **308** and preserves an event path/query. Domain redirect configuration and a verified public response are separate checks. [Vercel domain redirects](https://vercel.com/docs/domains/working-with-domains/deploying-and-redirecting)
3. Only after those checks pass, switch canonical, sitemap and share URLs to `https://wagz.com.hr` and enable old public-page redirects. Keep `https://wagz.vercel.app/api/*` working directly for existing mobile clients; do not apply an unconditional hostname redirect to the API.
4. Verify root/event canonicals, one-hop redirects, a missing-event 404, admin `noindex`, and the old mobile API after deployment. Until then, keep the current Vercel address and its canonical configuration working.
5. Complete Search Console ownership verification in the owner's signed-in account, then submit the final sitemap. Owner login is still required; Search Console verification has not been completed.

Verification commands:

```powershell
Resolve-DnsName wagz.com.hr -Type A
Resolve-DnsName www.wagz.com.hr -Type A
Resolve-DnsName wagz.com.hr -Type A -Server ns1.vercel-dns.com
Resolve-DnsName www.wagz.com.hr -Type A -Server ns2.vercel-dns.com
vercel domains verify wagz.com.hr
vercel domains verify www.wagz.com.hr
```

The read-only DNS results are saved locally in ignored `.artifacts/domain-dns-preflight.json` and `.artifacts/domain-delegation-latest.json`. With Vercel DNS, `www` resolves through its wildcard ALIAS and need not return an explicit CNAME.

The historical price/name research is in [domain options](DOMAIN-OPTIONS.md). Runtime deployment instructions remain in [hosting](DEPLOYMENT.md).
