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
Promise = global.Promise ? require 'promiscuous'   
ys = require 'yieldable-streams'

arrayStream = (arr, opts={objectMode: yes}) ->
    spi = (s = ys.Readable(opts)).spi()
    spi.write(item) for item in arr
    spi.end()
    return s

items = (val) -> Object.keys(val).map (k) -> [k, val[k]]

withSpy = (ob, name, fn) ->
    s = spy.named name, ob, name
    try fn(s) finally s.restore()

checkTE = (fn, msg) -> fn.should.throw TypeError, msg

shouldCallLaterOnce = (done, spy, args...) ->
    setImmediate failSafe done, -> onceExactly(spy, args...); done()

onceExactly = (spy, args...) ->
    spy.should.have.been.calledOnce
    spy.should.have.been.calledWithExactly(args...)

describe "pipelayer(tail, head?)", ->

    it "returns a pipelayer instance", ->
        pipe().should.be.instanceOf pipe

    it "uses tail as the default head", ->
        pipe.getHead(pipe(tail={})).should.equal tail

    it "uses the tail of a pipelayer as the tail", ->
        p1 = pipe(t1={})
        pipe.getTail(pipe(p1)).should.equal t1

    it "uses the head of a pipelayer as the head", ->
        p1 = pipe(t1={}, h1={})
        pipe.getHead(pipe(p1)).should.equal h1

    it "uses the head of the tail pipelayer as the default head", ->
        p1 = pipe(t1={})
        pipe.getHead(pipe(p1)).should.equal t1

    describe ".pipe(dest, opts?)", ->

        checkOpts = (arg, dest=arg, tail=pipe:->) ->
            withSpy tail, 'pipe', (t) ->
                pipe(tail).pipe(arg, opts={})
                t.should.be.calledOnce
                onceExactly(t, same(dest), same(opts))
                pipe(tail).pipe(arg)
                t.should.be.calledTwice
                t.should.be.calledWithExactly(same(dest))

        describe "calls tail.pipe(dest, opts?)", ->

            it "with or without opts, as provided", ->
                checkOpts({})

            it "using dest's tail if it's a pipelayer", ->
                checkOpts(pipe({}, dest={}), dest)



        describe "returns a new pipelayer", ->

            it "of the same class", ->
                class MyPipe extends Pipelayer
                new MyPipe(pipe: ->).pipe(dest={}).should.be.instanceOf MyPipe

            it "whose head is the original pipelayer's head", ->
                result = pipe((pipe:->), head={}).pipe(dest={})
                pipe.getHead(result).should.equal head

            it "whose tail is the supplied destination stream", ->
                result = pipe((pipe:->), head={}).pipe(dest={})
                pipe.getTail(result).should.equal dest


    describe ".then(onSuccess?, onFail?) returns a promise that", ->
        it "is a "+(if global.Promise? then "global.Promise" else "Promise polyfill"), ->
            pipe(arrayStream([])).then().should.be.instanceOf Promise

        describe "rejects if the tail emits an error", ->

            errorableStream = (e, done) ->
                pipe(p = ys.Readable(objectMode: yes, highWaterMark:1)).then(
                    -> done(new AssertionError("should not complete"))
                    failSafe done, (err) -> err.should.equal(e); done()
                )
                return p.spi()
                
            it "before any data", (done) ->                
                errorableStream(e = new Error, done).end(e)

            it "between/after data", (done) ->
                s = errorableStream(e = new Error, done)
                s.write(1) -> s.write(2) -> s.write(3) -> s.end(e)

        describe "when the tail is finished, resolves to an array", ->
            it "of objects", (done) ->
                pipe(arrayStream([1,2,3])).then failSafe done, (d) =>
                    d.should.eql [1,2,3]
                    done()

            it "of string/buffer data", (done) ->
                pipe(arrayStream(["one","two","three"], {})).then(
                    failSafe done, (d) =>
                        d.should.eql [
                            Buffer("one"),Buffer("two"),Buffer("three")
                        ]
                        done()
                )

            match = (p, res, done) ->
                p.then(
                    failSafe done, (d) -> d.should.eql(res); done()
                    done
                )

            dataStream = ->
                ds = pipe(ys.Readable(objectMode: yes, highWaterMark: 0))
                ds.pipe(ys.Writable(objectMode:yes))
                return [ds, pipe.getHead(ds).spi()]

            it "of only data since .then() was called", (done) ->
                [ds, s] = dataStream()
                s.write(1) -> s.write(2) ->                
                    match(ds, [3], done); s.write(3) -> s.end()

            it "with all data since .then() was first called", (done) ->
                [ds, s] = dataStream()
                ds.then()
                s.write(1) -> s.write(2) ->                
                    match(ds, [1, 2, 3], done); s.write(3) -> s.end()
                
            
        








describe "pipelayer.isPipelayer(ob)", ->

    it "returns true for pipelayer instances", ->
        pipe.isPipelayer(pipe()).should.be.true

    it "returns true for pipelayer subclass instances", ->
        class MyPipe extends Pipelayer
        pipe.isPipelayer(new MyPipe).should.be.true

    it "returns true for separate implementations", ->
        delete require.cache[require.resolve('./')]
        pipe.isPipelayer(require('./')()).should.be.true

    it "returns false for any other sort of object", ->
        pipe.isPipelayer({}).should.be.false

describe "pipelayer.getHead(ob)", ->

    it "returns the head of a pipelayer instance", ->
        pipe.getHead(pipe(tail={}, head={})).should.equal head

    it "returns ob for anything else", ->
        pipe.getHead(ob={}).should.equal ob

describe "pipelayer.getTail(ob)", ->

    it "returns the tail of a pipelayer instance", ->
        pipe.getTail(pipe(tail={})).should.equal tail

    it "returns ob for anything else", ->
        pipe.getTail(ob={}).should.equal ob










describe "pipelayer.withPlugins(ob) returns a pipelayer subclass", ->

    it "that creates instances without `new`"
    it "with instance properties for ob's non-function properties"
    it "with static properties for ob's non-function properties"

    describe "with instance methods", ->
        it "for ob's methods"
        it "that return this.pipe(originalmethod(args...))"

    describe "with static methods", ->
        it "for ob's methods"
        it "that return new this(originalmethod(args...))"


describe.skip "README Examples", ->
    require('mockdown').testFiles(['README.md'], describe, it, globals:
        require: (arg) ->
            if arg is 'pipelayer' then Pipelayer else require(arg)
)





















