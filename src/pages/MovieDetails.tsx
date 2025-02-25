import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { format } from 'date-fns';
import { supabase } from '../lib/supabase';
import { getMovieDetails, getMovieAwards, getMovieRatings, OmdbAwards, OmdbRatings } from '../lib/tmdb';
import { Movie } from '../types/Movie';
import type { MovieDetails as TMDBMovieDetails } from '../lib/tmdb';
import { Award, Ticket, ExternalLink } from 'lucide-react';

const MovieDetails = () => {
  const { id } = useParams<{ id: string }>();
  const [movie, setMovie] = useState<Movie | null>(null);
  const [tmdbDetails, setTmdbDetails] = useState<TMDBMovieDetails | null>(null);
  const [awards, setAwards] = useState<OmdbAwards>({ awards: null, loading: true, error: null });
  const [ratings, setRatings] = useState<OmdbRatings>({
    imdb: { rating: null, votes: null },
    rottenTomatoes: null,
    metacritic: null,
    loading: true,
    error: null
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      if (!id) return;

      try {
        const { data, error } = await supabase
          .from('movies2')
          .select('*')
          .eq('id', id)
          .single();

        if (error || !data) {
          console.error('Error fetching movie:', error);
          return;
        }

        setMovie(data);

        const details = await getMovieDetails(data['ID Film TMDb']);
        setTmdbDetails(details);

        if (details.imdb_id) {
          const [awardsData, ratingsData] = await Promise.all([
            getMovieAwards(details.imdb_id),
            getMovieRatings(
              details.imdb_id,
              details.title,
              details.release_date ? new Date(details.release_date).getFullYear().toString() : undefined
            )
          ]);
          setAwards(awardsData);
          setRatings(ratingsData);
        }
      } catch (error) {
        console.error('Error fetching movie details:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [id]);

  const handleAwardsClick = () => {
    if (tmdbDetails?.imdb_id) {
      window.open(
        `https://www.imdb.com/title/${tmdbDetails.imdb_id}/awards/`,
        '_blank'
      );
    }
  };

  if (loading || !movie || !tmdbDetails) {
    return (
      <div className="flex justify-center items-center h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900"></div>
      </div>
    );
  }

  const director = tmdbDetails.credits.crew.find(crew => crew.job === 'Director');
  const cast = tmdbDetails.credits.cast.slice(0, 5);

  return (
    <div className="max-w-4xl mx-auto px-4 py-8">
      <div className="relative h-96 mb-8">
        <img
          src={`https://image.tmdb.org/t/p/original${tmdbDetails.backdrop_path}`}
          alt={movie.Titolo}
          className="w-full h-full object-cover rounded-lg"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/75 to-transparent rounded-lg"></div>
        <div className="absolute bottom-0 left-0 p-8 text-white">
          <h1 className="text-4xl font-bold mb-2">{movie.Titolo}</h1>
          <p className="text-lg opacity-90">
            {format(new Date(tmdbDetails.release_date), 'yyyy')} • {tmdbDetails.runtime} min
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
        <div className="md:col-span-2 space-y-8">
          <div>
            <h2 className="text-2xl font-bold mb-4">Trama</h2>
            <p className="text-gray-700 leading-relaxed">{tmdbDetails.overview}</p>
          </div>

          <div>
            <h2 className="text-2xl font-bold mb-4">Cast & Crew</h2>
            {director && (
              <p className="mb-4">
                <span className="font-semibold">Regista:</span> {director.name}
              </p>
            )}
            <div>
              <span className="font-semibold">Cast principale:</span>
              <div className="mt-3 grid gap-3">
                {cast.map((actor) => (
                  <div key={actor.id} className="bg-gray-50 p-3 rounded-lg">
                    <p className="font-medium">{actor.name}</p>
                    <p className="text-sm text-gray-600">{actor.character}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Awards and Ratings Section */}
          <div>
            <h2 className="text-2xl font-bold mb-4">Premi e Valutazioni</h2>
            <div className="space-y-4">
              {/* Ratings */}
              {(ratings.imdb.rating || ratings.rottenTomatoes || ratings.metacritic) && (
                <div className="bg-gray-50 rounded-lg p-4">
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    {ratings.imdb.rating && (
                      <div className="bg-white p-3 rounded-lg">
                        <p className="text-sm text-gray-600 mb-1">IMDb</p>
                        <p className="font-medium text-lg">
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
                      <div className="bg-white p-3 rounded-lg">
                        <p className="text-sm text-gray-600 mb-1">Rotten Tomatoes</p>
                        <p className="font-medium text-lg">{ratings.rottenTomatoes}</p>
                      </div>
                    )}
                    {ratings.metacritic && (
                      <div className="bg-white p-3 rounded-lg">
                        <p className="text-sm text-gray-600 mb-1">Metacritic</p>
                        <p className="font-medium text-lg">{ratings.metacritic}/100</p>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* Awards */}
              {awards.awards && (
                <button
                  onClick={handleAwardsClick}
                  className="group w-full bg-yellow-50 border border-yellow-200 rounded-lg p-4 hover:bg-yellow-100 transition-colors text-left"
                >
                  <div className="flex items-center gap-3">
                    <Award className="w-6 h-6 text-yellow-600" />
                    <p className="text-yellow-800 flex-grow">{awards.awards}</p>
                    <ExternalLink className="w-4 h-4 text-yellow-600 opacity-0 -ml-1 transition-all group-hover:opacity-100 group-hover:ml-1" />
                  </div>
                </button>
              )}
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-md h-fit">
          <h2 className="text-xl font-bold mb-4">Informazioni Proiezione</h2>
          <div className="space-y-4">
            <div>
              <p className="font-semibold">Data:</p>
              <p>{format(new Date(movie.Data), 'dd/MM/yyyy')}</p>
            </div>
            <div>
              <p className="font-semibold">Orario:</p>
              <p>{movie['Orario Inizio']} - {movie['Orario Fine']}</p>
            </div>
            <div>
              <p className="font-semibold">Lingua:</p>
              <p>{movie.Lingua}</p>
            </div>
            {movie.Sottotitoli && (
              <div>
                <p className="font-semibold">Sottotitoli:</p>
                <p>{movie.Sottotitoli}</p>
              </div>
            )}
            {movie.Mark && (
              <div className="inline-block px-3 py-1 bg-indigo-100 text-indigo-800 rounded-full">
                {movie.Mark}
              </div>
            )}
            {movie['Sold Out'] ? (
              <div className="bg-red-100 text-red-800 px-4 py-2 rounded-md text-center font-semibold">
                Sold Out
              </div>
            ) : (
              <a
                href={`https://pretix.eu/vestri/npkez/${movie['Pretix Event ID']}`}
                target="_blank"
                rel="noopener noreferrer"
                className="block w-full bg-indigo-600 text-white text-center py-2 rounded-md hover:bg-indigo-700 transition-colors"
              >
                <span className="flex items-center justify-center gap-2">
                  <Ticket className="w-5 h-5" />
                  Acquista Biglietti
                </span>
              </a>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default MovieDetails;