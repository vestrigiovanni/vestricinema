/*
  # Create review ratings table

  1. New Tables
    - `review_ratings`
      - `id` (uuid, primary key)
      - `tmdb_id` (text, unique)
      - `rating` (numeric, restricted to 3.5, 4.0, 4.5, 5.0)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on `review_ratings` table
    - Add policy for public read access
    - Add policy for service role insert access

  This migration creates a table to store persistent star ratings for movie reviews,
  ensuring consistent ratings across page refreshes.
*/

-- Create the review_ratings table
CREATE TABLE IF NOT EXISTS public.review_ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tmdb_id text UNIQUE NOT NULL,
  rating numeric NOT NULL CHECK (rating IN (3.5, 4.0, 4.5, 5.0)),
  created_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.review_ratings ENABLE ROW LEVEL SECURITY;

-- Create policy for public read access
DO $$ BEGIN
  CREATE POLICY "Allow public read access"
    ON public.review_ratings
    FOR SELECT
    TO public
    USING (true);
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create policy for service role insert
DO $$ BEGIN
  CREATE POLICY "Enable insert for service role only"
    ON public.review_ratings
    FOR INSERT
    TO service_role
    WITH CHECK (true);
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;