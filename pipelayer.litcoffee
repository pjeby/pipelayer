# pipelayer

    autocreate = require('autocreate')

    module.exports = class Pipelayer
        Pipelayer = autocreate(this)

        @::[PROTOCOL = 'pipelayer.peak-dev.org:v1'] = PROTOCOL

        @isPipelayer: isPipe = (stream) -> stream instanceof Pipelayer or
            stream?[PROTOCOL] is PROTOCOL

        @getHead: getHead = (ob) -> if isPipe(ob) then ob._head else ob
        @getTail: getTail = (ob) -> if isPipe(ob) then ob._tail else ob

        constructor: (tail, head=tail) ->
            @_tail = getTail(tail)
            @_head = getHead(head)

        pipe: (dest, args...) ->
            getTail(this).pipe(getHead(dest), args...)
            return new @constructor(dest, this)
