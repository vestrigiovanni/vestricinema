import axios from 'axios';

const API_KEY = process.env.EXPO_PUBLIC_PRETIX_API_KEY!;
const ORGANIZER = process.env.EXPO_PUBLIC_PRETIX_ORGANIZER!;
const EVENT = process.env.EXPO_PUBLIC_PRETIX_EVENT!;
const TICKET_ID = Number(process.env.EXPO_PUBLIC_PRETIX_TICKET_ID!);
const BASE = `https://pretix.eu/api/v1/organizers/${ORGANIZER}/events/${EVENT}`;

export interface PretixOrder {
  code: string;
  secret: string;
}

export const listProducts = async () => {
  const { data } = await axios.get(`${BASE}/products/`, {
    headers: { Authorization: `Token ${API_KEY}` },
    timeout: 5000,
  });
  return data;
};

export const createOrder = async (): Promise<PretixOrder> => {
  const { data } = await axios.post(
    `${BASE}/orders/`,
    { positions: [{ item: TICKET_ID, quantity: 1 }] },
    {
      headers: { Authorization: `Token ${API_KEY}` },
      timeout: 5000,
    }
  );
  return { code: data.code, secret: data.secret };
};

export const qrCodeUrl = (code: string, secret: string) =>
  `https://pretix.eu${BASE.replace(`/events/${EVENT}`, '')}/download/qr/${code}/${secret}.png`;
