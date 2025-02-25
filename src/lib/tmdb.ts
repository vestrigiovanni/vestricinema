import axios from 'axios';

const TMDB_API_KEY = '00ea09c7fb5bf89b064f6001a2de3122';
const OMDB_API_KEY = '962dd713';
const BASE_URL = 'https://api.themoviedb.org/3';

// List of approved major international publications with common variations
const APPROVED_PUBLICATIONS = [
  { name: 'The Guardian', variants: ['guardian', 'the guardian', 'theguardian.com'] },
  { name: 'The New York Times', variants: ['nyt', 'new york times', 'nytimes.com'] },
  { name: 'Time Magazine', variants: ['time', 'time magazine', 'time.com'] },
  { name: 'Rolling Stone', variants: ['rolling stone', 'rollingstone', 'rollingstone.com'] },
  { name: 'The Telegraph', variants: ['telegraph', 'the telegraph', 'telegraph.co.uk'] },
  { name: 'Los Angeles Times', variants: ['la times', 'los angeles times', 'latimes.com'] },
  { name: 'The Washington Post', variants: ['washington post', 'washingtonpost', 'wapo'] },
  { name: 'Entertainment Weekly', variants: ['ew', 'entertainment weekly', 'ew.com'] },
  { name: 'The Atlantic', variants: ['atlantic', 'the atlantic', 'theatlantic.com'] },
  { name: 'BBC', variants: ['bbc', 'bbc.com', 'bbc.co.uk'] },
  { name: 'Empire', variants: ['empire', 'empire magazine', 'empireonline'] },
  { name: 'Variety', variants: ['variety', 'variety.com'] },
  { name: 'IndieWire', variants: ['indiewire', 'indie wire', 'indiewire.com'] },
  { name: 'The Hollywood Reporter', variants: ['thr', 'hollywood reporter', 'hollywoodreporter'] },
  { name: 'Screen International', variants: ['screen', 'screen international', 'screendaily'] }
];

// List of languages that should use English metadata
const USE_ENGLISH_METADATA = [
  'ja', // Japanese
  'ko', // Korean
  'zh', // Chinese
  'ar', // Arabic
  'fa', // Persian
  'ur', // Urdu
  'he', // Hebrew
  'hi', // Hindi
  'bn', // Bengali
  'ta', // Tamil
  'te', // Telugu
  'ml', // Malayalam
  'th', // Thai
  'vi', // Vietnamese
];

export interface MovieReview {
  id: string;
  author: string;
  content: string;
  created_at: string;
  author_details: {
    rating: number;
    avatar_path: string | null;
  };
  publication?: string;
  url?: string;
}

export interface MovieDetails {
  id: number;
  title: string;
  original_language: string;
  poster_path: string;
  backdrop_path: string;
  overview: string;
  release_date: string;
  runtime: number;
  vote_average: number;
  imdb_id?: string;
  credits: {
    cast: Array<{
      id: number;
      name: string;
      character: string;
    }>;
    crew: Array<{
      id: number;
      name: string;
      job: string;
    }>;
  };
  images: {
    backdrops: Array<{
      file_path: string;
      width: number;
      height: number;
      iso_639_1: string | null;
      aspect_ratio: number;
      vote_average: number;
    }>;
    logos: Array<{
      file_path: string;
      width: number;
      height: number;
      iso_639_1: string | null;
      aspect_ratio: number;
      vote_average: number;
    }>;
  };
  translations: {
    translations: Array<{
      iso_639_1: string;
      data: {
        overview: string;
      };
    }>;
  };
}

export interface OmdbAwards {
  awards: string | null;
  loading: boolean;
  error: string | null;
}

export interface OmdbRatings {
  imdb: { rating: string | null; votes: string | null };
  rottenTomatoes: string | null;
  metacritic: string | null;
  loading: boolean;
  error: string | null;
}

const getPreferredLanguage = (originalLanguage: string): string => {
  if (originalLanguage === 'it') {
    console.log('Using Italian metadata for Italian film');
    return 'it';
  }
  
  if (USE_ENGLISH_METADATA.includes(originalLanguage)) {
    console.log(`Using English metadata for ${originalLanguage} language film`);
    return 'en';
  }
  
  console.log(`Using English metadata for ${originalLanguage} language film`);
  return 'en';
};

