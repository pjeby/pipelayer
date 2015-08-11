# pipelayer

Sometimes -- especially when working with gulp -- it's helpful to be able to stack a bunch of transform streams together, and use the whole thing as if it were one giant transform stream.

For that matter, sometimes it would be nice to be able to replace verbose pipelines like `foo().pipe(bar()).pipe(baz())` with something like `pipe.foo().bar().baz()`.

Pipelayer lets you do *both*:

<!-- mockdown-setup: --printResults; languages.js = 'babel' -->

```js
var gulp      = require('gulp'),
    pipelayer = require('pipelayer').withPlugins({

        // Any function that returns a stream can be a plugin
        src: gulp.src,
        dest: gulp.dest,
        coffee: require('gulp-coffee'),
        uglify: require('gulp-uglify'),

        /* Generator functions become yieldable-streams.Transform factories */
        log: function *(msg) {
            var file;
            while ( (file = yield this.read()) != null ) {
                console.log(msg+": "+file.path);
                yield this.write(file);
            }
        }
    });

gulp.task("default", function() {
  return pipelayer.src(['src/*.coffee'])
    .log("source filename")
    .coffee({bare: true})
    .log("compiled filename")
    .uglify()
    .dest('dist');
});
```

Calling `pipelayer(stream)` wraps a stream as a Pipelayer object, with the given plugins.  Pipelayer objects also have a `.then()` method, so they can be used as promises (they'll yield an array of everything that came out of the stream since `.then()` was first called, or an error if the stream emits an error event.

(That's why the above gulp task can return a Pipelayer: gulp will recognize the `.then` method and wait for the stream to complete before going on to the next task.)

### Composing Pipelines

Pipelayer objects also have a `.pipe()` method that accepts a stream or another Pipelayer, and returns a *new* Pipelayer object with the same plugins.  This lets you compose pipelines, like so:

```js
function uglyCoffee(coffeOpts, uglyOpts) {
    return pipelayer.coffee(coffeOpts).uglify(uglyOpts);
}

var task = pipelayer.src('src/*.coffee').pipe(uglyCoffee()).dest('dist');
```    
Notice that `uglyCoffee()` returns a *combination* of two streams!  Normally, when you `.pipe()` node streams together, you end up with the *last* stream piped, which means you can't *compose* transform streams ahead of time: you have to assemble everything at once, which makes it hard to build higher-level transforms out of existing ones.

But when you call a Pipelayer's `.pipe()` method (or a plugin), you actually get back *another Pipelayer object*: one that remembers its "head", and handles incoming pipes accordingly.

There is one slight downside to this: you must always *start* a pipeline with a Pipelayer, never a regular node stream.  That's because a Pipelayer *isn't* a node stream: it's just a wrapper over one (or more) node streams.  (You can turn an arbitrary node stream into a Pipelayer, however, by calling `pipelayer(stream)`.)

### How Pipelayers Work

Each pipelayer has a head stream (where you pipe *into* it), and a tail stream (that you pipe *out* of).  When a pipelayer is first created, the head and tail streams are usually the same.  But when you use a plugin method or `.pipe()` to another stream, the new stream retains the old head stream, and replaces the tail stream.

In this way, you can build up a long pipeline, and yet retain the ability to pipe *into* the result, because the pipeline still knows where to route things into.

If you need to directly access the node stream at a pipelayer's head or tail, you can use `pipelayer.getHead(pipelineOrStream)` or `pipelayer.getTail(pipelineOrStream)`.  These functions will accept either a plain node stream or a pipelayer; if you pass in a node stream, the stream will be returned unchanged.  This is useful for creating APIs that work with pipelayers or streams: you can just call `pipelayer.getHead(arg)` when you're expecting `arg` to be a writable stream to pipe into, or `pipelayer.getTail(arg)` if you're looking for a readable stream to read out of. 

## Reference

### Constructor: `aPipe = pipelayer(tail, head?)`

Create a new pipelayer instance with the given tail stream (required) and head stream (optional).  If no head is supplied, the tail stream is used as the head.  

Either or both streams can be pipelayers themselves, in which case the tail pipelayer's tail is used as the tail stream, and the head pipelayer's head stream is used as the head stream.


### Instance Methods

#### `.pipe(newTail, opts?)`

Pipe the tail stream of this instance into the head of `newTail`, and return a new instance of the same pipelayer subclass, with the same head as the current instance, and a tail equal to the tail of `newTail`.  The `opts`, if provided, are passed to the underlying stream `.pipe()` call before creating the new instance.

#### `.then(onsuccess?, onfail?)`

Return an ES6 promise (or polyfill) for the end of the tail stream, if it's readable.  If not readable, or an error occurs, `onfail()` will be called with the error.  Otherwise, `onsuccess()` will be called with an array containing all the objects or data sent to the tail stream.  Data read from the tail stream *before* the first call to `.then()` will not be included.


### Static Methods

#### `pipelayer.isPipelayer(streamOrPipelayer)`

Returns true if the argument is a pipelayer -- even a subclass or a duplicate implementation due to multiple versions of the pacakge being installed.

#### `pipelayer.getHead(streamOrPipelayer)`

If the argument is a pipelayer (including a subclass or duplicate implementation), returns its underlying "head" stream.  Otherwise, the stream is returned unchanged.

#### `pipelayer.getTail(streamOrPipelayer)`

If the argument is a pipelayer (including a subclass or duplicate implementation), returns its underlying "tail" stream.  Otherwise, the stream is returned unchanged.

#### `withPlugins(obj)`

Create and return a new pipelayer subclass with the plugins found as the named, enumerable own-properties of `obj`.  If `obj` has no enumerable properties (as is the case when using [`auto-plug`](https://www.npmjs.com/package/auto-plug) in lazy mode), its non-enumerable own-properties are used instead.

Plugins are installed on the new subclass by creating both static and instance (i.e., prototype) properties.  These properties lazily delegate to the same-named properties on `obj`.

If a plugin is an object, it's simply exposed as a normal property.  If a plugin is a generator function, it's wrapped as a `Transform.factory` using the yieldable-streams package, so that it returns a stream.  If it's any other sort of function, it's assumed to already return a stream, and is wrapped in such a way that calling `aPipe.aPluginMethod(...args)` will be equivalent to `aPipe.pipe(obj.aPluginMethod(...args))`.

Likewise, if `.aPluginMethod()` is called statically on the *class* (e.g. `pipe.aPluginMethod(...args)`), it is wrapped in such a way as to create a new instance of the class, wrapping the returned stream.  (That is, `pipe(obj.aPluginMethod(...args)`.)

