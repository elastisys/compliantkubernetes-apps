import js from '@eslint/js'

import cypress from 'eslint-plugin-cypress'
import globals from 'globals'
import stylistic from '@stylistic/eslint-plugin'
import tseslint from 'typescript-eslint'
import unicorn from 'eslint-plugin-unicorn'

const rules = {
  // Make cypress checks a bit stricter
  'cypress/no-chained-get': 'error',
  'cypress/no-debug': 'error',
  'cypress/no-pause': 'error',

  // Prevent stylistic from making battle with prettier
  '@stylistic/arrow-parens': 'off',
  '@stylistic/brace-style': 'off',
  '@stylistic/comma-dangle': 'off',
  '@stylistic/indent-binary-ops': 'off',
  '@stylistic/operator-linebreak': 'off',

  // No more backticks where they aren't needed, please
  '@stylistic/quotes': [
    'error',
    'single',
    { avoidEscape: true, allowTemplateLiterals: 'avoidEscape' },
  ],

  // Abbreviations are fine in filenames, not in code
  'unicorn/prevent-abbreviations': ['error', { checkFilenames: false }],

  // Arrow functions can be defined inside other functions
  'unicorn/consistent-function-scoping': ['error', { checkArrowFunctions: false }],

  // This wrecks port numbers
  'unicorn/numeric-separators-style': 'off',
}

export default tseslint.config([
  js.configs.recommended,
  cypress.configs.globals,
  cypress.configs.recommended,
  stylistic.configs.recommended,
  tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname },
      globals: { ...globals.node },
    },
  },
  unicorn.configs.recommended,

  { ignores: ['node_modules/**'] },

  { files: ['**/*.js', '**/*.cjs'], rules: rules },

  { files: ['**/*.ts'], rules: { ...rules, 'no-unused-vars': 'off' } },
])
