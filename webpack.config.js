//
// webpack --progress --colors --watch
//
var path = require("path");
//var webpack = require("webpack");
module.exports = {
  cache: true,
  entry: {
    'foldingtext': "./lib-browser/foldingtext"
  },
  output: {
    path: path.join(__dirname, "lib-browser/dist"),
    publicPath: "browser/dist/",
    filename: "[name].js",
    chunkFilename: "[chunkhash].js"
  },
  module: {
    loaders: [
      { test: /\.coffee$/, loader: "coffee-loader" },
      { test: /\.(coffee\.md|litcoffee)$/, loader: "coffee-loader?literate" }
    ]
  },
  resolve: {
    alias: {
      atom: path.join(__dirname, '/lib-browser/shims/atom'),
      fs: path.join(__dirname, '/lib-browser/shims/fs'),
      grim: path.join(__dirname, '/lib-browser/shims/grim')
    },
    extensions: ['', '.js', '.json', '.coffee']
  },
  plugins: [
  ]
};