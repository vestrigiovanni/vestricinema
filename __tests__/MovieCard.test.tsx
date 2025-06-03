import React from 'react';
import { render } from '@testing-library/react-native';
import { MovieCard } from '../components/MovieCard';
import { Screening } from '../api/supabaseClient';

test('MovieCard snapshot', () => {
  const screening = {
    id: 1,
    Titolo: 'Test',
    Data: '2024-01-01',
    'Orario Inizio': '20:00',
    'Orario Fine': '22:00',
    Lingua: 'IT',
    Sottotitoli: 'EN',
    'Sold Out': false,
    'Pretix Event ID': 1,
    'ID Film TMDb': 123,
  } as Screening;
  const { toJSON } = render(<MovieCard screening={screening} />);
  expect(toJSON()).toMatchSnapshot();
});
