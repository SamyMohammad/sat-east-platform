// Paymob Intention API client (ADR-003). The secret key never leaves the server.

export type IntentionRequest = {
  amount: number; // minor units
  currency: string;
  payment_methods: number[]; // integration ids
  items: { name: string; amount: number; description: string; quantity: number }[];
  billing_data: { first_name: string; last_name: string; phone_number: string; email: string };
  special_reference: string; // our order id (NOT signed in callbacks — never used for lookup)
  notification_url: string;
  redirection_url: string;
};

export type Intention = { id: string; client_secret: string; intention_order_id: number };

export interface PaymobClient {
  createIntention(req: IntentionRequest): Promise<Intention>;
  checkoutUrl(clientSecret: string): string;
}

export class HttpPaymobClient implements PaymobClient {
  constructor(private readonly cfg: { baseUrl: string; secretKey: string; publicKey: string }) {}

  async createIntention(req: IntentionRequest): Promise<Intention> {
    const res = await fetch(`${this.cfg.baseUrl}/v1/intention/`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Token ${this.cfg.secretKey}` },
      body: JSON.stringify(req),
    });
    const text = await res.text();
    if (!res.ok) {
      // Status only: Paymob error bodies can echo billing data (PII).
      throw new Error(`paymob intention failed: ${res.status}`);
    }
    const j = JSON.parse(text);
    // The live run must confirm where Paymob puts its order id; both places seen in the wild.
    const orderId = j.intention_order_id ?? j.payment_keys?.[0]?.order_id;
    if (typeof j.client_secret !== 'string' || orderId == null) {
      throw new Error('paymob intention: unexpected response shape');
    }
    return { id: String(j.id), client_secret: j.client_secret, intention_order_id: Number(orderId) };
  }

  checkoutUrl(clientSecret: string): string {
    const u = new URL(`${this.cfg.baseUrl}/unifiedcheckout/`);
    u.searchParams.set('publicKey', this.cfg.publicKey);
    u.searchParams.set('clientSecret', clientSecret);
    return u.toString();
  }
}
