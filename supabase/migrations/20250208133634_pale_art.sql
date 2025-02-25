/*
  # Fix site settings table
  
  1. Table Fixes
    - Drop existing table if exists to avoid conflicts
    - Recreate site_settings table with proper constraints
    - Add trigger for updated_at timestamp
  
  2. Security
    - Enable RLS
    - Add policies for public read access
    - Add policies for authenticated updates
  
  3. Data
    - Ensure default record exists
*/

-- Drop existing policies if they exist
DO $$ 
BEGIN
  -- Drop existing policies
  DROP POLICY IF EXISTS "Allow public read access" ON site_settings;
  DROP POLICY IF EXISTS "Allow authenticated updates" ON site_settings;
EXCEPTION
  WHEN undefined_table THEN
    NULL;
END $$;

-- Drop and recreate the table
DROP TABLE IF EXISTS site_settings;

CREATE TABLE site_settings (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1), -- Ensure only one record
  standby_mode boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_site_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_site_settings_updated_at ON site_settings;
CREATE TRIGGER update_site_settings_updated_at
  BEFORE UPDATE ON site_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_site_settings_updated_at();

-- Insert default record
INSERT INTO site_settings (id, standby_mode)
VALUES (1, false)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE site_settings ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Allow public read access"
  ON site_settings
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Allow authenticated updates"
  ON site_settings
  FOR UPDATE
  TO authenticated
  USING (id = 1)
  WITH CHECK (id = 1);

-- Grant necessary permissions
GRANT SELECT ON site_settings TO public;
GRANT UPDATE ON site_settings TO authenticated;