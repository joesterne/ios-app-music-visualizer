import js from '@eslint/js';
import globals from 'globals';

export default [
  {
    files: ['Web/**/*.js'],
    languageOptions: { ecmaVersion: 'latest', sourceType: 'script', globals: globals.browser },
    rules: {
      ...js.configs.recommended.rules,
      'no-unused-vars': ['error', { args: 'none', caughtErrors: 'none' }],
    },
  },
  {
    files: ['Web/app.js'],
    languageOptions: { globals: { renderForestWalk: 'readonly', renderMinecraft: 'readonly' } },
  },
  {
    files: ['Web/forest-walk.js', 'Web/minecraft.js'],
    // build-preview.py concatenates the scene scripts with app.js.
    languageOptions: { globals: {
      sceneRenderers: 'readonly', palettes: 'readonly', palette: 'readonly',
      rms: 'readonly', gain: 'readonly', glow: 'readonly', detail: 'readonly',
    } },
  },
];
