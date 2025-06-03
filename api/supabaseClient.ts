import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

type Screening = {
  id: number;
  Titolo: string;
  Data: string;
  'Orario Inizio': string;
  'Orario Fine': string;
  Lingua: string;
  Sottotitoli: string;
  'Sold Out': boolean;
  'Pretix Event ID': number;
  'ID Film TMDb': number;
};

export const fetchScreenings = async (): Promise<Screening[]> => {
  const { data, error } = await supabase
    .from('movies2')
    .select('*')
    .gte('Data', new Date().toISOString().slice(0, 10))
    .order('Data', { ascending: true })
    .order('Orario Inizio', { ascending: true });

  if (error) throw error;
  return data as Screening[];
};

export type { Screening };
