const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const webpack = require('webpack');
const CopyWebpackPlugin = require('copy-webpack-plugin');

module.exports = (env, argv) => {
  const isProduction = argv.mode === 'production';

  return {
    entry: './index.web.js',
    output: {
      path: path.resolve(__dirname, 'dist'),
      filename: isProduction ? '[name].[contenthash].js' : '[name].js',
      chunkFilename: isProduction ? '[name].[contenthash].chunk.js' : '[name].chunk.js',
      clean: true,
    },
    optimization: {
      splitChunks: {
        chunks: 'all',
        cacheGroups: {
          default: false,
          vendors: false,
          // Vendor chunk
          vendor: {
            name: 'vendor',
            chunks: 'all',
            test: /node_modules/,
            priority: 20,
          },
          // Common chunk
          common: {
            name: 'common',
            minChunks: 2,
            chunks: 'all',
            priority: 10,
            reuseExistingChunk: true,
            enforce: true,
          },
        },
      },
    },
    module: {
      rules: [
        {
          test: /\.(js|jsx)$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader',
            options: {
              plugins: isProduction ? [
                ['transform-remove-console', { exclude: ['error', 'warn'] }]
              ] : []
            }
          },
        },
        {
          test: /\.(png|jpg|jpeg|gif|svg)$/i,
          type: 'asset/resource'
        }
      ],
    },
    plugins: [
      new HtmlWebpackPlugin({
        template: './index.html',
      }),
      // Copy favicon and cursorGlow.js to dist
      new CopyWebpackPlugin({
        patterns: [
          {
            from: path.resolve(__dirname, 'public', '*.png'),
            to: path.resolve(__dirname, 'dist', '[name][ext]'),
            noErrorOnMissing: true,
          },
          {
            from: path.resolve(__dirname, 'public', '*.svg'),
            to: path.resolve(__dirname, 'dist', '[name][ext]'),
            noErrorOnMissing: true,
          },
          {
            from: path.resolve(__dirname, 'cursorGlow.js'),
            to: path.resolve(__dirname, 'dist', 'cursorGlow.js'),
            noErrorOnMissing: true,
          },
          // Fluid simulation files
          {
            from: path.resolve(__dirname, 'fluid-sim.js'),
            to: path.resolve(__dirname, 'dist', 'fluid-sim.js'),
            noErrorOnMissing: true,
          },
          {
            from: path.resolve(__dirname, 'dat.gui.min.js'),
            to: path.resolve(__dirname, 'dist', 'dat.gui.min.js'),
            noErrorOnMissing: true,
          },
          {
            from: path.resolve(__dirname, 'LDR_LLL1_0.png'),
            to: path.resolve(__dirname, 'dist', 'LDR_LLL1_0.png'),
            noErrorOnMissing: true,
          },
        ],
      }),
      // Inject environment variables at build time
      new webpack.DefinePlugin({
        'process.env.REACT_APP_API_URL': JSON.stringify(process.env.REACT_APP_API_URL || ''),
        'process.env.NODE_ENV': JSON.stringify(isProduction ? 'production' : 'development'),
      }),
    ],
    resolve: {
      extensions: ['.js', '.jsx'],
      alias: {
        'react-native$': 'react-native-web',
      },
    },
    devServer: {
      static: './',
      hot: true,
      historyApiFallback: true,
      port: 9999,
      host: '0.0.0.0',
      allowedHosts: 'all'
    },
  };
};