export const getMovieDetails = async (movieId: string): Promise<MovieDetails> => {
  try {
    const basicResponse = await axios.get(
      `${BASE_URL}/movie/${movieId}?api_key=${TMDB_API_KEY}`
    );
    
    const originalLanguage = basicResponse.data.original_language;
    const preferredLanguage = getPreferredLanguage(originalLanguage);
    
    console.log(`Movie ${movieId}: Original language = ${originalLanguage}, Preferred language = ${preferredLanguage}`);

    const detailsResponse = await axios.get(
      `${BASE_URL}/movie/${movieId}?api_key=${TMDB_API_KEY}&language=${preferredLanguage}`
    );

    const imagesResponse = await axios.get(
      `${BASE_URL}/movie/${movieId}/images?api_key=${TMDB_API_KEY}&include_image_language=${preferredLanguage},null,en`
    );

    const creditsResponse = await axios.get(
      `${BASE_URL}/movie/${movieId}/credits?api_key=${TMDB_API_KEY}&language=${preferredLanguage}`
    );

    const translationsResponse = await axios.get(
      `${BASE_URL}/movie/${movieId}/translations?api_key=${TMDB_API_KEY}`
    );

    const combinedData = {
      ...detailsResponse.data,
      images: imagesResponse.data,
      credits: creditsResponse.data,
      translations: {
        translations: translationsResponse.data.translations
      }
    };

    console.log(`Movie ${movieId} metadata:`);
    console.log(`Title: ${combinedData.title}`);
    console.log(`Original Language: ${combinedData.original_language}`);
    console.log(`Using ${preferredLanguage} metadata`);
    
    const logoLanguages = combinedData.images.logos
      ?.map(logo => logo.iso_639_1 || 'neutral')
      .filter((value, index, self) => self.indexOf(value) === index)
      .join(', ');
    console.log(`Available logo languages: ${logoLanguages}`);

    return combinedData;
  } catch (error) {
    console.error('Error fetching movie details:', error);
    throw error;
  }
};

export const getMovieAwards = async (imdbId: string): Promise<OmdbAwards> => {
  try {
    console.log('Fetching awards for IMDb ID:', imdbId);
    const response = await axios.get(
      `https://www.omdbapi.com/?i=${imdbId}&apikey=${OMDB_API_KEY}`
    );

    if (response.data.Error) {
      console.error('OMDb API error:', response.data.Error);
      return { awards: null, loading: false, error: response.data.Error };
    }

    console.log('Awards data received:', response.data.Awards);
    return {
      awards: response.data.Awards || null,
      loading: false,
      error: null
    };
  } catch (error) {
    console.error('Error fetching movie awards:', error);
    return {
      awards: null,
      loading: false,
      error: 'Failed to fetch awards information'
    };
  }
};

export const getMovieRatings = async (imdbId: string, title: string, year?: string): Promise<OmdbRatings> => {
  try {
    console.log('Fetching ratings for:', { imdbId, title, year });
    
    // Try fetching by IMDb ID first
    const imdbResponse = await axios.get(
      `https://www.omdbapi.com/?i=${imdbId}&apikey=${OMDB_API_KEY}&plot=short&r=json`
    );

    // If IMDb ID fails or returns an error, try by title
    if (imdbResponse.data.Error) {
      console.log('IMDb ID lookup failed, trying title search...');
      const titleUrl = `https://www.omdbapi.com/?t=${encodeURIComponent(title)}${year ? `&y=${year}` : ''}&apikey=${OMDB_API_KEY}&plot=short&r=json`;
      console.log('Title search URL:', titleUrl);
      
      const titleResponse = await axios.get(titleUrl);

      if (titleResponse.data.Error) {
        console.error('Both IMDb ID and title lookups failed:', titleResponse.data.Error);
        return {
          imdb: { rating: null, votes: null },
          rottenTomatoes: null,
          metacritic: null,
          loading: false,
          error: titleResponse.data.Error
        };
      }

      console.log('Title search response:', titleResponse.data);
      return processOmdbResponse(titleResponse.data);
    }

    console.log('IMDb ID lookup response:', imdbResponse.data);
    return processOmdbResponse(imdbResponse.data);
  } catch (error) {
    console.error('Error fetching movie ratings:', error);
    return {
      imdb: { rating: null, votes: null },
      rottenTomatoes: null,
      metacritic: null,
      loading: false,
      error: 'Failed to fetch ratings information'
    };
  }
};

