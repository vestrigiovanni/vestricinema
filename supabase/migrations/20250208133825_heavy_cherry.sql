/*
  # Remove standby column from movies2 table

  1. Changes
    - Remove the `standby` column from `movies2` table since we're using the `site_settings` table for standby mode
*/

DO $$ 
BEGIN
  -- Remove standby column if it exists
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'movies2' 
    AND column_name = 'standby'
  ) THEN
    ALTER TABLE movies2 DROP COLUMN standby;
  END IF;
END $$;