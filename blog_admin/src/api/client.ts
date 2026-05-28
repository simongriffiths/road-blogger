import { getOrdsRootUrl } from '../config/runtime';

export type ApiError = {
  status: number;
  message: string;
};

export async function apiRequest<T>(path: string, options: RequestInit = {}): Promise<T> {
  const response = await fetch(`${getOrdsRootUrl()}${path}`, {
    credentials: 'same-origin',
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers
    }
  });

  const payload = await response.json().catch(() => null);

  if (!response.ok) {
    throw {
      status: response.status,
      message: payload?.message ?? payload?.error ?? `Request failed with status ${response.status}`
    } satisfies ApiError;
  }

  return payload as T;
}
