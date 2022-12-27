# cbyaml

[![Master Branch Build Status](https://img.shields.io/travis/elpete/cbyaml/master.svg?style=flat-square&label=master)](https://travis-ci.org/elpete/cbyaml)

## Provides easy serialization and deserialization of yaml files

### Parser component

There is only one component provided by `cbyaml`, the `Parser` component.
You can inject it using the `Parser@cbyaml` mapping.

There are four methods on the Parser:

```js
function serialize( required any content );
function serializeToFile( required any content, required string path );
function deserialize( required string content );
function deserializeFile( required string path );
```

> CAUTION: When serializing content to yaml, the key order will not be preserved
unless you are using an ordered struct, a `LinkedHashMap`, or a similar data structure.

### Application Helpers

Application helpers are automatically registered to be used in your handlers and views.

```js
function serializeYaml( required any content );
function deserializeYaml( required string content );
```

These call the `parser.serialize` and `parser.deserialize` methods under the hood.

You can disable this by setting `settings.autoLoadHelpers = false`.

### Mixins

You can also use the `serializeYaml` and `deserializeYaml` helpers in any model
by utilizing [WireBox's mixins](https://wirebox.ortusbooks.com/advanced-topics/runtime-mixins).

```js
component mixins="/cbyaml/helpers" {

    function parse( required string content ) {
        return deserializeYaml( arguments.content );
    }

    function stringify( required any content ) {
        return serializeYaml( arguments.content );
    }

}
```
