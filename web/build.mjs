// build.mjs
import * as esbuild from 'esbuild';
import { NodeGlobalsPolyfillPlugin } from '@esbuild-plugins/node-globals-polyfill';
import { NodeModulesPolyfillPlugin } from '@esbuild-plugins/node-modules-polyfill';

await esbuild.build({
  entryPoints: ['wallet-selector.source.js'],
  bundle: true,
  outfile: 'wallet-selector.bundle.js',
  format: 'iife',
  globalName: 'NearWalletSelectorInit',
  platform: 'browser',
  define: {
    'global': 'globalThis',
    'process.env.NODE_ENV': '"production"',
  },
  plugins: [
    NodeModulesPolyfillPlugin(),
    NodeGlobalsPolyfillPlugin({
      buffer: true,
      process: true,
    }),
  ],
  logLevel: 'info',
});

console.log('✅ Bundle created successfully!');
