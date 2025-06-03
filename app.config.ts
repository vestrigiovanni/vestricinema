import 'dotenv/config';
import { ExpoConfig, ConfigContext } from '@expo/config';

export default ({ config }: ConfigContext): ExpoConfig => ({
  name: 'CinemaApp',
  slug: 'cinemaapp',
  scheme: 'cinemaapp',
  version: '1.0.0',
  extra: {
    EXPO_PUBLIC_SUPABASE_URL: process.env.EXPO_PUBLIC_SUPABASE_URL,
    EXPO_PUBLIC_SUPABASE_ANON_KEY: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
    EXPO_PUBLIC_TMDB_API_KEY: process.env.EXPO_PUBLIC_TMDB_API_KEY,
    EXPO_PUBLIC_OMDB_API_KEY: process.env.EXPO_PUBLIC_OMDB_API_KEY,
    EXPO_PUBLIC_PRETIX_API_KEY: process.env.EXPO_PUBLIC_PRETIX_API_KEY,
    EXPO_PUBLIC_PRETIX_ORGANIZER: process.env.EXPO_PUBLIC_PRETIX_ORGANIZER,
    EXPO_PUBLIC_PRETIX_EVENT: process.env.EXPO_PUBLIC_PRETIX_EVENT,
    EXPO_PUBLIC_PRETIX_TICKET_ID: process.env.EXPO_PUBLIC_PRETIX_TICKET_ID,
  },
  plugins: ['expo-router'],
});
