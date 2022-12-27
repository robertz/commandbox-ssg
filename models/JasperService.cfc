component accessors="true" {

	property name="JasperService";
	property name="YamlService" inject="Parser@cbyaml";
	property name="processor"   inject="processor@commandbox-jasper";

	function init() {
		return this;
	}

	/**
	 *  Reads a template and returns front matter and template data
	 */
	function getTemplateData( required string fname ) {
		var payload  = {};
		var yaml     = "";
		var body     = "";
		var isCFM    = fname.findNoCase( ".cfm" ) ? true : false;
		var openFile = fileOpen( fname, "read" );
		var lines    = [];
		var payload  = {};

		try {
			while ( !fileIsEOF( openFile ) ) {
				arrayAppend( lines, fileReadLine( openFile ) );
			}
		} catch ( any e ) {
			rethrow;
		} finally {
			fileClose( openFile );
		}
		// front matter should be at the start of the file
		var fms = !isCFM ? lines.find( "---" ) : lines.find( "<!---" ); // front matter start

		if ( fms == 1 ) {
			var fme = !isCFM ? lines.findAll( "---" )[ 2 ] : lines.findAll( "--->" )[ 1 ]; // front matter end
			lines.each( ( line, index ) => {
				if ( index > 1 && index < fme ) yaml &= lines[ index ] & chr( 10 );
				if ( index > fme ) body &= lines[ index ] & chr( 10 );
			} );
			if ( yaml.len() ) payload.append( YamlService.deserialize( trim( yaml ) ) );
		} else {
			body = arrayToList( lines, chr( 10 ) );
		}
		payload[ "content" ] = processor.toHtml( body );

		return payload;
	}

	/**
	 * Get a list of valid templates in the specified file path, recursively
	 */
	function list( required string path ) {
		var templates = directoryList( path, true, "query", "*.md|*.cfm" );

		templates = queryExecute(
			"
				SELECT *
				FROM templates t
				WHERE lcase(t.directory) NOT LIKE '%_includes%'",
			[],
			{ "dbtype" : "query" }
		);
		return templates
	}

	/**
	 * returns rendered html for a template and view
	 *
	 * @prc request context for the current page
	 * @collections application generated data
	 */
	function renderTemplate( required struct prc, required struct collections ) {
		var renderedHtml = "";
		var computedPath = prc.directory.replace( prc.rootDir, "" );
		// render the view based on prc.type
		if ( prc.inFile.findNoCase( ".cfm" ) ) {
			savecontent variable="renderedHtml" {
				include prc.directory & "/" & prc.fileSlug & ".cfm";
			}
		} else {
			savecontent variable="renderedHtml" {
				include prc.rootDir & "/_includes/" & prc.type & ".cfm";
			}
		}
		// skip layout if "none" is specified
		if ( prc.layout != "none" ) {
			savecontent variable="renderedHtml" {
				include prc.rootDir & "/_includes/layouts/" & prc.layout & ".cfm";
			}
		}
		// a little whitespace management
		return trim( renderedHtml );
	}

	/**
	 * a function to quickly paginate data
	 *
	 * @data the data to be paginated
	 * @pageSize items per page
	 */
	function paginate( required array data, required numeric pageSize ) {
		var output       = [];
		var currentChunk = 1;

		if ( pageSize > 1 ) output[ 1 ] = [];
		data.each( ( item, index ) => {
			if ( pageSize > 1 ) {
				output[ currentChunk ].append( item );
			} else {
				output.append( item );
			}
			if ( index % pageSize == 0 && index < data.len() && pageSize > 1 ) output[ ++currentChunk ] = [];
		} );
		return output;
	}

	/**
	 * Generate a slug for a given input
	 * https://stackoverflow.com/questions/36856269/coldfusion-regex-to-generate-slug
	 *
	 * @input a string you would like to slugify
	 * @spacer default spacer is a dash
	 */
	function generateSlug( required string input, string spacer = "-" ) {
		var ret = replace( arguments.input, "'", "", "all" );
		ret     = trim( reReplaceNoCase( ret, "<[^>]*>", "", "ALL" ) );
		ret     = replaceList(
			ret,
			"À,Á,Â,Ã,Ä,Å,Æ,È,É,Ê,Ë,Ì,Í,Î,Ï,Ð,Ñ,Ò,Ó,Ô,Õ,Ö,Ø,Ù,Ú,Û,Ü,Ý,à,á,â,ã,ä,å,æ,è,é,ê,ë,ì,í,î,ï,ñ,ò,ó,ô,õ,ö,ø,ù,ú,û,ü,ý,&nbsp;,&amp;",
			"A,A,A,A,A,A,AE,E,E,E,E,I,I,I,I,D,N,O,O,O,O,O,0,U,U,U,U,Y,a,a,a,a,a,a,ae,e,e,e,e,i,i,i,i,n,o,o,o,o,o,0,u,u,u,u,y, , "
		);
		ret = trim( reReplace( ret, "[[:punct:]]", " ", "all" ) );
		ret = reReplace( ret, "[[:space:]]+", "!", "all" );
		ret = reReplace( ret, "[^a-zA-Z0-9!]", "", "ALL" );
		ret = trim( reReplace( ret, "!+", arguments.spacer, "all" ) );
		return lCase( ret );
	}

}
