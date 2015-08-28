## pipelayer

The pipelayer function is defined using a class, but really it's abusing the
class structure to implement the Template Method pattern.  Instances are never
created: instead, the function prototype is always used as `this`.  In this
way, new "subclasses" can be created with different plugins or even changed
meta-level behaviors.  `autocreate` is used to direct function calls to the
prototype `augment()` method, which is where all the real action takes place.

    autocreate = require('autocreate')

    module.exports = class pipelayer
        pipelayer = autocreate(this)
        constructor: -> throw new TypeError "Not a constructor"
        __class_call__: (stream) -> @augment(stream)


### Plugins and Subclasses

Plugins are kept as an object on the prototype; the plugins of each "subclass"
inherit from the parent class's plugins.  Subclasses are `__proto__`-based,
using `autocreate`.

        plugins: Object.create(null)

        @withPlugins: -> @::subclass()::definePlugins(arguments...)

        subclass: ->
            cls = autocreate.subclass(@constructor)
            cls::plugins = Object.create(@plugins)
            return cls

When plugins are defined, they're arranged as properties lazily delegating to
the original plugin source, cached on `plugins`, and also delegated to by
static properties on the "constructor".

        definePlugins: (obj, names=Object.keys(obj)) ->
            @copyProps(@plugins, obj, names, yes, this)
            return @copyProps(@constructor, @plugins, names)


### Augmentation and .pipe() Chaining

Streams are augmented by adding properties that delegate to `plugins`, after
hooking their `.pipe()` method to perform augmentation recursively or
"virally".  A static `.pipe()` method is included to bootstrap static plugins.

The hooked `.pipe()` keeps track of every stream chained in the current
pipeline, allowing a composed transform stream to be created by calling
`.pipe()` with no arguments.

        augment: (stream, heads) ->
            @copyProps(@hookPipe(stream, heads), @plugins)

        @pipe: (stream) -> @::augment(stream)

        ys = require('yieldable-streams')

        hookPipe: (stream, heads=[]) ->
            # Only modify .pipe() if it already exists
            return stream unless isFunction(oldPipe = stream?.pipe)

            stream.pipe = (dest, opts) =>
                streams = heads.concat([stream])
                if dest?
                    # Standard pipe, augment it and track the heads
                    return @augment(oldPipe.apply(stream, arguments), streams)

                else if not heads.length and this is pipelayer::
                    # Somebody called .pipe().pipe()
                    return stream

                # Create a pipeline or duplex stream, w/plugin-free .pipe()
                else return pipelayer::hookPipe(
                    if streams.length > 1
                        ys.pipeline(streams, noPipe: yes)
                    else ys.duplexify(stream, stream)
                )

            return stream


### Property Copying

In order to define and use plugins, pipelayer makes extensive use of ES5
properties.  The `copyProps()` method creates configurable, overwritable
get/set properties on a destination object that read from a source object, and
overwrite themselves with plain properties if assigned to.  Properties on the
destination (whether own- or inherited) are not overwritten unless the
overwrite flag is set.

        enumerable = configurable = writable = yes

        copyProps: (dest, src, names, overwrite, layer) ->
            copy = (name) ->
                return unless overwrite or name not of dest
                Object.defineProperty dest, name, {
                    enumerable, configurable,

If the `layer` object is provided, it's assumed to be `pipelayer.prototype` or
a derivative prototype thereof, and its `wrapPlugin()` method will be called
with the source value, the first time a given property is accessed on the
destination.  The result will then be cached as a normal property on `dest`.

                    get: if layer
                              -> dest[name] = layer.wrapPlugin(src[name])
                         else -> src[name],

                    set: (value) -> Object.defineProperty(
                        this, name, {configurable, enumerable, writable, value}
                    )
                }

An explicit list of properties can be given, but if it's omitted, then delegate
properties are created for *all* of the source's enumerable properties,
including inherited ones.  (This is mainly useful for `plugins`, which has a
null root prototype.)

            if names then names.forEach(copy)
            else for name of src then copy(name)
            return dest


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
        isWritableType = (ob) -> isFunction(ob.write) and isFunction(ob.end)
        isReadableType = (ob) -> isFunction(ob.pipe)




