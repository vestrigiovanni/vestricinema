import React from 'react';
import MovieBanner from './MovieBanner';
import { Movie } from '../types/Movie';
import { MovieDetails } from '../lib/tmdb';
import { isToday, parseISO } from 'date-fns';

interface BannerSectionProps {
  movies: Movie[];
  movieDetails: Record<string, MovieDetails>;
  onMovieSelect: (movie: Movie) => void;
}

const BannerSection: React.FC<BannerSectionProps> = ({ movies, movieDetails, onMovieSelect }) => {
  // Get today's upcoming screenings
  const now = new Date();
  
  // Filter and deduplicate movies
  const uniqueMovies = new Map<string, Movie>();
  
  movies
    .filter(movie => {
      // Check if the movie is today
      if (!isToday(parseISO(movie.Data))) return false;
      
      // Create a Date object for the movie's start time
      const [hours, minutes] = movie['Orario Inizio'].split(':');
      const movieTime = new Date();
      movieTime.setHours(parseInt(hours, 10), parseInt(minutes, 10), 0);
      
      // Only include movies that haven't started yet
      return movieTime > now;
    })
    .sort((a, b) => {
      // Sort by start time
      return a['Orario Inizio'].localeCompare(b['Orario Inizio']);
    })
    .forEach(movie => {
      // Only add the movie if we haven't seen its TMDb ID yet
      if (!uniqueMovies.has(movie['ID Film TMDb'])) {
        uniqueMovies.set(movie['ID Film TMDb'], movie);
      }
    });

  // Take only the first 3 unique upcoming movies
  const bannerMovies = Array.from(uniqueMovies.values()).slice(0, 3);

  // If no upcoming movies today, don't show the section
  if (bannerMovies.length === 0) return null;

  return (
    <section className="container mx-auto px-4 py-12">
      <h2 className="text-2xl font-bold text-white mb-6">Film in Evidenza</h2>
      <div className="grid gap-4 md:gap-6">
        {bannerMovies.map((movie) => {
          const details = movieDetails[movie['ID Film TMDb']];
          if (!details) return null;

          return (
            <MovieBanner
              key={movie.id}
              movie={movie}
              tmdbDetails={details}
              onClick={() => onMovieSelect(movie)}
            />
          );
        })}
      </div>
    </section>
  );
}

export default BannerSection;