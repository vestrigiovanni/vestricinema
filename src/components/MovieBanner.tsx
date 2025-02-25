import React from 'react';
import { getMovieLogo, getMovieBackdrop, findPreferredLogo, findBackdrops } from '../lib/tmdb-image';
import { MovieDetails } from '../lib/tmdb';
import { Movie } from '../types/Movie';

interface MovieBannerProps {
  movie: Movie;
  tmdbDetails: MovieDetails;
  onClick: () => void;
}

const MovieBanner: React.FC<MovieBannerProps> = ({ movie, tmdbDetails, onClick }) => {
  const logoPath = findPreferredLogo(tmdbDetails);
  const backdrops = findBackdrops(tmdbDetails);
  const backdropPath = backdrops?.banner || tmdbDetails.backdrop_path;

  if (!backdropPath) return null;

  return (
    <button
      onClick={onClick}
      className="relative w-full h-48 overflow-hidden rounded-lg group"
    >
      {/* Background Image */}
      <div className="absolute inset-0">
        <img
          src={getMovieBackdrop(backdropPath)}
          alt={movie.Titolo}
          className="w-full h-full object-cover transform group-hover:scale-105 transition-transform duration-300"
        />
        <div className="absolute inset-0 bg-gradient-to-r from-black/80 via-black/50 to-transparent" />
      </div>

      {/* Content */}
      <div className="relative h-full flex items-center p-6">
        <div className="max-w-md">
          {logoPath ? (
            <img
              src={getMovieLogo(logoPath)}
              alt={`Logo di ${movie.Titolo}`}
              className="h-16 object-contain mb-3"
            />
          ) : (
            <h3 className="text-2xl font-bold text-white mb-2">{movie.Titolo}</h3>
          )}
          <p className="text-white/80 text-sm line-clamp-2">
            {tmdbDetails.overview}
          </p>
        </div>
      </div>
    </button>
  );
};

export default MovieBanner;