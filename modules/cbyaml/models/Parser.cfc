component singleton {

	property name="jLoader" inject="loader@cbjavaloader";

	function serialize( required any content ) {
		var options = jLoader.create( "org.yaml.snakeyaml.DumperOptions" ).init();
		options.setDefaultFlowStyle( jLoader.create( "org.yaml.snakeyaml.DumperOptions$FlowStyle" ).BLOCK );
		var yamlLoader = jLoader.create( "org.yaml.snakeyaml.Yaml" ).init( options );
		return yamlLoader.dump( toCF( arguments.content ) );
	}

	function serializeToFile( required any content, required string path ) {
		fileWrite( arguments.path, this.serialize( arguments.content ) );
	}

	function deserialize( required string content ) {
		var yamlLoader = jLoader.create( "org.yaml.snakeyaml.Yaml" );
		return toCF( yamlLoader.load( arguments.content ) );
	}

	function deserializeFile( required string path ) {
		var yamlLoader  = jLoader.create( "org.yaml.snakeyaml.Yaml" );
		var file        = jLoader.create( "java.io.File" ).init( arguments.path );
		var inputStream = jLoader.create( "java.io.FileInputStream" ).init( file );
		return yamlLoader.load( inputStream );
	}

	/**
	 * Converts a Java object to native CFML structure
	 *
	 * @param Object Map  	The Java map object or array to be converted
	 */
	function toCF( map ) {
		if ( isNull( arguments.map ) ) {
			return;
		}

		// if we're in a loop iteration and the array item is simple, return it
		if ( isSimpleValue( arguments.map ) ) {
			if ( reFind( "^(true|false)$", arguments.map ) ) {
				return arguments.map == "true";
			}
			return arguments.map;
		}

		if ( isArray( map ) ) {
			var cfObj = [];
			for ( var obj in arguments.map ) {
				arrayAppend( cfObj, toCF( obj ) );
			}
		} else {
			var cfObj = {};
			try {
				cfObj.putAll( arguments.map );
			} catch ( any e ) {
				return arguments.map;
			}

			// loop our keys to ensure first-level items with sub-documents objects are converted
			for ( var key in cfObj ) {
				if ( !isNull( cfObj[ key ] ) ) {
					cfObj[ key ] = toCF( cfObj[ key ] );
				}
			}
		}

		return cfObj;
	}

}
