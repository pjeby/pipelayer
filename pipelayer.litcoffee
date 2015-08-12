# pipelayer

Pipelayer exports a single, `new`-less class with various static methods.

    autocreate = require('autocreate')

    module.exports = class Pipelayer
        Pipelayer = autocreate(this)

## Core Protocols and Piping

In order to interop with other installed versions of Pipelayer, we use a
protocol versioning string.  The `isPipelayer()` static method recognizes
either instances of the same calss, objects with a matching protocol string.
It's then possible to extract head or tail streams from objects that implement
the same protocol.

        @::[PROTOCOL = 'pipelayer.peak-dev.org:v1'] = PROTOCOL

        @isPipelayer: isPipe = (stream) -> stream instanceof Pipelayer or
            stream?[PROTOCOL] is PROTOCOL

        @getHead: getHead = (ob) -> if isPipe(ob) then ob._head else ob
        @getTail: getTail = (ob) -> if isPipe(ob) then ob._tail else ob

A pipelayer is just a head stream (usually writable) and a tail stream (usually
readable), which default to being the same object.  If the head or tail are
pipelayers, they're unwrapped to get the head-most or tail-most stream.
Piping from a pipelayer then pipes its tail stream to the head of the
destination, and returns a new pipelayer whose head is the current pipelayer's
head, and whose tail is the tail of the destination.  Any extra arguments (i.e.,
options) are passed through to the stream-level `.pipe()` call.

        constructor: (tail, head=tail) ->
            @_tail = getTail(tail)
            @_head = getHead(head)

        pipe: (dest, args...) ->
            getTail(this).pipe(getHead(dest), args...)
            return new @constructor(dest, this)

## Promise Support

Pipelayers have a `.then()` method that resolves to an array of data -- or the
first error -- emitted by their tail stream.  Internally, this is implemented
by creating a promise wrapping the tail stream, and saving it for future use
so that all calls to `.then()` will receive the same result.

        then: ->
            p = streamPromise(getTail(this))
            @then = p.then.bind(p)
            return p.then(arguments...)

The internal promise will be a Node-native promise, or a polyfill if running
under an older version of Node.  It's implemented by piping the target stream
into a yieldable-streams `Writable` and consuming the received data or first
error.

        Promise = global.Promise

        streamPromise = (stream) ->
            stream.pipe(
                s = require('yieldable-streams').Writable(objectMode: yes)
            )
            spi = s.spi()
            Promise ?= require 'promiscuous'
            return new Promise (resolve, reject) ->
                output = []
                spi.read() consume = (e, d) ->
                    return reject(e) if e
                    return resolve(output) unless d?
                    output.push(d)
                    spi.read() consume









## Plugins

        @withPlugins: ->






































