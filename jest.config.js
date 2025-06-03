module.exports = {
  preset: 'jest-expo',
  transform: {
    '^.+\\.tsx?$': 'ts-jest',
  },
  setupFilesAfterEnv: ['@testing-library/react-native/cleanup-after-each'],setupFiles:['<rootDir>/__tests__/setup.ts'],
};
