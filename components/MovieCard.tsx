import React from 'react';
import { View, Image } from 'react-native';
import { Card, Chip, Text } from 'react-native-paper';
import { Screening } from '../api/supabaseClient';

interface Props {
  screening: Screening;
  onPress?: () => void;
}

export const MovieCard: React.FC<Props> = ({ screening, onPress }) => (
  <Card onPress={onPress} style={{ marginBottom: 8 }}>
    <Card.Title title={screening.Titolo} subtitle={`${screening.Data} ${screening['Orario Inizio']}`} />
    <Card.Content>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <Chip>{screening['Orario Inizio']}</Chip>
        <Chip>{screening['Orario Fine']}</Chip>
      </View>
    </Card.Content>
  </Card>
);
