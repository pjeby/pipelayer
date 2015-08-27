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

    it "throws when called with new", ->
        checkTE (-> new pipe), "Not a constructor"

    it "returns augmented stream", ->
        withSpy pipe::, 'augment', (a) ->
            res = pipe(s=ys.Duplex())
            res.should.equal s
            a.should.be.calledOn(same pipe::)
            a.should.be.calledOnce
            a.should.be.calledWithExactly(same(s))
            a.should.have.returned same(res)

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
        it "without any plugins"
        it "returns the same stream if repeated"



describe "pipelayer.pipe(stream)", ->

    it "returns augmented stream", ->
        withSpy pipe::, 'augment', (a) ->
            res = pipe.pipe(s=ys.Duplex())
            res.should.equal s
            a.should.be.calledOn(same pipe::)
            a.should.be.calledOnce
            a.should.be.calledWithExactly(same(s))
            a.should.have.returned same(res)


describe "pipelayer.withPlugins(ob) returns a pipelayer subclass", ->

    it "with __proto__-based inheritance", ->
        wp = pipe.withPlugins({})
        wp.__proto__.should.equal pipe
        wp::__proto__.should.equal pipe.prototype
        expect(wp::plugins.__proto__).to.equal pipe::plugins

    it "extending the base's plugins", ->
        withSpy pipe::, 'definePlugins', (dp) ->
            wp = pipe.withPlugins(pi={}, n=[])
            dp.should.be.calledOnce
            dp.should.be.calledOn(same wp::)
            dp.should.be.calledWithExactly(same(pi), same(n))
            dp.should.have.returned same(wp)

    it "that wraps streams and augments them", ->
        wp = pipe.withPlugins({})
        withSpy wp::, 'augment', (a) ->
            res = wp(s=ys.Duplex())
            res.should.equal s
            a.should.be.calledOnce
            a.should.be.calledOn(same wp::)
            a.should.be.calledWithExactly(same(s))
            a.should.have.returned same(res)




describe "Internals", ->

    describe "::augment(stream, heads=[])", ->

        it "doesn't add .pipe() to an object without one"
        it "adds plugins from ::plugins"

        describe "wraps .pipe()", ->
            it "to pass through original arguments"
            it "to augment returned streams (with extended heads)"
            it "to create a pipeline if no destination"


    describe "::definePlugins(obj, names?)", ->

        it "copies the named props to ::plugins, wrapped w/::wrapPlugin", ->
            wp = pipe.withPlugins({})
            withSpy wp::, 'copyProps', (cp) ->
                wp::definePlugins(obj={}, names=[])
                cp.should.be.calledWithExactly(
                    wp::plugins, same(obj), same(names), yes, wp::
                )

        it "adds static properties for named ::plugins", ->
            wp = pipe.withPlugins({})
            withSpy wp::, 'copyProps', (cp) ->
                wp::definePlugins(obj={}, names=[])
                cp.should.be.calledWithExactly(wp, wp::plugins, same(names))

        it "defaults names to obj's enumerable own-properties", ->
            wp = pipe.withPlugins({})
            withSpy wp::, 'copyProps', (cp) ->
                wp::definePlugins(obj={x:1, z:2})
                cp.should.be.calledWithExactly(wp, wp::plugins, ['x', 'z'])







    describe "::wrapPlugin(plugin)", ->

        it "returns plugin if a non-function", ->
            res = pipe::wrapPlugin(42)
            expect(res).to.equal 42

        describe "returns a function", ->

            it "w/__proto__ of plugin", ->
                res = pipe::wrapPlugin(f = ->)
                expect(typeof res).to.equal "function"
                expect(res.__proto__).to.equal f

            it "that passes through arguments and this", ->
                res = pipe::wrapPlugin(f = spy.named('f', -> 4))
                res.call(o={}, 1, 2, 3)
                f.should.be.calledOnce
                f.should.be.calledOn same(o)
                f.should.be.calledWithExactly 1, 2, 3

            it "that returns its result unaltered if it's not a stream", ->
                withSpy pipe::, "augment", (a) ->
                    res = pipe::wrapPlugin(-> 42)
                    expect(res()).to.equal 42

                    ob = {on:(->), end:->}
                    ctx = pipe: spy ->
                    res = pipe::wrapPlugin(-> ob)
                    expect(res.call(ctx)).to.equal ob

                    ctx.pipe.should.not.be.called
                    a.should.not.be.called









            it "that pipes to a returned writable stream", ->
                withSpy pipe, "pipe", (p) ->
                    withSpy pipe::, "augment", (a) ->
                        f = ->
                        ob = {on:f, write:f, end:f, writable:yes}
                        res = pipe::wrapPlugin(-> ob)
                        expect(res.call(pipe)).to.equal ob

                        p.should.be.calledWithExactly same(ob)
                        a.should.be.calledWithExactly same(ob)

            it "that augments a returned readable (but not writable) stream", ->
                withSpy pipe, "pipe", (p) ->
                    withSpy pipe::, "augment", (a) ->
                        f = ->
                        ob = {on:f, write:f, end:f, writable:no}
                        res = pipe::wrapPlugin(-> ob)
                        expect(res.call(pipe)).to.equal ob
                        p.should.not.be.called
                        a.should.be.calledWithExactly same(ob)

                        ob = {on:f, pipe:f}
                        expect(res.call(pipe)).to.equal ob
                        p.should.not.be.called
                        a.should.be.calledWithExactly same(ob)
















    describe "::copyProps(dest, src, names, overwrite, layer)", ->

        it "returns dest", ->
            res = pipe::copyProps(d={}, s={}, n=[])
            expect(res).to.equal d

        describe "creates properties", ->
            it "enumerable on dest for named props on src"
            it "skipping already-existing props"
            it "overwriting existing props if `overwrite`"
            it "including all enumerable props of src by default"
            it "that delegate to src"
            it "that can be assigned to"
            it "that can be reconfigured"

            describe "that, when a layer is given, invoke layer::wrapPlugin()", ->
                it "at most once, with caching"
                it "unless overwritten"
                it "unless reconfigured"

            describe "that, even if inherited,", ->
                it "fetch only once when a wrapper is given"
                it "no longer delegate when assigned to"
                it "no longer delegate when reconfigured"

















describe "README Examples", ->
    require('mockdown').testFiles(['README.md'], describe, it, globals:
        require: (arg) ->
            if arg is 'pipelayer' then Pipelayer else require(arg)
)




































