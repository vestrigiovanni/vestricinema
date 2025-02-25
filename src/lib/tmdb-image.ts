import type { MovieDetails } from './tmdb';

const TMDB_IMAGE_BASE_URL = 'https://image.tmdb.org/t/p';

export const getMoviePoster = (path: string | null) => {
  if (!path) return '';
  return `${TMDB_IMAGE_BASE_URL}/w500${path}`;
};

export const getMovieBackdrop = (path: string | null) => {
  if (!path) return '';
  return `${TMDB_IMAGE_BASE_URL}/original${path}`;
};

export const getMovieLogo = (path: string | null) => {
  if (!path) return '';
  return `${TMDB_IMAGE_BASE_URL}/original${path}`;
};

export const findPreferredLogo = (details: MovieDetails) => {
  if (!details?.images?.logos?.length) {
    console.log('No logos found for movie:', details.title);
    return null;
  }
  
  // Filter for PNG logos only and sort by vote_average
  const pngLogos = details.images.logos
    .filter(logo => logo.file_path.toLowerCase().endsWith('.png'))
    .sort((a, b) => b.vote_average - a.vote_average);

  if (!pngLogos.length) {
    console.log('No PNG logos found for movie:', details.title);
    return null;
  }

  // Log available logos for debugging
  console.log('Available logos for', details.title, ':', pngLogos.map(logo => ({
    language: logo.iso_639_1 || 'neutral',
    path: logo.file_path,
    vote_average: logo.vote_average
  })));

  const originalLanguage = details.original_language;
  console.log('Original language:', originalLanguage);

  // Priority 1: Try English logos first
  const englishLogos = pngLogos.filter(logo => logo.iso_639_1 === 'en');
  if (englishLogos.length > 0) {
    // Get the highest rated English logo
    const bestEnglishLogo = englishLogos[0];
    console.log('Found English logo with rating:', bestEnglishLogo.vote_average);
    return bestEnglishLogo.file_path;
  }

  // Priority 2: If no English logo, try original language
  const originalLanguageLogos = pngLogos.filter(logo => 
    logo.iso_639_1 === originalLanguage
  );
  if (originalLanguageLogos.length > 0) {
    // Get the highest rated original language logo
    const bestOriginalLogo = originalLanguageLogos[0];
    console.log('Found original language logo with rating:', bestOriginalLogo.vote_average);
    return bestOriginalLogo.file_path;
  }

  // Priority 3: Try language-neutral logos
  const neutralLogos = pngLogos.filter(logo => !logo.iso_639_1);
  if (neutralLogos.length > 0) {
    // Get the highest rated neutral logo
    const bestNeutralLogo = neutralLogos[0];
    console.log('Found neutral logo with rating:', bestNeutralLogo.vote_average);
    return bestNeutralLogo.file_path;
  }
  
  // Priority 4: If all else fails, use the highest voted logo regardless of language
  console.log('Using highest voted logo as fallback with rating:', pngLogos[0].vote_average);
  return pngLogos[0].file_path;
};

export const findBackdrops = (details: MovieDetails) => {
  if (!details?.images?.backdrops?.length) return null;

  // Filter for language-neutral backdrops and sort by vote average
  const neutralBackdrops = details.images.backdrops
    .filter(backdrop => !backdrop.iso_639_1)
    .sort((a, b) => b.vote_average - a.vote_average);

  if (!neutralBackdrops.length) return null;

  // Get unique backdrops for different sections
  const uniqueBackdrops = [...new Set(neutralBackdrops.map(b => b.file_path))];
  
  return {
    hero: uniqueBackdrops[0], // Best rated for hero
    banner: uniqueBackdrops[1] || uniqueBackdrops[0], // Second best for banner
    review: uniqueBackdrops[2] || uniqueBackdrops[0] // Third best for review
  };
};