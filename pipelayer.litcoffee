# pipelayer

    autocreate = require('autocreate')

    module.exports = class pipelayer

        pipelayer = autocreate(this)

        constructor: -> throw new TypeError "Not a constructor"

        __class_call__: (stream) -> @augment(stream)

        @withPlugins: -> @::subclass()::definePlugins(arguments...)

        plugins: Object.create(null)

        subclass: ->
            cls = autocreate.subclass(@constructor)
            cls::plugins = Object.create(@plugins)
            return cls

        definePlugins: (obj, names=Object.keys(obj)) ->
            @copyProps(@plugins, obj, names, yes, @pluginWrapper())
            return @copyProps(@constructor, @plugins, names)

        augment: (stream) -> stream

        copyProps: (dest) -> dest

        pluginWrapper: -> (ctx, name, plugin) -> plugin
