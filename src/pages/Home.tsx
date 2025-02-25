import React, { useState, useEffect } from 'react';
import { supabase, checkSupabaseConnection, handleSupabaseError } from '../lib/supabase';
import { Movie } from '../types/Movie';
import { getMovieDetails, getMovieReviews, MovieDetails, MovieReview } from '../lib/tmdb';
import HeroSection from '../components/HeroSection';
import MovieGrid from '../components/MovieGrid';
import BannerSection from '../components/BannerSection';
import ReviewSection from '../components/ReviewSection';
import toast from 'react-hot-toast';

const Home = () => {
  const [movies, setMovies] = useState<(Movie & { posterUrl?: string })[]>([]);
  const [selectedMovie, setSelectedMovie] = useState<Movie | null>(null);
  const [selectedMovieDetails, setSelectedMovieDetails] = useState<MovieDetails | null>(null);
  const [movieDetails, setMovieDetails] = useState<Record<string, MovieDetails>>({});
  const [movieReviews, setMovieReviews] = useState<Record<string, MovieReview[]>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isCalendarView, setIsCalendarView] = useState(false);

  useEffect(() => {
    const fetchMovies = async () => {
      try {
        const isConnected = await checkSupabaseConnection();
        if (!isConnected) {
          throw new Error('Could not connect to the database');
        }

        const { data, error } = await supabase
          .from('movies2')
          .select('*')
          .order('Data', { ascending: true })
          .order('Orario Inizio', { ascending: true });

        if (error) throw error;

        if (!data || data.length === 0) {
          setMovies([]);
          setLoading(false);
          return;
        }

        const details: Record<string, MovieDetails> = {};
        const reviews: Record<string, MovieReview[]> = {};
        
        const moviesWithPosters = await Promise.all(
          data.map(async (movie) => {
            try {
              const movieDetails = await getMovieDetails(movie['ID Film TMDb']);
              details[movie['ID Film TMDb']] = movieDetails;
              
              const movieReviews = await getMovieReviews(movie['ID Film TMDb']);
              if (movieReviews.length > 0) {
                reviews[movie['ID Film TMDb']] = movieReviews;
              }
              
              return {
                ...movie,
                posterUrl: movieDetails.poster_path,
              };
            } catch (error) {
              console.error('Error fetching movie details:', error);
              return movie;
            }
          })
        );

        setMovies(moviesWithPosters);
        setMovieDetails(details);
        setMovieReviews(reviews);
        
        // Set the first upcoming movie as selected
        if (moviesWithPosters.length > 0) {
          const now = new Date();
          const upcomingMovies = moviesWithPosters.filter(movie => {
            const movieDateTime = new Date(`${movie.Data}T${movie['Orario Inizio']}`);
            return movieDateTime >= now;
          });
          
          const firstMovie = upcomingMovies[0] || moviesWithPosters[0];
          setSelectedMovie(firstMovie);
          if (details[firstMovie['ID Film TMDb']]) {
            setSelectedMovieDetails(details[firstMovie['ID Film TMDb']]);
          }
        }
      } catch (error) {
        const errorMessage = handleSupabaseError(error);
        setError(errorMessage);
        toast.error(errorMessage);
      } finally {
        setLoading(false);
      }
    };

    fetchMovies();
  }, []);

  const handleMovieSelect = (movie: Movie) => {
    setSelectedMovie(movie);
    const details = movieDetails[movie['ID Film TMDb']];
    if (details) {
      setSelectedMovieDetails(details);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  };

  const handleBookTickets = () => {
    if (selectedMovie) {
      window.open(
        `https://pretix.eu/vestri/npkez/${selectedMovie['Pretix Event ID']}`,
        '_blank'
      );
    }
  };

  const handleViewChange = (isCalendar: boolean) => {
    setIsCalendarView(isCalendar);
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-white"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen text-white">
        <h2 className="text-2xl font-bold mb-4">Error</h2>
        <p className="text-red-400">{error}</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-black text-white">
      {/* 1. Hero Section */}
      {selectedMovie && selectedMovieDetails && (
        <HeroSection
          movie={selectedMovie}
          tmdbDetails={selectedMovieDetails}
          onBookTickets={handleBookTickets}
          allMovies={movies}
        />
      )}

      <div className="container mx-auto px-4">
        {!isCalendarView ? (
          <>
            {/* 2. Today's Movies */}
            <MovieGrid 
              movies={movies}
              onMovieSelect={handleMovieSelect}
              isCalendarView={false}
              onViewChange={handleViewChange}
              showToday={true}
              showTomorrow={false}
              showWeek={false}
            />

            {/* 3. Featured Movies Banners */}
            <BannerSection
              movies={movies}
              movieDetails={movieDetails}
              onMovieSelect={handleMovieSelect}
            />

            {/* 4. Tomorrow's Movies */}
            <MovieGrid 
              movies={movies}
              onMovieSelect={handleMovieSelect}
              isCalendarView={false}
              onViewChange={handleViewChange}
              showToday={false}
              showTomorrow={true}
              showWeek={false}
            />

            {/* 5. Critics Reviews */}
            <ReviewSection
              reviews={movieReviews}
              movies={movies}
              onMovieSelect={handleMovieSelect}
              movieDetails={movieDetails}
            />

            {/* 6. All Screenings */}
            <div className="mt-12 mb-16">
              <h2 className="text-2xl font-bold mb-6 text-white">Tutte le proiezioni</h2>
              <MovieGrid 
                movies={movies}
                onMovieSelect={handleMovieSelect}
                isCalendarView={false}
                onViewChange={handleViewChange}
                showToday={false}
                showTomorrow={false}
                showWeek={true}
              />
            </div>
          </>
        ) : (
          /* Calendar View */
          <MovieGrid 
            movies={movies}
            onMovieSelect={handleMovieSelect}
            isCalendarView={true}
            onViewChange={handleViewChange}
            showToday={true}
            showTomorrow={true}
            showWeek={true}
          />
        )}
      </div>
    </div>
  );
};

export default Home;