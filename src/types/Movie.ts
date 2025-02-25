export interface Movie {
  id: number;
  Data: string;
  'ID Film TMDb': string;
  'Orario Inizio': string;
  'Orario Fine': string;
  Lingua: string;
  Sottotitoli: string | null;
  'Pretix Event ID': string;
  'Sold Out': boolean;
  Titolo: string;
  Mark: string | null;
}