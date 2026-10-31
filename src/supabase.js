import { createClient } from '@supabase/supabase-js'

// The anon/publishable key is meant to be public: Row Level Security protects the data.
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY,
)
