/*
  # Add site settings table
  
  1. New Tables
    - `site_settings`
      - `id` (integer, primary key, default 1)
      - `standby_mode` (boolean, default false)
      - `updated_at` (timestamptz, default now)
  
  2. Security
    - Enable RLS on `site_settings` table
    - Add policies for public read access
    - Add policies for authenticated updates
*/

-- Create the site settings table
CREATE TABLE IF NOT EXISTS site_settings (
  id integer PRIMARY KEY DEFAULT 1,
  standby_mode boolean DEFAULT false,
  updated_at timestamptz DEFAULT now()
);

-- Insert default record
INSERT INTO site_settings (id, standby_mode)
VALUES (1, false)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE site_settings ENABLE ROW LEVEL SECURITY;

-- Create policy for public read access
CREATE POLICY "Allow public read access"
  ON site_settings
  FOR SELECT
  TO public
  USING (true);

-- Create policy for authenticated updates
CREATE POLICY "Allow authenticated updates"
  ON site_settings
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);