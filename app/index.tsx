import { useEffect } from 'react';
import { FlatList } from 'react-native';
import { useNavigation } from 'expo-router';
import { fetchScreenings } from '../api/supabaseClient';
import { MovieCard } from '../components/MovieCard';
import { useScreeningStore } from '../store/useScreeningStore';
import { useApiQuery } from '../utils/useApiQuery';

export default function HomeScreen() {
  const setScreenings = useScreeningStore((s) => s.setScreenings);
  const { data } = useApiQuery(['screenings'], fetchScreenings);
  const navigation = useNavigation();

  useEffect(() => {
    if (data) setScreenings(data);
  }, [data]);

  return (
    <FlatList
      data={data}
      keyExtractor={(item) => item.id.toString()}
      renderItem={({ item }) => (
        <MovieCard
          screening={item}
          onPress={() => navigation.push(`/movie/${item['ID Film TMDb']}`)}
        />
      )}
    />
  );
}