const processOmdbResponse = (data: any): OmdbRatings => {
  console.log('Processing OMDb response:', data);
  
  // Extract IMDb rating and votes
  const imdbRating = data.imdbRating && data.imdbRating !== 'N/A' ? data.imdbRating : null;
  const imdbVotes = data.imdbVotes && data.imdbVotes !== 'N/A' ? data.imdbVotes : null;

  // Extract Rotten Tomatoes rating
  let rtRating = null;
  if (data.Ratings && Array.isArray(data.Ratings)) {
    const rtData = data.Ratings.find(
      (r: { Source: string; Value: string }) => r.Source === 'Rotten Tomatoes'
    );
    if (rtData && rtData.Value !== 'N/A') {
      rtRating = rtData.Value;
    }
  }

  // Extract Metacritic rating
  let metacriticRating = null;
  if (data.Ratings && Array.isArray(data.Ratings)) {
    const mcData = data.Ratings.find(
      (r: { Source: string; Value: string }) => r.Source === 'Metacritic'
    );
    if (mcData && mcData.Value !== 'N/A') {
      metacriticRating = mcData.Value.split('/')[0];
    }
  }
  // Fallback to Metascore if not found in Ratings array
  if (!metacriticRating && data.Metascore && data.Metascore !== 'N/A') {
    metacriticRating = data.Metascore;
  }

  const ratings = {
    imdb: {
      rating: imdbRating,
      votes: imdbVotes
    },
    rottenTomatoes: rtRating,
    metacritic: metacriticRating,
    loading: false,
    error: null
  };

  console.log('Processed ratings:', ratings);
  return ratings;
};

export const getMovieReviews = async (movieId: string): Promise<MovieReview[]> => {
  try {
    console.log(`Fetching reviews for movie ${movieId}...`);
    
    const response = await axios.get(
      `${BASE_URL}/movie/${movieId}/reviews?api_key=${TMDB_API_KEY}&language=en-US`
    );

    if (!response.data.results || response.data.results.length === 0) {
      console.log(`No reviews found for movie ${movieId}`);
      return [];
    }

    console.log(`Found ${response.data.results.length} total reviews for movie ${movieId}`);

    const reviews = response.data.results
      .filter((review: MovieReview) => {
        if (!review.author_details?.rating || review.author_details.rating < 7) {
          console.log(`Skipping review from ${review.author} - no rating or low rating`);
          return false;
        }

        if (!review.content || review.content.length < 100) {
          console.log(`Skipping review from ${review.author} - content too short`);
          return false;
        }

        const authorLower = review.author.toLowerCase();
        const contentLower = review.content.toLowerCase();
        const urlLower = review.url?.toLowerCase() || '';

        for (const pub of APPROVED_PUBLICATIONS) {
          if (pub.variants.some(variant => 
            authorLower.includes(variant) || 
            contentLower.includes(variant) ||
            urlLower.includes(variant)
          )) {
            review.publication = pub.name;
            console.log(`Matched review to publication: ${pub.name}`);
            return true;
          }
        }

        console.log(`Skipping review from ${review.author} - not from approved publication`);
        return false;
      })
      .map((review: MovieReview) => {
        let content = review.content
          .replace(/\[.*?\]/g, '')
          .replace(/\(.*?\)/g, '')
          .replace(/http\S+/g, '')
          .replace(/\s+/g, ' ')
          .trim();

        const sentences = content.split(/[.!?]+/).filter(s => s.trim().length >= 40);
        content = sentences.slice(0, 2).join('. ') + '.';

        return {
          ...review,
          content
        };
      })
      .sort((a, b) => {
        if (b.author_details.rating !== a.author_details.rating) {
          return b.author_details.rating - a.author_details.rating;
        }
        return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
      })
      .slice(0, 3);

    const uniquePublications = new Map();
    const diverseReviews = [];
    
    for (const review of reviews) {
      if (!uniquePublications.has(review.publication)) {
        uniquePublications.set(review.publication, true);
        diverseReviews.push(review);
        if (diverseReviews.length === 3) break;
      }
    }

    console.log(`Returning ${diverseReviews.length} filtered reviews for movie ${movieId}`);
    diverseReviews.forEach(review => {
      console.log(`- ${review.publication}: ${review.author_details.rating}/10`);
    });

    return diverseReviews;
  } catch (error) {
    console.error('Error fetching reviews:', error);
    return [];
  }
};