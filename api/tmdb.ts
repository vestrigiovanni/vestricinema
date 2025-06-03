import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';

const API_KEY = process.env.EXPO_PUBLIC_TMDB_API_KEY!;
const BASE_URL = 'https://api.themoviedb.org/3';

const cacheKey = (id: number) => `tmdb_${id}`;

export interface TMDBMovie {
  id: number;
  title: string;
  overview: string;
  runtime: number;
  poster_path: string | null;
  genres: { id: number; name: string }[];
  videos: any;
  images: any;
  credits: any;
}

export const fetchMovie = async (id: number): Promise<TMDBMovie> => {
  const key = cacheKey(id);
  const cached = await AsyncStorage.getItem(key);
  if (cached) {
    const parsed = JSON.parse(cached);
    const expired = Date.now() - parsed.timestamp > 24 * 60 * 60 * 1000;
    if (!expired) return parsed.data;
  }
  const url = `${BASE_URL}/movie/${id}?language=it-IT&append_to_response=videos,images,credits&api_key=${API_KEY}`;
  const { data } = await axios.get<TMDBMovie>(url);
  await AsyncStorage.setItem(key, JSON.stringify({ data, timestamp: Date.now() }));
  return data;
};
