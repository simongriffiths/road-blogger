export function getOrdsRootUrl(): string {
  const configuredUrl = import.meta.env.VITE_ORDS_ROOT_URL;

  if (configuredUrl.includes('<host>')) {
    return configuredUrl.replace('https://<host>', window.location.origin);
  }

  if (configuredUrl.startsWith('/')) {
    return `${window.location.origin}${configuredUrl}`;
  }

  return configuredUrl;
}
