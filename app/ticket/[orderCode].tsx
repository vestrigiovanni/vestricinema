import { useLocalSearchParams, useGlobalSearchParams } from 'expo-router';
import { View, Image } from 'react-native';
import { Text } from 'react-native-paper';
import * as SecureStore from 'expo-secure-store';
import { qrCodeUrl } from '../../api/pretix';

export default function Ticket() {
  const { orderCode } = useLocalSearchParams<{ orderCode: string }>();
  const { secret } = useGlobalSearchParams<{ secret: string }>();

  if (orderCode && secret) {
    SecureStore.setItemAsync(orderCode, secret);
  }

  return (
    <View style={{ alignItems: 'center', padding: 16 }}>
      <Text variant="titleLarge">Order {orderCode}</Text>
      {secret && (
        <Image
          source={{ uri: qrCodeUrl(orderCode, secret) }}
          style={{ width: 200, height: 200, marginTop: 16 }}
        />
      )}
    </View>
  );
}
