import React, { useState, useEffect } from 'react';
import { Ticket, Info, X, Calendar, Clock, Languages, Subtitles, Award, ExternalLink } from 'lucide-react';
import { MovieDetails, getMovieAwards, getMovieRatings, OmdbAwards, OmdbRatings } from '../lib/tmdb';
import { Movie } from '../types/Movie';
import { getMovieBackdrop, getMovieLogo, findPreferredLogo, getMoviePoster } from '../lib/tmdb-image';
import { format, parseISO, isToday } from 'date-fns';
import { it } from 'date-fns/locale';

const IMDbLogo = () => (
  <img 
    src="/imdb-logo.png" 
    alt="IMDb"
    className="w-12 h-6 object-contain"
  />
);

const RottenTomatoesLogo = () => (
  <img 
    src="/rotten-tomatoes-logo.png" 
    alt="Rotten Tomatoes"
    className="w-6 h-6 object-contain"
  />
);

const MetacriticLogo = () => (
  <img 
    src="/metacritic-logo.png" 
    alt="Metacritic"
    className="w-6 h-6 object-contain"
  />
);

interface HeroSectionProps {
  movie: Movie;
  tmdbDetails: MovieDetails;
  onBookTickets: () => void;
  allMovies: Movie[];
}

const HeroSection: React.FC<HeroSectionProps> = ({ movie, tmdbDetails, onBookTickets, allMovies }) => {
  const [showDetails, setShowDetails] = useState(false);
  const [fadeIn, setFadeIn] = useState(false);

  const logoPath = findPreferredLogo(tmdbDetails);
  const backdropUrl = getMovieBackdrop(tmdbDetails.backdrop_path);

  useEffect(() => {
    setFadeIn(false);
    const timer = setTimeout(() => {
      setFadeIn(true);
    }, 50);
    return () => clearTimeout(timer);
  }, [movie.id]);

  const handleAwardsClick = () => {
    if (tmdbDetails.title) {
      const formattedTitle = tmdbDetails.title.toLowerCase().replace(/\s+/g, '-');
      window.open(
        `https://mubi.com/it/films/${formattedTitle}/awards`,
        '_blank'
      );
    }
  };

  return (
    <div className="relative h-[90vh] w-full overflow-hidden">
      <div 
        className={`absolute inset-0 transition-opacity duration-1000 ${
          fadeIn ? 'opacity-100' : 'opacity-0'
        }`}
      >
        <img
          src={backdropUrl}
          alt={movie.Titolo}
          className="w-full h-full object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black via-black/60 to-transparent" />
      </div>

      <div className="relative h-full flex items-center">
        <div className="container mx-auto px-4">
          <div className={`max-w-3xl transition-all duration-1000 ${
            fadeIn ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'
          }`}>
            <div className="mb-6">
              {logoPath ? (
                <img
                  src={getMovieLogo(logoPath)}
                  alt={`Logo di ${movie.Titolo}`}
                  className="w-auto h-28 object-contain"
                  loading="eager"
                />
              ) : (
                <h1 className="text-4xl font-bold text-white mb-2">
                  {movie.Titolo}
                </h1>
              )}
            </div>
            <div className="flex flex-col gap-6 max-w-lg">
              <div className="flex flex-wrap items-start gap-4">
                <button
                  onClick={handleAwardsClick}
                  className="px-6 py-3 bg-white/10 text-white font-semibold rounded-lg hover:bg-white/20 transition-colors"
                >
                  <span className="flex items-center gap-2">
                    <Award className="w-5 h-5" />
                    Premi su MUBI
                  </span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default HeroSection;
