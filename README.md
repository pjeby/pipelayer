# pipelayer

Sometimes -- especially when working with gulp -- it's helpful to be able to stack a bunch of transform streams together, and use the whole thing as if it were one giant transform stream.

For that matter, sometimes it would be nice to be able to replace pipelines like `foo().pipe(bar()).pipe(baz())` with something like `pipe.foo().bar().baz()`.

Pipelayer lets you do *both*:

<!-- mockdown-setup:  --printResults; languages.js = 'babel' -->

```js
var gulp = require('gulp'),
    pipe = require('pipelayer').withPlugins({

        // Any function that returns a stream can be a plugin
        src: gulp.src,
        dest: gulp.dest,
        coffee: require('gulp-coffee'),
        uglify: require('gulp-uglify'),

        log: function*(msg) {
            // Generator function plugins become yieldable-streams.Transforms
            var file;
            while ( (file = yield this.read()) != null ) {
                console.log(msg+": "+file.path);
                yield this.write(file);
            }
        }
    });

gulp.task("default", function() {
  return pipe.src(['src/*.coffee'])
    .log("source filename")
    .coffee({bare: true})
    .log("compiled filename")
    .uglify()
    .dest('dist');
});
```

Calling `pipe(stream)` wraps a stream as a Pipelayer object, with the given plugins.  Pipelayer objects also have a `then()` method, so they can be used as promises (they'll yield an array of everything that came out of the stream since `.then()` was first called, or an error if the stream emits an error event.

(That's why the above gulp task can return a Pipelayer: gulp will recognize the `.then` method and wait for the stream to complete before going on to the next task.)

### Composing Pipelines

Pipelayer objects also have a `.pipe()` method that accepts a stream or another Pipelayer, and returns a *new* Pipelayer object with the same plugins.  This lets you compose pipelines, like so:

```js
function uglyCoffee(coffeOpts, uglyOpts) {
    return pipe.coffee(coffeOpts).uglify(uglyOpts);
}

var task = pipe.src('src/*.coffee').pipe(uglyCoffee()).dest('dist');
```    
Notice that `uglyCoffee()` returns a *combination* of two streams!  Normally, when you `.pipe()` node streams together, you end up with the *last* stream piped, which means you can't *compose* transform streams ahead of time: you have to assemble everything at once, which makes it hard to build higher-level transforms out of existing ones.

But when you call a Pipelayer's `.pipe()` method (or a plugin), you actually get back *another Pipelayer object*: one that remembers its "head", and handles incoming pipes accordingly.

There is one slight downside to this: you must always *start* a pipeline with a Pipelayer, never a regular node stream.  That's because a Pipelayer *isn't* a node stream: it's just a wrapper over one (or more) node streams.  (You can turn an arbitrary node stream into a Pipelayer by calling `pipe(stream)`.)

### How Pipelayers Work

Each pipelayer has a head stream (where you pipe *into* it), and a tail stream (that you pipe *out* of).  When a pipelayer is first created, the head and tail streams are the same.  But when you use a plugin method or `.pipe()` to another stream, the new stream retains the old head stream, and replaces the tail stream.

In this way, you can build up a long pipeline, and yet retain the ability to pipe *into* the result, because the pipeline still knows where to route things into.

If you need to directly access the node stream at a pipelayer's head or tail, you can use `pipe.head(pipelineOrStream)` or `pipe.tail(pipelineOrStream)`.  These functions will accept either a plain node stream or a pipelayer; if you pass in a node stream, the stream will be returned unchanged.  This is useful for creating APIs that work with pipelayers or streams: you can just call `pipe.head(arg)` when you're expecting `arg` to be a writable stream to pipe into, or `pipe.tail(arg)` if you're looking for a readable stream to read out of. 

