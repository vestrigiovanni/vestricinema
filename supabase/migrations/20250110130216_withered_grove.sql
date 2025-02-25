/*
  # Add rating_stars field to review_ratings table

  1. Changes
    - Add `rating_stars` text field to `review_ratings` table
    - This field will store textual representation of ratings

  2. Security
    - Inherits existing RLS policies from the table
*/

DO $$ 
BEGIN
  -- Add rating_stars column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'review_ratings' 
    AND column_name = 'rating_stars'
  ) THEN
    ALTER TABLE public.review_ratings 
    ADD COLUMN rating_stars text;
  END IF;
END $$;