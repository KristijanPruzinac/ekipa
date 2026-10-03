// This is an explicit deployment decision, never derived from a request Host header.
// Legacy API/editor hosts remain independently reachable for existing clients/bookmarks.
export const SITE_ORIGIN = 'https://wagz.com.hr';
// A less discoverable editor entry point; authorization is still enforced by the API.
export const ADMIN_PATH = '/ured-231b67e86427';
export const eventPath = (id: string) => `/dogadaji/${encodeURIComponent(id)}`;
export const publicSiteUrl = (path = '/') => `${SITE_ORIGIN}${path}`;
