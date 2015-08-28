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

            it "augmented with any plugins", ->
                s = pipe.withPlugins(
                    s: ys.Readable, t: ys.Transform, d: ys.Writable
                ).s(); s.should.be.instanceof ys.Readable
                t = s.t(); t.should.be.instanceOf ys.Transform
                d = t.d(); d.should.be.instanceOf ys.Writable





    describe ".pipe()", ->

        beforeEach ->
            @p = pipe.withPlugins(s: ys.Readable, d: ys.Writable).s().d().pipe()

        it "returns a yieldable-streams pipeline()", ->
            @p.should.be.instanceOf ys.Duplex

        it "without any plugins", ->
            expect(@p.s).to.not.exist
            expect(@p.d).to.not.exist

        it "returns the same stream if repeated", ->
            expect(@p.pipe()).to.equal @p
            expect(@p.s).to.not.exist
            expect(@p.d).to.not.exist


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

        it "doesn't add .pipe() to an object without one", ->
            wp = pipe.withPlugins({})
            wp::augment(s={}).should.equal s
            s.should.not.have.property 'pipe'

        it "adds plugins from ::plugins", ->
            wp = pipe.withPlugins({})
            withSpy wp::, "copyProps", (cp) ->
                wp::augment(s={}).should.equal s
                cp.should.be.calledWithExactly same(s), wp::plugins

        describe "wraps .pipe()", ->
            it "to augment original .pipe() return value w/new head", ->
                res = {}
                ob = pipe: oldPipe = spy (dest) -> res
                wp = pipe.withPlugins({})
                wp::augment(ob).should.equal ob
                ob.pipe.should.not.equal oldPipe
                withSpy wp::, "augment", (a) ->
                    ob.pipe(otherOb = ys.Writable()).should.equal res
                    oldPipe.should.be.calledOn(ob)
                    oldPipe.should.be.calledWithExactly same otherOb
                    a.should.be.calledWithExactly same(res), [ob]

            it "to chain pipeline heads, recursively", ->
                p = pipe(s1=ys.Readable()).pipe(s2=ys.Duplex()).pipe(s3=ys.Duplex())
                p.should.equal(s3)
                withSpy pipe::, "augment", (a) ->
                    p.pipe(s4=ys.Writable())
                    a.should.be.calledWithExactly same(s4), [s1, s2, s3]
                    a.should.have.returned same(s4)






            describe "so that with no destination, it returns (unaugmented)", ->

                it "a plain duplex stream (w/idempotent .pipe()) for a single step", ->
                    wp = pipe.withPlugins({})
                    withSpy ys, 'pipeline', (pl) ->
                        withSpy ys, 'duplexify', (d) ->
                            s2 = wp(s1=ys.Writable()).pipe()
                            pl.should.not.be.called
                            d.should.be.calledWithExactly same(s1), same(s1)
                            d.should.have.returned same(s2)
                            s2.pipe().should.equal s2
                            s2.pipe().pipe().should.equal s2

                it "a pipeline (w/idempotent .pipe()) for multiple steps", ->
                    wp = pipe.withPlugins({})
                    wp(s1=ys.Readable()).pipe(s2=ys.Writable())
                    withSpy ys, 'pipeline', (pl) ->
                        s3 = s2.pipe()
                        pl.should.be.calledWithExactly(
                            [same(s1), same(s2)], noPipe: yes
                        )
                        pl.should.have.returned same(s3)
                        s3.pipe().should.equal s3
                        s3.pipe().pipe().should.equal s3

                it "the original stream for a plain pipelayer w/no heads", ->
                    s2 = pipe(s1=ys.Writable()).pipe()
                    s2.should.equal s1
                    oldPipe = s2.pipe
                    s3 = s2.pipe()
                    s3.should.equal s2
                    s3.pipe.should.equal oldPipe









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

            it "enumerable on dest for named props on src", ->
                pipe::copyProps(d={},s={x:1,y:2}, n=['x','z'])
                Object.keys(d).should.eql n
                d.should.eql {x:1, z:undefined}

            it "skipping already-existing props", ->
                pipe::copyProps(d={y:3},s={x:1,y:2}, n=['x','y'])
                Object.keys(d).should.eql ['y', 'x']
                d.should.eql {x:1, y:3}

            it "overwriting existing props if `overwrite`", ->
                pipe::copyProps(d={y:3},s={x:1,y:2}, n=['x','y'], yes)
                Object.keys(d).should.eql ['y', 'x']
                d.should.eql {x:1, y:2}

            it "including all enumerable props of src by default", ->
                s1 = Object.create(null); s1.a = 'b'
                s2 = Object.create(s1); s2.b = 'c'
                pipe::copyProps(d={}, s2)
                d.should.eql {a:'b', b:'c'}

            it "that delegate to src", ->
                pipe::copyProps(d={},s={x:1,y:2}, n=['y','x'])
                Object.keys(d).should.eql n
                s.x = 99; d.should.eql {x:99, y:2}
                s.y = 42; d.should.eql {x:99, y:42}
                s.x = 17; d.should.eql {x:17, y:42}






            it "that can be assigned to", ->
                pipe::copyProps(d={},s={x:1,y:2}, n=['y','x'])
                d.x = 42
                d.should.eql {x:42, y:2}
                Object.keys(d).should.eql ['y', 'x']
                Object.getOwnPropertyDescriptor(d, 'x').should.eql {
                    value: 42, enumerable: yes, configurable: yes, writable: yes
                }
                delete d.x; d.should.eql {y:2}
                Object.keys(d).should.eql ['y']

            it "that can be reconfigured", ->
                pipe::copyProps(d={},s={x:1,y:2}, n=['y','x'])
                p = Object.getOwnPropertyDescriptor(d, 'y')
                p.should.eql {
                    set: p.set, get: p.get, configurable: yes, enumerable: yes
                }

            describe "that, when a layer is given, invoke layer::wrapPlugin()", ->

                it "at most once, with caching", ->
                    withSpy pipe::, "wrapPlugin", (wp) ->
                        pipe::copyProps(d={},s={x:->}, n=['x'], no, pipe::)
                        wp.should.not.be.called
                        x = d.x
                        wp.should.be.calledOnce
                        wp.should.be.calledOn(pipe::)
                        wp.should.be.calledWithExactly(s.x)
                        wp.should.have.returned x
                        xx = d.x
                        wp.should.be.calledOnce
                        expect(xx).to.equal x

                it "unless overwritten or reconfigured", ->
                    withSpy pipe::, "wrapPlugin", (wp) ->
                        pipe::copyProps(d={},s={x:->}, n=['x'], no, pipe::)
                        d.x = ->
                        x = d.x
                        wp.should.not.be.called


            describe "that, even if inherited,", ->

                it "fetches only once, if a layer is given", ->
                    withSpy pipe::, "wrapPlugin", (wp) ->
                        pipe::copyProps(d={},s={x:->}, n=['x'], no, pipe::)
                        dd = Object.create(d)
                        x1 = dd.x
                        x2 = d.x
                        x1.should.equal x2
                        expect(dd.hasOwnProperty('x')).to.be.false
                        wp.should.be.calledOnce

                it "no longer delegate when overwritten or reconfigured", ->
                    withSpy pipe::, "wrapPlugin", (wp) ->
                        pipe::copyProps(d={},s={x:->}, n=['x'], no, pipe::)
                        dd = Object.create(d)
                        d.x = 42
                        x1 = dd.x
                        x2 = d.x
                        expect(x1).to.equal x2
                        expect(dd.hasOwnProperty('x')).to.be.false
                        wp.should.not.be.called



describe "README Examples", ->
    require('mockdown').testFiles(['README.md'], describe, it, globals:
        require: (arg) ->
            if arg is 'pipelayer' then Pipelayer else require(arg)
)











