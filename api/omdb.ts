import axios from 'axios';

const API_KEY = process.env.EXPO_PUBLIC_OMDB_API_KEY!;

export interface OMDBResponse {
  imdbRating?: string;
  Metascore?: string;
  Ratings?: { Source: string; Value: string }[];
}

export const fetchRatings = async (title: string): Promise<OMDBResponse | null> => {
  try {
    const url = `https://www.omdbapi.com/?apikey=${API_KEY}&t=${encodeURIComponent(title)}`;
    const { data } = await axios.get<OMDBResponse>(url, { timeout: 5000 });
    return data;
  } catch (e) {
    return null;
  }
};
