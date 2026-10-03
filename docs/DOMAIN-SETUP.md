# WagZ domain setup

Status recorded **3 October 2026**. The working production address is still **https://wagz.vercel.app**. `wagz.com.hr` is the selected future primary hostname; DNS and HTTPS verification are pending, so no cutover is claimed.

## Completed configuration

- `wagz.com.hr` is attached to the Vercel project `wagz`.
- `www.wagz.com.hr` is attached with a redirect to `wagz.com.hr`; Vercel API configuration confirms status **308**. The public redirect cannot be verified until DNS/HTTPS work.
- Authoritative nameservers remain REGica's `dns1.com.hr`, `dns2.com.hr` and `dns-ez-1.carnet.hr`. The latest DNS check found no website A/CNAME records.

Hosting remains **Vercel + Neon**. Railway is only an alternative to evaluate later if commercial hosting costs warrant it; no migration is decided.

## DNS records to add

At the existing DNS provider, add the records recommended by `vercel domains verify` for this project:

| Type  | Name  | Value                                 |
| ----- | ----- | ------------------------------------- |
| A     | `@`   | `216.198.79.1`                        |
| A     | `@`   | `64.29.17.1`                          |
| CNAME | `www` | `cae9f53892f4c2e5.vercel-dns-017.com` |

Use both apex A records from the current recommendation. Preserve the nameservers and all unrelated records, including mail and verification records. If the provider requires a full name, use `wagz.com.hr` for `@` and `www.wagz.com.hr` for `www`. Use the project's current recommended values if Vercel changes them later; generic example records are not a substitute. Vercel supports changing website A/CNAME records at an external DNS provider without moving the rest of the zone. [Vercel domain setup](https://vercel.com/docs/domains/working-with-domains/add-a-domain)

No registrar browser session is connected, so these DNS changes have not been made by the current workflow.

## Remaining launch checks

1. Add the DNS records through the owner's REGica account. Verify the authoritative answers and Vercel domain status for both hostnames.
2. Confirm valid HTTPS certificates and anonymous access to the homepage, a published event page and `/api/events` on the apex hostname. Confirm `www` redirects with **308** and preserves an event path/query. Domain redirect configuration and a verified public response are separate checks. [Vercel domain redirects](https://vercel.com/docs/domains/working-with-domains/deploying-and-redirecting)
3. Only after those checks pass, switch canonical, sitemap and share URLs to `https://wagz.com.hr` and enable old public-page redirects. Keep `https://wagz.vercel.app/api/*` working directly for existing mobile clients; do not apply an unconditional hostname redirect to the API.
4. Verify root/event canonicals, one-hop redirects, a missing-event 404, admin `noindex`, and the old mobile API after deployment. Until then, keep the current Vercel address and its canonical configuration working.
5. Complete Search Console ownership verification in the owner's signed-in account, then submit the final sitemap. Owner login is still required; Search Console verification has not been completed.

Verification commands:

```powershell
Resolve-DnsName wagz.com.hr -Type A
Resolve-DnsName www.wagz.com.hr -Type CNAME
vercel domains verify wagz.com.hr
vercel domains verify www.wagz.com.hr
```

The historical price/name research is in [domain options](DOMAIN-OPTIONS.md). Runtime deployment instructions remain in [hosting](DEPLOYMENT.md).
