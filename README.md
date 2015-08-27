# pipelayer

Pipelayer is a tool for "virally" adding plugins to node stream objects, such that they pass on the same plugins to any stream they're `.pipe()`d to, recursively.  This is especially useful for working with gulp, e.g.:

<!-- mockdown-setup: --printResults; languages.js = 'babel' -->

```js
// Use plugins without .pipe()

var gulp      = require('gulp'),
    pipelayer = require('pipelayer').withPlugins({
        src: gulp.src,
        dest: gulp.dest,
        coffee: require('gulp-coffee'),
        uglify: require('gulp-uglify'),
    });

gulp.task("someTask", function() {
  return pipelayer
    .src(['src/*.coffee'])  // No need to .pipe() between plugins!
    .coffee({bare: true})   // Each new stream gets extended with
    .uglify()               // the same set of plugins, but is
    .dest('dist');          // otherwise the same stream as before.
});
```

### Defining Plugins

Pipelayer's `.withPlugins(obj, names?)` static method returns a new, customized version of the `pipelayer` function, with the specified additional plugins found as own-enumerable properties on `obj`.  (Unless an array of `names` is given, in which case only the named properties will be used as plugins.)

The returned function will have the plugins available as static properties on itself, and will augment any streams passed to it with the same plugins.  It will also have a `.withPlugins()` method, that can be used to create extended versions of itself, recursively.

So, we could have made the previous example even simpler, by telling pipelayer what properties to grab from `gulp`, and then using [`auto-plug`](https://npmjs.com/package/auto-plug) to load the gulp plugins, e.g.:

<!--mockdown-set: ++ignore -->

```js
var gulp      = require('gulp'),
    pipelayer = require('pipelayer')
        .withPlugins(gulp, ['src', 'dest'])
        .withPlugins(require('auto-plug')('gulp'));
```

The above code will make `src()`, `dest()`, and any modules named `gulp-*` listed in `package.json` available as methods on `pipelayer`, and on any streams it creates or pipes to.

The plugin values or methods are "late bound", meaning that they aren't actually retrieved from the supplied `obj` until the first time they're actually used.  (This is especially handy when using `auto-plug`, which by default returns an object whose properties will lazily `require()` a relevant plugin module.)

Plugins supplied to `.withPlugins()` can be any Javascript value, but functions are handled specially:

* If it's a generator function, it's turned into a transform stream factory using the [`yieldable-streams`](https://npmjs.com/package/yieldable-streams) module.

* If a function returns a stream, the returned stream is augmented with the same plugins as the current stream or `pipelayer` function.  If the returned stream is writable and the plugin was invoked on a stream, then the returned stream will also be `.pipe()`d to before it's returned.

All other plugin values just become regular properties or methods of the stream (and of the new pipelayer function).


### Composing Pipelines

Normally, when you `.pipe()` node streams together, you end up with the *last* stream piped, which means you can't *compose* transform streams ahead of time: you have to assemble everything at once, which makes it hard to build higher-level transforms out of existing ones.

But sometimes -- especially when working with gulp -- it's helpful to be able to stack a bunch of transform streams together, and use the whole thing as if it were one giant transform stream.  Pipelayer lets you do that, just by wrapping the first stream in the pipeline, and ending it with an empty `.pipe()` call:

```js
// Compose a pipeline from some transform streams

var pipelayer = require('pipelayer'),

    aPipeline = pipelayer(aTransform)   // start the chain w/pipelayer()
                .pipe(anotherTransform)
                .pipe(yetAnotherTransform)
                .pipe();                // and end with empty .pipe()

// Now we can use the combined stream as if it were one stream all along
someReadable.pipe(aPipeline).pipe(someWritable)
```

Pipelayer does this by augmenting its argument's `.pipe()` method to carry forward the original start of the pipeline, so that the final `.pipe()` call can create a combined duplex stream.  Each subsequently-piped stream is augmented in the same way, and the resulting stream will emit errors for any errors emitted by the underlying streams.

This pipeline composition aspect of Pipelayer is completely orthogonal to the plugin-adding aspect.  If the `pipelayer` function used to start the chain has plugins, then each piped stream and the combined stream will have the same plugins.  If it doesn't have any plugins, then only the `.pipe()` method of the streams will be altered.  And you can use an empty `.pipe()` call to create a combined stream, even if the chain was composed entirely from plugin calls, e.g.:

```js
// Compose a pipeline from plugin calls

var uglyCoffee = pipelayer
                    .coffee({bare: true})
                    .uglify()
                    .pipe();    // just end the composition with .pipe()

gulp.src("*.coffee")
    .pipe(uglyCoffee)   // and it's a valid standalone transform stream
    .dest("dist");      // ...with the original chain's plugins!
```

