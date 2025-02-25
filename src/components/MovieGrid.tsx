import React from 'react';
import { Movie } from '../types/Movie';
import { getMoviePoster } from '../lib/tmdb-image';
import { Clock, Calendar, List } from 'lucide-react';
import { format, startOfWeek, addDays, parseISO, isToday, isTomorrow, isWithinInterval, endOfWeek } from 'date-fns';
import { it } from 'date-fns/locale';

interface MovieGridProps {
  movies: (Movie & { posterUrl?: string })[];
  onMovieSelect: (movie: Movie) => void;
  isCalendarView: boolean;
  onViewChange: (isCalendar: boolean) => void;
  showToday: boolean;
  showTomorrow: boolean;
  showWeek: boolean;
}

const MovieGrid: React.FC<MovieGridProps> = ({ 
  movies, 
  onMovieSelect, 
  isCalendarView, 
  onViewChange,
  showToday,
  showTomorrow,
  showWeek
}) => {
  const categorizeMovies = () => {
    const now = new Date();
    const endOfCurrentWeek = endOfWeek(now, { weekStartsOn: 1 });

    // Get all today's movies and sort by start time
    const todayMovies = movies
      .filter(movie => isToday(parseISO(movie.Data)))
      .sort((a, b) => a['Orario Inizio'].localeCompare(b['Orario Inizio']));

    return {
      today: todayMovies,
      tomorrow: movies.filter(movie => isTomorrow(parseISO(movie.Data))),
      thisWeek: showWeek ? movies : movies.filter(movie => {
        const date = parseISO(movie.Data);
        return isWithinInterval(date, {
          start: addDays(now, 2),
          end: endOfCurrentWeek
        });
      })
    };
  };

  const getWeekDays = () => {
    const start = startOfWeek(new Date(), { weekStartsOn: 1 });
    return Array.from({ length: 7 }, (_, i) => addDays(start, i));
  };

  const getMoviesForDay = (date: Date) => {
    return movies.filter(movie => {
      const movieDate = parseISO(movie.Data);
      return format(movieDate, 'yyyy-MM-dd') === format(date, 'yyyy-MM-dd');
    }).sort((a, b) => a['Orario Inizio'].localeCompare(b['Orario Inizio']));
  };

  const getMovieStatus = (movie: Movie) => {
    const now = new Date();
    const movieDate = parseISO(movie.Data);
    
    // If the movie is not today, we don't need to check the time
    if (!isToday(movieDate)) {
      return null;
    }

    // Create Date objects for start and end times
    const [startHours, startMinutes] = movie['Orario Inizio'].split(':');
    const [endHours, endMinutes] = movie['Orario Fine'].split(':');
    
    const startTime = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 
      parseInt(startHours), parseInt(startMinutes));
    const endTime = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 
      parseInt(endHours), parseInt(endMinutes));

    if (now < startTime) {
      return null; // Movie hasn't started yet
    } else if (now >= startTime && now <= endTime) {
      return 'in corso'; // Movie is currently screening
    } else {
      return 'terminata'; // Movie has ended
    }
  };

  const MovieCard = ({ movie }: { movie: Movie & { posterUrl?: string } }) => {
    const movieStatus = getMovieStatus(movie);
    const isUnavailable = movieStatus === 'in corso' || movieStatus === 'terminata';
    
    return (
      <button
        onClick={() => onMovieSelect(movie)}
        className={`group relative aspect-[2/3] rounded-lg overflow-hidden text-left ${
          isUnavailable ? 'bg-gray-800' : 'bg-gray-900'
        } hover:ring-2 hover:ring-white/20 transition-all duration-300`}
      >
        {movie.posterUrl && (
          <img
            src={getMoviePoster(movie.posterUrl)}
            alt={movie.Titolo}
            className={`w-full h-full object-cover transform group-hover:scale-105 transition duration-300 ${
              isUnavailable ? 'opacity-50' : ''
            }`}
          />
        )}
        {movie['Sold Out'] && !isUnavailable && (
          <div className="absolute top-4 right-4 rotate-12">
            <div className="bg-red-600 text-white px-4 py-1 font-bold text-sm uppercase tracking-wider shadow-lg">
              Sold Out
            </div>
          </div>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black via-black/50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity">
          <div className="absolute bottom-0 left-0 right-0 p-4 space-y-3">
            <h3 className="text-white font-semibold text-sm sm:text-base line-clamp-2">
              {movie.Titolo}
            </h3>
            <div className="space-y-2 text-gray-300 text-xs sm:text-sm">
              <div className="flex items-center gap-2">
                <Calendar size={14} />
                <span>{format(parseISO(movie.Data), 'EEEE d MMMM', { locale: it })}</span>
              </div>
              <div className="flex items-center gap-2">
                <Clock size={14} />
                <span>{movie['Orario Inizio']}</span>
              </div>
            </div>
            <div className="flex flex-wrap gap-2">
              {movieStatus ? (
                <div className="px-2 py-1 text-xs rounded-full bg-gray-600/80 text-white">
                  Proiezione {movieStatus}
                </div>
              ) : (
                <div className={`px-2 py-1 text-xs rounded-full ${
                  movie['Sold Out'] 
                    ? 'bg-red-600/80 text-white' 
                    : 'bg-green-600/80 text-white'
                }`}>
                  {movie['Sold Out'] ? 'Sold Out' : 'Posti disponibili'}
                </div>
              )}
            </div>
          </div>
        </div>
      </button>
    );
  };

  const MovieSection = ({ title, movies }: { title: string; movies: (Movie & { posterUrl?: string })[] }) => {
    if (movies.length === 0) return null;

    return (
      <div className="mb-12">
        {title && <h2 className="text-2xl font-bold mb-6 text-white">{title}</h2>}
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
          {movies.map((movie) => (
            <MovieCard key={movie.id} movie={movie} />
          ))}
        </div>
      </div>
    );
  };

  const CalendarView = () => {
    const weekDays = getWeekDays();

    return (
      <div className="overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            <tr>
              {weekDays.map((day) => (
                <th key={day.toString()} className="p-4 border-b border-gray-800 text-left min-w-[200px]">
                  <span className="block text-sm text-gray-400">
                    {format(day, 'EEEE', { locale: it })}
                  </span>
                  <span className="block text-lg">
                    {format(day, 'd MMMM', { locale: it })}
                  </span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            <tr>
              {weekDays.map((day) => {
                const dayMovies = getMoviesForDay(day);
                return (
                  <td key={day.toString()} className="p-4 border-t border-gray-800 align-top">
                    {dayMovies.length > 0 ? (
                      <div className="space-y-4">
                        {dayMovies.map((movie) => {
                          const movieStatus = getMovieStatus(movie);
                          const isUnavailable = movieStatus === 'in corso' || movieStatus === 'terminata';
                          
                          return (
                            <div
                              key={movie.id}
                              onClick={() => onMovieSelect(movie)}
                              className={`p-4 rounded-lg cursor-pointer hover:bg-gray-800 transition-colors ${
                                isUnavailable ? 'bg-gray-800' : 'bg-gray-900'
                              }`}
                            >
                              <h3 className="font-medium mb-2">{movie.Titolo}</h3>
                              <div className="flex items-center gap-2 text-sm text-gray-400">
                                <Clock size={14} />
                                <span>{movie['Orario Inizio']}</span>
                              </div>
                              {movieStatus ? (
                                <span className="inline-block mt-2 px-2 py-1 bg-gray-600/20 text-gray-400 text-xs rounded-full">
                                  Proiezione {movieStatus}
                                </span>
                              ) : movie['Sold Out'] ? (
                                <span className="inline-block mt-2 px-2 py-1 bg-red-600/20 text-red-400 text-xs rounded-full">
                                  Sold Out
                                </span>
                              ) : null}
                            </div>
                          );
                        })}
                      </div>
                    ) : (
                      <div className="text-sm text-gray-600">Nessuna proiezione</div>
                    )}
                  </td>
                );
              })}
            </tr>
          </tbody>
        </table>
      </div>
    );
  };

  const { today, tomorrow, thisWeek } = categorizeMovies();

  return (
    <div>
      <div className="flex justify-end mb-6">
        <button
          onClick={() => onViewChange(!isCalendarView)}
          className="flex items-center gap-2 px-4 py-2 bg-white/10 text-white rounded-lg hover:bg-white/20 transition-colors"
        >
          {!isCalendarView ? (
            <>
              <Calendar className="w-4 h-4" />
              Vista Calendario
            </>
          ) : (
            <>
              <List className="w-4 h-4" />
              Vista Normale
            </>
          )}
        </button>
      </div>
      
      <div className="transition-opacity duration-300">
        {!isCalendarView ? (
          <>
            {showToday && <MovieSection title="Oggi al cinema" movies={today} />}
            {showTomorrow && <MovieSection title="Domani al cinema" movies={tomorrow} />}
            {showWeek && <MovieSection title="" movies={movies} />}
          </>
        ) : (
          <CalendarView />
        )}
      </div>
    </div>
  );
};

export default MovieGrid;