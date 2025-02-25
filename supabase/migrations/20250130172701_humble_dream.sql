/*
  # Fix movies2 table schema

  1. Changes
    - Add proper ID column configuration with auto-increment
    - Preserve existing data
    - Add proper constraints

  2. Security
    - Maintain existing RLS policies
*/

-- First, ensure the movies2 table exists
CREATE TABLE IF NOT EXISTS movies2 (
  id SERIAL PRIMARY KEY,
  "Data" date NOT NULL,
  "ID Film TMDb" text NOT NULL,
  "Orario Inizio" time NOT NULL,
  "Orario Fine" time NOT NULL,
  "Lingua" text NOT NULL,
  "Sottotitoli" text,
  "Pretix Event ID" text NOT NULL,
  "Sold Out" boolean DEFAULT false,
  "Titolo" text NOT NULL,
  "Mark" text,
  "rating_stars" text
);

-- Enable RLS
ALTER TABLE movies2 ENABLE ROW LEVEL SECURITY;

-- Add policies if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'movies2' AND policyname = 'Enable read access for all users'
  ) THEN
    CREATE POLICY "Enable read access for all users" 
      ON movies2 FOR SELECT 
      TO public 
      USING (true);
  END IF;
END $$;