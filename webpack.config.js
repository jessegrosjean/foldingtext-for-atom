//
// webpack --progress --colors --watch
//
var path = require("path");
//var webpack = require("webpack");
module.exports = {
  cache: true,
  entry: {
    'birch': "./lib-browser/birch"
  },
  output: {
    filename: "[name].js",
    publicPath: "browser/dist/",
    chunkFilename: "[chunkhash].js",
    path: path.join(__dirname, "lib-browser/dist")
  },
  module: {
    loaders: [
      { test: /\.coffee$/, loader: "coffee-loader" },
      { test: /\.(coffee\.md|litcoffee)$/, loader: "coffee-loader?literate" }
    ]
  },
  resolve: {
    alias: {
      fs: path.join(__dirname, '/lib-browser/shims/fs'),
      less: path.join(__dirname, '/lib-browser/shims/less'),
      atom: path.join(__dirname, '/lib-browser/shims/atom'),
      grim: path.join(__dirname, '/lib-browser/shims/grim')
    },
    extensions: ['', '.js', '.json', '.coffee']
  },
  plugins: [
  ]
};