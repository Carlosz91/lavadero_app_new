module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.js'],
  verbose: true,
  forceExit: true,
  detectOpenHandles: true,
  collectCoverageFrom: [
    'controllers/**/*.js',
    'middlewares/**/*.js',
    'models/**/*.js',
    'routes/**/*.js',
    'utils/**/*.js',
  ],
  // Umbral mínimo: evita que la cobertura retroceda sin que nadie lo note.
  coverageThreshold: {
    global: { statements: 70, lines: 70, functions: 70, branches: 50 },
  },
};
