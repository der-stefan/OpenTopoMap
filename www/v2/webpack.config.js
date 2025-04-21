const package = require('./package.json');
const webpack = require('webpack');
const HtmlWebpackPlugin = require("html-webpack-plugin");
const CopyPlugin = require("copy-webpack-plugin");
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const path = require("path");

module.exports = (env, argv) => {
  
  // set all the environment we need
  const isEnvDevelopment = argv.mode === 'development';
  const isEnvProduction = argv.mode === 'production';
  
  // our environment
  EnvTestThomasWorbs = false;
  EnvBrowserPath = isEnvDevelopment ? 'http://localhost:9000/' : 
    (EnvTestThomasWorbs ? 'https://www.mountainpanoramas.com/____otm-test/' : 'https://opentopomap.org/');
  EnvDomain = EnvTestThomasWorbs ? 'www.mountainpanoramas.com' : 'opentopomap.org';
  EnvVersion = package.version;
  EnvCookieName = "OTM-" + package.version.replace(/\./g, '-') + (isEnvProduction ? '' : '-test');

  return {

  resolve: {
    alias: {
      "togeojson": path.resolve(__dirname, 'node_modules/@tmcw/togeojson/'),
      "leaflet-elevation": path.resolve(__dirname, 'node_modules/@raruto/leaflet-elevation/')
    }
  },

  entry: './src/index.js',

  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: isEnvProduction ? '[contenthash].js' : '[name].js',
    publicPath: EnvBrowserPath
  },

  devServer: {
    contentBase: path.join(__dirname, 'dist'),
    open: true,
    port: 9000,
    historyApiFallback: {
      rewrites: [
        { from: /^.*index\.js$/, to: 'index.js' },
      ]
    }
  },
  
  module: {
    rules: [
      {
        // styles
        test: /\.(scss|css)$/,
        use: ["style-loader", "css-loader", "sass-loader"]
      },
      {
        // js
        test: /\.js$/,
        exclude: /node_modules/,
        use: ["babel-loader"]
      },
      {
        // images
        test: /\.(png|gif|jpg|jpeg|svg)$/,
        use: {
          loader: 'file-loader',
          options: {
            name: '[name].[ext]',
            outputPath: 'i',
          }
        }
      },
      {
        // favicon
        test: /\.(ico)$/,
        use: {
          loader: 'file-loader',
          options: {
            name: '[name].[ext]',
            outputPath: '',
          }
        }
      },
    ]
  },

  plugins: [
    
    // Clean dist folder
    new CleanWebpackPlugin(),

    // HTML template
    new HtmlWebpackPlugin({
      template: path.resolve(__dirname, "src", "index.ejs"),
      filename: isEnvDevelopment ? 'index.html' : 'index.php',
      templateParameters: {
        'isEnvDevelopment': isEnvDevelopment,
        'EnvBrowserPath': EnvBrowserPath
      }
    }),
    
    // copy language jsons
    new CopyPlugin({
      patterns: [
        { from: "localization", to: "l" }
      ],
    }),
    
    // provide leaflet globally
    new webpack.ProvidePlugin({
      L: 'leaflet',
      'window.L': 'leaflet'
    }),
      
    // provide toGeoJSON globally
    new webpack.ProvidePlugin({
      toGeoJSON: '@tmcw/togeojson',
      'window.toGeoJSON': '@tmcw/togeojson'
    }),
    
    // inject the OTM environment
    new webpack.DefinePlugin({
      OTM_ENV_DEVELOPMENT: JSON.stringify(isEnvDevelopment)
    }),
    new webpack.DefinePlugin({
      OTM_ENV_BROWSERPATH: JSON.stringify(EnvBrowserPath)
    }),
    new webpack.DefinePlugin({
      OTM_ENV_VERSION: JSON.stringify(EnvVersion)
    }),
    new webpack.DefinePlugin({
      OTM_ENV_COOKIE_NAME: JSON.stringify(EnvCookieName)
    }),
    new webpack.DefinePlugin({
      OTM_ENV_DOMAIN: JSON.stringify(EnvDomain)
    }),
  ]
  };
};
