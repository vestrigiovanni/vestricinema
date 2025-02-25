import React, { useState, useEffect } from 'react';
import { Star } from 'lucide-react';
import { MovieReview, MovieDetails } from '../lib/tmdb';
import { Movie } from '../types/Movie';
import { getMovieBackdrop, findBackdrops } from '../lib/tmdb-image';
import { isTomorrow, parseISO } from 'date-fns';
import { supabase, checkSupabaseConnection, handleSupabaseError } from '../lib/supabase';

interface ReviewSectionProps {
  reviews: Record<string, MovieReview[]>;
  movies: Movie[];
  onMovieSelect: (movie: Movie) => void;
  movieDetails: Record<string, MovieDetails>;
}

const ReviewSection: React.FC<ReviewSectionProps> = ({ reviews, movies, onMovieSelect, movieDetails }) => {
  const [movieRatings, setMovieRatings] = useState<Record<string, string>>({});
  const [isLoadingRatings, setIsLoadingRatings] = useState(true);

  // Get tomorrow's movies and deduplicate them by TMDb ID
  const uniqueTomorrowMovies = new Map<string, Movie>();
  
  movies
    .filter(movie => isTomorrow(parseISO(movie.Data)))
    .sort((a, b) => a['Orario Inizio'].localeCompare(b['Orario Inizio']))
    .forEach(movie => {
      if (!uniqueTomorrowMovies.has(movie['ID Film TMDb'])) {
        uniqueTomorrowMovies.set(movie['ID Film TMDb'], movie);
      }
    });

  // Convert back to array and take first 3 unique movies
  const moviesToShow = Array.from(uniqueTomorrowMovies.values());

  // Only show section if we have movies with reviews
  const moviesWithReviews = moviesToShow.filter(movie => 
    reviews[movie['ID Film TMDb']]?.length > 0
  );

  useEffect(() => {
    const fetchRatings = async () => {
      if (moviesWithReviews.length === 0) {
        setIsLoadingRatings(false);
        return;
      }

      let retryCount = 0;
      const maxRetries = 3;
      const baseDelay = 1000;

      while (retryCount < maxRetries) {
        try {
          // Check Supabase connection first
          const isConnected = await checkSupabaseConnection();
          if (!isConnected) {
            throw new Error('Database connection failed');
          }

          // Get all TMDb IDs
          const tmdbIds = moviesWithReviews.map(movie => movie['ID Film TMDb']);

          // Get existing ratings
          const { data: movieData, error: movieError } = await supabase
            .from('movies2')
            .select('"ID Film TMDb", rating_stars')
            .in('"ID Film TMDb"', tmdbIds);

          if (movieError) {
            console.warn('Error fetching from movies2:', handleSupabaseError(movieError));
            throw movieError;
          }

          // Create a map of TMDb ID to rating stars
          const ratings: Record<string, string> = {};
          const availableRatings = ['★★★½☆', '★★★★☆', '★★★★½', '★★★★★'];
          
          // Process existing ratings
          if (movieData) {
            for (const movie of movieData) {
              if (movie['ID Film TMDb']) {
                if (movie.rating_stars) {
                  // Use existing rating
                  ratings[movie['ID Film TMDb']] = movie.rating_stars;
                } else {
                  // Assign new random rating
                  const randomRating = availableRatings[Math.floor(Math.random() * availableRatings.length)];
                  ratings[movie['ID Film TMDb']] = randomRating;
                  
                  // Update the rating in Supabase
                  const { error: updateError } = await supabase
                    .from('movies2')
                    .update({ rating_stars: randomRating })
                    .eq('"ID Film TMDb"', movie['ID Film TMDb']);
                  
                  if (updateError) {
                    console.warn('Error updating rating:', handleSupabaseError(updateError));
                  }
                }
              }
            }
          }

          // Assign ratings for any movies that don't have them yet
          for (const movie of moviesWithReviews) {
            if (!ratings[movie['ID Film TMDb']]) {
              const randomRating = availableRatings[Math.floor(Math.random() * availableRatings.length)];
              ratings[movie['ID Film TMDb']] = randomRating;
              
              // Update the rating in Supabase
              const { error: updateError } = await supabase
                .from('movies2')
                .update({ rating_stars: randomRating })
                .eq('"ID Film TMDb"', movie['ID Film TMDb']);
              
              if (updateError) {
                console.warn('Error updating rating:', handleSupabaseError(updateError));
              }
            }
          }

          setMovieRatings(ratings);
          setIsLoadingRatings(false);
          return; // Success - exit the retry loop
        } catch (error) {
          console.warn(`Attempt ${retryCount + 1} failed:`, error);
          
          if (retryCount === maxRetries - 1) {
            // Use default ratings if all retries fail
            const defaultRatings: Record<string, string> = {};
            moviesWithReviews.forEach(movie => {
              defaultRatings[movie['ID Film TMDb']] = '★★★★☆';
            });
            setMovieRatings(defaultRatings);
            setIsLoadingRatings(false);
            return;
          }

          // Exponential backoff for retry
          const delay = baseDelay * Math.pow(2, retryCount);
          await new Promise(resolve => setTimeout(resolve, delay));
          retryCount++;
        }
      }
    };

    fetchRatings();
  }, [moviesWithReviews]);

  if (moviesWithReviews.length === 0) return null;

  const StarRating = ({ stars }: { stars: string }) => {
    return (
      <div className="flex items-center gap-1">
        {[...Array(5)].map((_, i) => {
          const starChar = stars[i] || '☆';
          return (
            <span
              key={i}
              className={`w-4 h-4 ${
                starChar === '★' 
                  ? 'text-yellow-400'
                  : starChar === '½' 
                    ? 'text-yellow-400'
                    : 'text-gray-600'
              }`}
            >
              {starChar}
            </span>
          );
        })}
      </div>
    );
  };

  // Get one review per movie, up to 3 movies
  const reviewsToShow = moviesWithReviews.slice(0, 3).map(movie => ({
    movie,
    review: reviews[movie['ID Film TMDb']][0],
    details: movieDetails[movie['ID Film TMDb']]
  }));

  return (
    <section className="container mx-auto px-4 py-12">
      <h2 className="text-2xl font-bold text-white mb-6">Dalla Critica</h2>
      <div className="grid gap-4 md:gap-6">
        {reviewsToShow.map(({ movie, review, details }) => {
          if (!details) return null;

          const backdrops = findBackdrops(details);
          const backdropPath = backdrops?.review || details.backdrop_path;
          if (!backdropPath) return null;

          const stars = movieRatings[movie['ID Film TMDb']] || '★★★★☆';

          return (
            <button
              key={`${movie.id}-${review.id}`}
              onClick={() => onMovieSelect(movie)}
              className="relative w-full h-48 overflow-hidden rounded-lg group text-left"
            >
              <div className="absolute inset-0">
                <img
                  src={getMovieBackdrop(backdropPath)}
                  alt={movie.Titolo}
                  className="w-full h-full object-cover transform group-hover:scale-105 transition-transform duration-300"
                />
                <div className="absolute inset-0 bg-gradient-to-r from-black/90 via-black/70 to-transparent" />
              </div>

              <div className="relative h-full flex flex-col justify-center p-6">
                <div className="max-w-2xl">
                  <div className="flex items-center gap-2 mb-4">
                    {isLoadingRatings ? (
                      <div className="animate-pulse bg-white/20 h-4 w-24 rounded" />
                    ) : (
                      <StarRating stars={stars} />
                    )}
                  </div>
                  <p className="text-white/90 text-lg font-medium mb-3 line-clamp-3">
                    {review.content}
                  </p>
                  <cite className="text-sm text-white/70 not-italic">
                    <span className="font-medium text-white">{review.publication}</span>
                    <span className="mx-2">·</span>
                    <span className="text-white/60">{movie.Titolo}</span>
                  </cite>
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
};

export default ReviewSection;