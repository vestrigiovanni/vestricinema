import { useLocalSearchParams, router } from 'expo-router';
import { ScrollView, Image } from 'react-native';
import { Button, Text } from 'react-native-paper';
import { fetchMovie } from '../../api/tmdb';
import { fetchRatings } from '../../api/omdb';
import { createOrder } from '../../api/pretix';
import { useApiQuery } from '../../utils/useApiQuery';
import * as Haptics from 'expo-haptics';

export default function MovieDetails() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { data: movie } = useApiQuery(['movie', id], () => fetchMovie(Number(id)));
  useApiQuery(['ratings', movie?.title], () => fetchRatings(movie!.title), {
    enabled: !!movie,
  });

  const buy = async () => {
    const order = await createOrder();
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    router.push(`/ticket/${order.code}?secret=${order.secret}`);
  };

  if (!movie) return null;

  return (
    <ScrollView contentContainerStyle={{ padding: 16 }}>
      {movie.poster_path && (
        <Image
          source={{ uri: `https://image.tmdb.org/t/p/w500${movie.poster_path}` }}
          style={{ height: 300 }}
        />
      )}
      <Text variant="titleLarge" style={{ marginVertical: 8 }}>
        {movie.title}
      </Text>
      <Text>{movie.overview}</Text>
      <Button mode="contained" onPress={buy} style={{ marginVertical: 16 }}>
        Buy Ticket
      </Button>
    </ScrollView>
  );
}
