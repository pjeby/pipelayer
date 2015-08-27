# pipelayer

    autocreate = require('autocreate')

    module.exports = class pipelayer

        pipelayer = autocreate(this)

        constructor: -> throw new TypeError "Not a constructor"

        __class_call__: (stream) -> @augment(stream)

        @pipe: (stream) -> @::augment(stream)

        @withPlugins: -> @::subclass()::definePlugins(arguments...)

        plugins: Object.create(null)

        subclass: ->
            cls = autocreate.subclass(@constructor)
            cls::plugins = Object.create(@plugins)
            return cls

        definePlugins: (obj, names=Object.keys(obj)) ->
            @copyProps(@plugins, obj, names, yes, this)
            return @copyProps(@constructor, @plugins, names)

        augment: (stream) -> stream

        copyProps: (dest) -> dest











### Plugin Wrapping

A pipelayer's plugins are wrapped versions of the original plugin values, when
those values are functions.  The wrapped function inherits any static
properties from the original function, and invokes it with the same context and
arguments.  If its return value is a stream, it's augmented: either by piping
to it (in the case of a currently-writable stream), or just by `.augment()`ing
it (in the case of all other stream types.

        isFunction = (ob) -> typeof ob is "function"

        wrapPlugin: (plugin) ->
            return plugin unless isFunction(plugin)

            self = this

            fn = ->
                res = plugin.apply(this, arguments)
                return res unless isStream(res)
                if isWritableType(res) and res.writable isnt false
                    return this.pipe(res)
                else
                    return self.augment(res)

            fn.__proto__ = plugin
            return fn

For augmentation purposes, a stream is defined as an object with an `on()`
method, and either a `pipe()` method or both a `write()` and an `end()` method.

        isStream = (ob) -> isEmitter(ob) and (
            isWritableType(ob) or isReadableType(ob)
        )

        isEmitter = (ob) -> ob? and isFunction(ob.on)
        isWritableType = (ob) -> isFunction(ob?.write) and isFunction(ob?.end)
        isReadableType = (ob) -> isFunction(ob?.pipe)




