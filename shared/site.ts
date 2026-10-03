// This is an explicit deployment decision, never derived from a request Host header.
// Keep the current public origin until the custom domain's DNS/TLS is verified.
export const SITE_ORIGIN = 'https://wagz.vercel.app';
// A less discoverable editor entry point; authorization is still enforced by the API.
export const ADMIN_PATH = '/ured-231b67e86427';
export const eventPath = (id: string) => `/dogadaji/${encodeURIComponent(id)}`;
export const publicSiteUrl = (path = '/') => `${SITE_ORIGIN}${path}`;
