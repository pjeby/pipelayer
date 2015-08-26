{expect, should} = chai = require 'chai'
should = should()
chai.use require 'sinon-chai'

{spy} = sinon = require 'sinon'
same = sinon.match.same

spy.named = (name, args...) ->
    s = if this is spy then spy(args...) else this
    s.displayName = name
    return s

failSafe = (done, fn) -> ->
    try fn.apply(this, arguments)
    catch e then done(e)

Pipelayer = pipe = require './'
ys = require 'yieldable-streams'

arrayStream = (arr, opts={objectMode: yes}) ->
    spi = (s = ys.Readable(opts)).spi()
    spi.write(item) for item in arr
    spi.end()
    return s

withSpy = (ob, name, fn) ->
    s = spy.named name, ob, name
    try fn(s) finally s.restore()

checkTE = (fn, msg) -> fn.should.throw TypeError, msg

shouldCallLaterOnce = (done, spy, args...) ->
    setImmediate failSafe done, -> onceExactly(spy, args...); done()

onceExactly = (spy, args...) ->
    spy.should.have.been.calledOnce
    spy.should.have.been.calledWithExactly(args...)




describe "pipelayer(stream)", ->

    it.skip "returns stream", ->
        pipe(s=ys.Duplex()).should.equal s

    it "augmented with any plugins"

    it "throws when called with new"

    describe ".pipe(dest, opts?)", ->

        checkOpts = (arg, dest=arg, tail=pipe:->) ->
            withSpy tail, 'pipe', (t) ->
                pipe(tail).pipe(arg, opts={})
                t.should.be.calledOnce
                onceExactly(t, same(dest), same(opts))
                pipe(tail).pipe(arg)
                t.should.be.calledTwice
                t.should.be.calledWithExactly(same(dest))

        describe "returns stream.pipe(dest, opts?)", ->

            it "with or without opts, as provided", ->
                checkOpts({})

            it "augmented with any plugins"


    describe ".pipe()", ->

        it "returns a yieldable-streams pipeline()"

        it "augmented with any plugins"








describe "pipelayer.withPlugins(ob) returns a pipelayer subclass", ->

    it.skip "with __proto__-based inheritance", ->
        wp = pipe.withPlugins({})
        wp.__proto__.should.equal pipe
        wp::__proto__.should.equal pipe.prototype

    it "inheriting and extending the base's plugins"
    it "that wraps streams and augments them"     


describe "Internals", ->

    describe "pipelayer::augment(stream, heads=[])", ->

        it "doesn't add .pipe() to an object without one"
        it "adds plugins from pipelayer::plugins"

        describe "wraps .pipe()", ->
            it "to pass through original arguments"
            it "to augment returned streams (with extended heads)"
            it "to create a pipeline if no destination"

    describe "pipelayer::pluginWrapper() -> (ctx, name, plugin) ->", ->

        it "returns plugin if a non-function"

        describe "returns a function", ->
            it "w/__proto__ of plugin"
            it "that passes through arguments and this"

    describe "pipelayer::definePlugins(obj, names?)", ->

        it "copies named props to ::plugins"
        it "adds static properties linked to ::plugins"
        it "wraps plugin properties using ::pluginWrapper"





describe "README Examples", ->
    require('mockdown').testFiles(['README.md'], describe, it, globals:
        require: (arg) ->
            if arg is 'pipelayer' then Pipelayer else require(arg)
)




































