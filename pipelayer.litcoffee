# pipelayer

    autocreate = require('autocreate')

    module.exports = class Pipelayer

        Pipelayer = autocreate(this)

        @withPlugins: -> this

        __class_call__: (stream) -> stream
