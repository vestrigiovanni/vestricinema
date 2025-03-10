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
  const [showShowtimes, setShowShowtimes] = useState(false);
  const [fadeIn, setFadeIn] = useState(false);
  const [awards, setAwards] = useState<OmdbAwards>({ awards: null, loading: true, error: null });
  const [ratings, setRatings] = useState<OmdbRatings>({
    imdb: { rating: null, votes: null },
    rottenTomatoes: null,
    metacritic: null,
    loading: true,
    error: null
  });
  
  const logoPath = findPreferredLogo(tmdbDetails);
  const backdropUrl = getMovieBackdrop(tmdbDetails.backdrop_path);
  const director = tmdbDetails.credits.crew.find(crew => crew.job === 'Director');
  const mainCast = tmdbDetails.credits.cast.slice(0, 5);
  
  const italianOverview = tmdbDetails.translations?.translations?.find(
    t => t.iso_639_1 === 'it'
  )?.data?.overview || tmdbDetails.overview;

  useEffect(() => {
    setFadeIn(false);
    const timer = setTimeout(() => {
      setFadeIn(true);
    }, 50);
    return () => clearTimeout(timer);
  }, [movie.id]);

  useEffect(() => {
    const fetchData = async () => {
      if (tmdbDetails.imdb_id) {
        setAwards({ awards: null, loading: true, error: null });
        setRatings({
          imdb: { rating: null, votes: null },
          rottenTomatoes: null,
          metacritic: null,
          loading: true,
          error: null
        });

        const [awardsData, ratingsData] = await Promise.all([
          getMovieAwards(tmdbDetails.imdb_id),
          getMovieRatings(
            tmdbDetails.imdb_id,
            tmdbDetails.title,
            tmdbDetails.release_date ? new Date(tmdbDetails.release_date).getFullYear().toString() : undefined
          )
        ]);

        setAwards(awardsData);
        setRatings(ratingsData);
      }
    };

    fetchData();
  }, [tmdbDetails.imdb_id]);

  const getMovieStatus = () => {
    const now = new Date();
    const movieDate = parseISO(movie.Data);
    
    if (!isToday(movieDate)) {
      return null;
    }

    const [startHours, startMinutes] = movie['Orario Inizio'].split(':');
    const [endHours, endMinutes] = movie['Orario Fine'].split(':');
    
    const startTime = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 
      parseInt(startHours), parseInt(startMinutes));
    const endTime = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 
      parseInt(endHours), parseInt(endMinutes));

    if (now < startTime) {
      return null;
    } else if (now >= startTime && now <= endTime) {
      return 'in corso';
    } else {
      return 'terminata';
    }
  };

  const movieStatus = getMovieStatus();
  const isUnavailable = movieStatus === 'in corso' || movieStatus === 'terminata';

  const now = new Date();
  const futureShowtimes = allMovies.filter(m => {
    if (m['ID Film TMDb'] !== movie['ID Film TMDb'] || m.id === movie.id) return false;
    const showtime = new Date(`${m.Data}T${m['Orario Inizio']}`);
    return showtime > now;
  }).sort((a, b) => {
    const dateA = new Date(`${a.Data}T${a['Orario Inizio']}`);
    const dateB = new Date(`${b.Data}T${b['Orario Inizio']}`);
    return dateA.getTime() - dateB.getTime();
  });

  const handleShowtimeClick = (selectedMovie: Movie) => {
    window.open(
      `https://pretix.eu/vestri/npkez/${selectedMovie['Pretix Event ID']}`,
      '_blank'
    );
  };

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
      {/* Background Image with Fade */}
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
      
      {/* Content Container */}
      <div className="relative h-full flex items-center">
        <div className="container mx-auto px-4">
          <div className={`max-w-3xl transition-all duration-1000 ${
            fadeIn ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'
          }`}>
            {/* Logo */}
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

            {/* Overview */}
            <div className="mb-8">
              <p className="text-lg text-gray-200 line-clamp-3">
                {italianOverview}
              </p>
            </div>

            {/* Screening Info */}
            <div className="flex flex-wrap gap-6 mb-8 text-white">
              <div className="flex items-center gap-2">
                <Calendar className="w-5 h-5" />
                <span className="text-lg font-medium">
                  {format(new Date(movie.Data), 'EEEE d MMMM', { locale: it })}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <Clock className="w-5 h-5" />
                <span className="text-lg font-medium">{movie['Orario Inizio']}</span>
              </div>
            </div>

            {/* Language and Subtitles */}
            <div className="flex gap-4 mb-8">
              <div className="flex items-center gap-2 text-gray-300">
                <Languages className="w-4 h-4" />
                <span className="text-sm">{movie.Lingua}</span>
              </div>
              {movie.Sottotitoli && (
                <div className="flex items-center gap-2 text-gray-300">
                  <Subtitles className="w-4 h-4" />
                  <span className="text-sm">{movie.Sottotitoli}</span>
                </div>
              )}
            </div>

            {/* Action Buttons */}
            <div className="flex flex-col gap-6 max-w-lg">
              <div className="flex flex-wrap items-start gap-4">
                {isUnavailable ? (
                  <div className="px-6 py-3 bg-gray-600 text-white font-semibold rounded-lg cursor-not-allowed">
                    <span className="flex items-center gap-2">
                      <Clock className="w-5 h-5" />
                      Proiezione {movieStatus}
                    </span>
                  </div>
                ) : !movie['Sold Out'] ? (
                  <button
                    onClick={onBookTickets}
                    className="px-6 py-3 bg-white text-black font-semibold rounded-lg hover:bg-gray-200 transition-colors"
                  >
                    <span className="flex items-center gap-2">
                      <Ticket className="w-5 h-5" />
                      Acquista Biglietti
                    </span>
                  </button>
                ) : (
                  <div className="px-6 py-3 bg-red-600 text-white font-semibold rounded-lg">
                    Sold Out
                  </div>
                )}
                <div className="flex flex-col gap-3">
                  <button
                    onClick={() => setShowDetails(true)}
                    className="px-6 py-3 bg-white/10 text-white font-semibold rounded-lg hover:bg-white/20 transition-colors"
                  >
                    <span className="flex items-center gap-2">
                      <Info className="w-5 h-5" />
                      Dettagli
                    </span>
                  </button>
                  {futureShowtimes.length > 0 && (
                    <button
                      onClick={() => setShowShowtimes(true)}
                      className="px-6 py-3 bg-white/10 text-white font-semibold rounded-lg hover:bg-white/20 transition-colors"
                    >
                      <span className="flex items-center gap-2">
                        <Calendar className="w-5 h-5" />
                        Altri Orari
                      </span>
                    </button>
                  )}
                </div>
              </div>

              {/* Awards and Ratings Section */}
              <div className="space-y-4">
                {/* Awards */}
                {awards.awards && (
                  <button
                    onClick={handleAwardsClick}
                    className="group flex items-center gap-2 text-gray-300 transition-all duration-300 hover:text-white w-full"
                  >
                    <Award className="w-5 h-5 text-yellow-400 shrink-0" />
                    <span className="text-sm">{awards.awards}</span>
                    <ExternalLink className="w-4 h-4 opacity-0 -ml-1 transition-all group-hover:opacity-100 group-hover:ml-1 shrink-0" />
                  </button>
                )}

                {/* Ratings */}
                {(ratings.imdb.rating || ratings.rottenTomatoes || ratings.metacritic) && (
                  <div className="flex flex-wrap gap-3">
                    {ratings.imdb.rating && (
                      <div className="bg-black/30 backdrop-blur-sm px-3 py-2 rounded-lg flex items-center gap-3">
                        <IMDbLogo />
                        <div>
                          <p className="text-white font-medium leading-tight">
                            {ratings.imdb.rating}/10
                          </p>
                          {ratings.imdb.votes && (
                            <p className="text-xs text-gray-400">
                              {parseInt(ratings.imdb.votes.replace(/,/g, '')).toLocaleString()} voti
                            </p>
                          )}
                        </div>
                      </div>
                    )}
                    {ratings.rottenTomatoes && (
                      <div className="bg-black/30 backdrop-blur-sm px-3 py-2 rounded-lg flex items-center gap-3">
                        <RottenTomatoesLogo />
                        <div>
                          <p className="text-white font-medium leading-tight">
                            {ratings.rottenTomatoes}
                          </p>
                          <p className="text-xs text-gray-400">Tomatometer</p>
                        </div>
                      </div>
                    )}
                    {ratings.metacritic && (
                      <div className="bg-black/30 backdrop-blur-sm px-3 py-2 rounded-lg flex items-center gap-3">
                        <MetacriticLogo />
                        <div>
                          <p className="text-white font-medium leading-tight">
                            {ratings.metacritic}/100
                          </p>
                          <p className="text-xs text-gray-400">Metascore</p>
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Details Modal */}
      {showDetails && (
        <div className="fixed inset-0 bg-black/90 flex items-center justify-center z-50 p-4 overflow-y-auto">
          <div className="bg-gray-900 rounded-2xl max-w-5xl w-full my-8">
            <div className="flex flex-col md:flex-row max-h-[85vh]">
              {/* Poster - Hidden on mobile, shown on md and up */}
              <div className="hidden md:block md:w-1/3 relative">
                <img
                  src={getMoviePoster(tmdbDetails.poster_path)}
                  alt={movie.Titolo}
                  className="w-full h-full object-cover rounded-l-2xl"
                />
              </div>
              
              {/* Content */}
              <div className="flex-1 p-8 overflow-y-auto">
                {/* Mobile Poster - Shown only on mobile */}
                <div className="md:hidden w-1/2 float-right ml-4 mb-4">
                  <img
                    src={getMoviePoster(tmdbDetails.poster_path)}
                    alt={movie.Titolo}
                    className="w-full rounded-lg"
                  />
                </div>
                
                <div className="flex justify-between items-start mb-8">
                  <h2 className="text-3xl font-bold text-white">{movie.Titolo}</h2>
                  <button
                    onClick={() => setShowDetails(false)}
                    className="text-gray-400 hover:text-white transition-colors p-2"
                  >
                    <X className="w-6 h-6" />
                  </button>
                </div>
                
                <div className="space-y-8 text-gray-300">
                  <div>
                    <h3 className="text-sm uppercase tracking-wider text-gray-400 mb-3">Trama</h3>
                    <p className="leading-relaxed text-lg">{italianOverview}</p>
                  </div>

                  <div className="grid grid-cols-2 gap-6">
                    <div>
                      <h3 className="text-sm uppercase tracking-wider text-gray-400 mb-1">Regista</h3>
                      <p className="text-lg font-medium text-white">{director?.name || 'N/A'}</p>
                    </div>
                    <div>
                      <h3 className="text-sm uppercase tracking-wider text-gray-400 mb-1">Anno</h3>
                      <p className="text-lg font-medium text-white">
                        {new Date(tmdbDetails.release_date).getFullYear()}
                      </p>
                    </div>
                    <div>
                      <h3 className="text-sm uppercase tracking-wider text-gray-400 mb-1">Durata</h3>
                      <p className="text-lg font-medium text-white">{tmdbDetails.runtime} minuti</p>
                    </div>
                    <div>
                      <h3 className="text-sm uppercase tracking-wider text-gray-400 mb-1">Orario</h3>
                      <p className="text-lg font-medium text-white">
                        {movie['Orario Inizio']} - {movie['Orario Fine']}
                      </p>
                    </div>
                  </div>
                  
                  <div>
                    <h3 className="text-sm uppercase tracking-wider text-gray-400 mb-3">Cast Principale</h3>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      {mainCast.map(actor => (
                        <div key={actor.id} className="bg-white/5 rounded-lg p-3">
                          <p className="font-medium text-white">{actor.name}</p>
                          <p className="text-sm text-gray-400">{actor.character}</p>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Awards and Ratings in Modal */}
                  <div>
                    <h3 className="text-sm uppercase tracking-wider text-gray-400 mb-3">
                      Premi e Valutazioni
                    </h3>
                    <div className="space-y-4">
                      {awards.awards && (
                        <button
                          onClick={handleAwardsClick}
                          className="group flex items-center gap-2 bg-white/5 rounded-lg p-3 w-full hover:bg-white/10 transition-colors text-left"
                        >
                          <Award className="w-5 h-5 text-yellow-400" />
                          <p className="text-white flex-grow">{awards.awards}</p>
                          <ExternalLink className="w-4 h-4 opacity-0 -ml-1 transition-all group-hover:opacity-100 group-hover:ml-1" />
                        </button>
                      )}

                      {(ratings.imdb.rating || ratings.rottenTomatoes || ratings.metacritic) && (
                        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                          {ratings.imdb.rating && (
                            <div className="bg-white/5 rounded-lg p-3">
                              <div className="flex items-center gap-2 mb-2">
                                <IMDbLogo />
                              </div>
                              <p className="text-lg font-medium text-white">
                                {ratings.imdb.rating}/10
                              </p>
                              {ratings.imdb.votes && (
                                <p className="text-sm text-gray-500 mt-1">
                                  {parseInt(ratings.imdb.votes.replace(/,/g, '')).toLocaleString()} voti
                                </p>
                              )}
                            </div>
                          )}
                          {ratings.rottenTomatoes && (
                            <div className="bg-white/5 rounded-lg p-3">
                              <div className="flex items-center gap-2 mb-2">
                                <RottenTomatoesLogo />
                              </div>
                              <p className="text-lg font-medium text-white">
                                {ratings.rottenTomatoes}
                              </p>
                              <p className="text-sm text-gray-500 mt-1">Tomatometer</p>
                            </div>
                          )}
                          {ratings.metacritic && (
                            <div className="bg-white/5 rounded-lg p-3">
                              <div className="flex items-center gap-2 mb-2">
                                <MetacriticLogo />
                              </div>
                              <p className="text-lg font-medium text-white">
                                {ratings.metacritic}/100
                              </p>
                              <p className="text-sm text-gray-500 mt-1">Metascore</p>
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                  </div>

                  {isUnavailable ? (
                    <div className="w-full bg-gray-600 text-white font-semibold py-3 rounded-lg text-center cursor-not-allowed">
                      <span className="flex items-center justify-center gap-2">
                        <Clock className="w-5 h-5" />
                        Proiezione {movieStatus}
                      </span>
                    </div>
                  ) : !movie['Sold Out'] ? (
                    <button
                      onClick={onBookTickets}
                      className="w-full bg-white text-black font-semibold py-3 rounded-lg hover:bg-gray-200 transition-colors"
                    >
                      <span className="flex items-center justify-center gap-2">
                        <Ticket className="w-5 h-5" />
                        Acquista Biglietti
                      </span>
                    </button>
                  ) : (
                    <div className="w-full bg-red-600 text-white font-semibold py-3 rounded-lg text-center">
                      Sold Out
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Other Showtimes Modal */}
      {showShowtimes && (
        <div className="fixed inset-0 bg-black/90 flex items-center justify-center z-50 p-4">
          <div className="bg-gray-900 rounded-2xl max-w-2xl w-full">
            <div className="p-8">
              <div className="flex justify-between items-center mb-8">
                <h2 className="text-3xl font-bold text-white">Altri Orari</h2>
                <button
                  onClick={() => setShowShowtimes(false)}
                  className="text-gray-400 hover:text-white transition-colors p-2"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>

              <div className="max-h-[60vh] overflow-y-auto pr-4 space-y-4 scrollbar-thin scrollbar-thumb-gray-700 scrollbar-track-transparent">
                {futureShowtimes.map((showtime) => (
                  <button
                    key={showtime.id}
                    onClick={() => handleShowtimeClick(showtime)}
                    disabled={showtime['Sold Out']}
                    className={`w-full p-4 rounded-lg text-left transition-colors ${
                      showtime['Sold Out']
                        ? 'bg-red-900/20 cursor-not-allowed'
                        : 'bg-white/5 hover:bg-white/10'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="text-white font-medium">
                          {format(new Date(showtime.Data), 'EEEE d MMMM', { locale: it })}
                        </p>
                        <p className="text-gray-400">
                          {showtime['Orario Inizio']} - {showtime['Orario Fine']}
                        </p>
                      </div>
                      {showtime['Sold Out'] ? (
                        <span className="px-3 py-1 bg-red-600/20 text-red-400 rounded-full text-sm">
                          Sold Out
                        </span>
                      ) : (
                        <span className="text-white/60">Prenota →</span>
                      )}
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default HeroSection;