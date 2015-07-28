var gulp = require('gulp');
var gutil = require('gulp-util');
var webpack = require("webpack");
var webpackConfig = require("./webpack.config.js");

gulp.task("webpack", function(callback) {
    var config = Object.create(webpackConfig);
    webpack(config, function(err, stats) {
        if (err) throw new gutil.PluginError("webpack", err);
        gutil.log("[webpack]", stats.toString({
            // output options
        }));
        callback();
    });
});

gulp.task('default', function() {
  // place code for your default task here
});