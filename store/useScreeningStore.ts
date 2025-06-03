import { create } from 'zustand';
import { Screening } from '../api/supabaseClient';

interface State {
  screenings: Screening[];
  favorites: number[];
  setScreenings: (s: Screening[]) => void;
  toggleFavorite: (id: number) => void;
}

export const useScreeningStore = create<State>((set, get) => ({
  screenings: [],
  favorites: [],
  setScreenings: (s) => set({ screenings: s }),
  toggleFavorite: (id) =>
    set({
      favorites: get().favorites.includes(id)
        ? get().favorites.filter((f) => f !== id)
        : [...get().favorites, id],
    }),
}));
