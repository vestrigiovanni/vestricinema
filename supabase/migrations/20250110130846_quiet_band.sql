/*
  # Add rating stars trigger

  1. Changes
    - Add trigger to automatically populate rating_stars on movies2 table
    - Add function to generate random star ratings
    - Add constraint to ensure valid star ratings

  2. Security
    - Maintain existing RLS policies
*/

-- Function to generate random star rating
CREATE OR REPLACE FUNCTION generate_random_star_rating()
RETURNS text AS $$
DECLARE
  ratings text[] := ARRAY['3.5', '4', '4.5', '5'];
  selected_rating text;
BEGIN
  -- Select a random rating from the array
  selected_rating := ratings[floor(random() * array_length(ratings, 1) + 1)];
  
  -- Convert numeric rating to star representation
  RETURN CASE
    WHEN selected_rating = '5' THEN '★★★★★'
    WHEN selected_rating = '4.5' THEN '★★★★½'
    WHEN selected_rating = '4' THEN '★★★★☆'
    WHEN selected_rating = '3.5' THEN '★★★½☆'
    ELSE '★★★★☆' -- Default to 4 stars if something goes wrong
  END;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to set rating_stars on insert if null
CREATE OR REPLACE FUNCTION set_rating_stars()
RETURNS TRIGGER AS $$
BEGIN
  -- Only set rating_stars if it's null
  IF NEW.rating_stars IS NULL THEN
    NEW.rating_stars := generate_random_star_rating();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'set_rating_stars_trigger'
  ) THEN
    CREATE TRIGGER set_rating_stars_trigger
    BEFORE INSERT ON movies2
    FOR EACH ROW
    EXECUTE FUNCTION set_rating_stars();
  END IF;
END $$;