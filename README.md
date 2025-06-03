# CinemaApp

Mobile app built with Expo and React Native to browse screenings and purchase tickets for Vestri cinema.

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```
2. Copy `.env` to your local machine and adjust values if necessary. The file is read by `app.config.ts`.
3. Run the app:
   ```bash
   npm run start
   ```

### iOS / Android
- `npm run ios` – run on iOS simulator
- `npm run android` – run on Android emulator

## Testing
Run unit tests with:
```bash
npm run test
```

## EAS Build
Configure [EAS](https://docs.expo.dev/eas) with your Expo account then run:
```bash
npx eas build -p ios|android
```

