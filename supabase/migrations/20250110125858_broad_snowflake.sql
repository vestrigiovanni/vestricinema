/*
  # Add review ratings table

  1. New Tables
    - `review_ratings`
      - `id` (uuid, primary key)
      - `tmdb_id` (text, unique)
      - `rating` (numeric)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on `review_ratings` table
    - Add policy for public read access
*/

CREATE TABLE IF NOT EXISTS review_ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tmdb_id text UNIQUE NOT NULL,
  rating numeric NOT NULL CHECK (rating IN (3.5, 4.0, 4.5, 5.0)),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE review_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access"
  ON review_ratings
  FOR SELECT
  TO public
  USING (true);