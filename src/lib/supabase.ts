import { createClient } from '@supabase/supabase-js';

// Ensure we have the required environment variables
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://hhekubqxrwofgmtodmny.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhoZWt1YnF4cndvZmdtdG9kbW55Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzEyNDE0MzUsImV4cCI6MjA0NjgxNzQzNX0.MCmvUt8lizKkDVxaQ25F74oaxia90Oy-fRXp1orS8lU';

// Create a single instance of the Supabase client with improved configuration
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
  global: {
    headers: { 'x-application-name': 'vestri-cinema' },
  },
  db: {
    schema: 'public',
  },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
  // Add request timeout and retry configuration
  fetch: (url, options = {}) => {
    return fetch(url, {
      ...options,
      // Set a reasonable timeout
      signal: AbortSignal.timeout(10000), // 10 second timeout
      // Add retry headers
      headers: {
        ...options.headers,
        'x-retry-after': '1',  // Retry after 1 second
        'x-retry-limit': '3',  // Maximum 3 retries
      }
    });
  }
});

// Improved connection check function with better error handling
export const checkSupabaseConnection = async (retries = 3, delay = 1000): Promise<boolean> => {
  for (let i = 0; i < retries; i++) {
    try {
      // Use a simple query to test connection
      const { data, error } = await supabase
        .from('movies2')
        .select('id')
        .limit(1)
        .maybeSingle();

      if (error) {
        // Log specific error for debugging
        console.warn(`Supabase connection attempt ${i + 1} failed:`, {
          code: error.code,
          message: error.message,
          details: error.details
        });
        
        // If this isn't the last retry, wait before trying again
        if (i < retries - 1) {
          await new Promise(resolve => setTimeout(resolve, delay * (i + 1))); // Exponential backoff
          continue;
        }
      }

      // Connection successful
      return true;
    } catch (error) {
      console.error(`Supabase connection attempt ${i + 1} failed with exception:`, error);
      
      // If this isn't the last retry, wait before trying again
      if (i < retries - 1) {
        await new Promise(resolve => setTimeout(resolve, delay * (i + 1))); // Exponential backoff
        continue;
      }
    }
  }

  // All retries failed
  return false;
};

// Enhanced error handler with more specific error cases
export const handleSupabaseError = (error: any): string => {
  if (!error) return 'Unknown error occurred';
  
  // Network related errors
  if (error instanceof TypeError && error.message.includes('NetworkError')) {
    return 'Network connection error. Please check your internet connection.';
  }

  // Timeout errors
  if (error.name === 'TimeoutError' || error.message.includes('timeout')) {
    return 'Request timed out. Please try again.';
  }

  // Common Supabase error codes
  switch (error.code) {
    case 'PGRST301':
      return 'Database connection failed. Please try again later.';
    case '23505':
      return 'A record with this information already exists.';
    case '42P01':
      return 'The requested data table does not exist.';
    case '42703':
      return 'Invalid column name in query.';
    case 'PGRST116':
      return 'Invalid query parameters.';
    default:
      if (error.message?.includes('JWT')) {
        return 'Authentication error. Please try logging in again.';
      }
      // Return the original error message if we don't have a specific handler
      return error.message || 'An unexpected error occurred';
  }
};