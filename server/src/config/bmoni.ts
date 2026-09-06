import { config } from './env.js';

/// BMONI API client.
/// Every call from the Flutter app goes through our backend,
/// which proxies to BMONI with the secret API key.
class BmoniClient {
  private baseUrl: string;
  private apiKey: string;

  constructor() {
    this.baseUrl = config.bmoni.baseUrl;
    this.apiKey = config.bmoni.apiKey;
  }

  private get headers() {
    return {
      'x-api-key': this.apiKey,
      'Content-Type': 'application/json',
    };
  }

  async post<T>(path: string, body?: Record<string, unknown>): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      method: 'POST',
      headers: this.headers,
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!response.ok) {
      const error = await response.text();
      throw new BmoniApiError(response.status, error);
    }
    return response.json() as Promise<T>;
  }

  async get<T>(path: string): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      method: 'GET',
      headers: this.headers,
    });
    if (!response.ok) {
      const error = await response.text();
      throw new BmoniApiError(response.status, error);
    }
    return response.json() as Promise<T>;
  }

  async patch<T>(path: string, body?: Record<string, unknown>): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      method: 'PATCH',
      headers: this.headers,
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!response.ok) {
      const error = await response.text();
      throw new BmoniApiError(response.status, error);
    }
    return response.json() as Promise<T>;
  }

  async upload<T>(path: string, formData: FormData): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      method: 'POST',
      headers: {
        'x-api-key': this.apiKey,
        // Do NOT set Content-Type — let the browser set it with the boundary
      },
      body: formData,
    });
    if (!response.ok) {
      const error = await response.text();
      throw new BmoniApiError(response.status, error);
    }
    return response.json() as Promise<T>;
  }
}

export class BmoniApiError extends Error {
  constructor(
    public statusCode: number,
    public bmoniMessage: string,
  ) {
    super(`BMONI API error ${statusCode}: ${bmoniMessage}`);
    this.name = 'BmoniApiError';
  }
}

export const bmoni = new BmoniClient();
