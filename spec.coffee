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

util = require 'util'

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

        it "calls tail.pipe(dest, opts)"

        describe "returns a new pipelayer", ->
            it "of the same class"
            it "whose head is the original pipelayer's head"
            it "whose tail is the supplied destination stream"

    describe ".then(onSuccess?, onFail?) returns a promise", ->
        (if global.Promise? then it else it.skip
        ) "that is a global.Promise"
        it "that resolves to error if the tail emits an error"
        it "that resolves to an array when the tail is finished"







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





















