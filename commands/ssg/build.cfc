component extends="commandbox.system.BaseCommand" {

	property name="YamlService" inject="Parser@cbyaml";
	property name="processor" inject="processor@commandbox-ssg";
	property name="fileSystemUtil" inject="FileSystem";
	property name="cwd";
	property name="templates";
	property name="collections";
	property name="process";
	property name="baseData";
	property name="config";
	property name="ignoreDirs";
	property name="buildTime";

	/**
	 * Test harness
	 */
	function run(){
		buildTime   = getTickCount();
		cwd         = fileSystemUtil.normalizeSlashes( resolvePath( "." ) );
		templates   = [];
		collections = { "all" : [], "tags" : [], "byTag" : {}, "global" : {} };
		process     = {};
		baseData    = { "layouts" : {}, "views" : {} };
		config      = { "outputDir" : "_site", "passthru" : [], "ignore" : [] };
		ignoreDirs  = [ cwd & "_includes", cwd & ".*" ];

		pagePoolClear();

		getProcessConfig();
		if ( process.hasConfig ) getSSGConfig();
		if ( process.hasIncludes ) getIncludes();
		if ( process.hasData ) getGlobalData();
		if ( process.applicationHelper ) getApplicationHelper();

		process[ "verbose" ] = arguments.keyExists( "verbose" ) ? true : false;

		if ( variables.keyExists( "onBuildReady" ) ) {
			try {
				variables[ "onBuildReady" ]( );
			} catch ( any e ) {
				error( "onBuildReady :: " & e.message )
			}
		}

		if ( arguments.keyExists( "showconfig" ) ) {
			print.line();
			print.limeline( "Process" );
			print.line( process );
			print.line();
			print.limeline( "Config" );
			print.line( config );
			return;
		}

		print.line();
		print.yellowLine( "Building source directory: " & cwd );
		print.line();

		// copy assets/directories that should be copied as-is
		processPassthruFiles();

		// Get a list of all files to process
		var templateList = globber( [ cwd & "**.cfm", cwd & "**.md" ] )
			.setExcludePattern( ignoreDirs )
			.asArray()
			.matches();

		print.limeLine( "Found " & templateList.len() & " template(s) for processing..." );
		print.line();

		templateList.each( ( template ) => {
			processTemplate( template );
		} );

		if ( variables.keyExists( "beforeProcessCollections" ) ) {
			try {
				variables[ "beforeProcessCollections" ]( );
			} catch ( any e ) {
				error( "beforeProcessCollections :: " & e.message )
			}
		}

		processCollectionsData();
		processPagination();

		if ( variables.keyExists( "beforeGenerate" ) ) {
			try {
				variables[ "beforeGenerate" ]( );
			} catch ( any e ) {
				error( "beforeGenerate :: " & e.message )
			}
		}

		generateStatic();

		print.line();
		print.greenLine( "Compiled " & collections.all.len() & " template(s) in " & ( ( getTickCount() - buildTime ) / 1000 ) & " seconds" );
		print.line();
	}

	/**
	 * Detect directory structure and setup defaul values
	 *
	 * @process the configuration object
	 */
	function getProcessConfig(){
		process[ "applicationHelper" ] = fileExists( cwd & "_includes/applicationHelper.cfm" );
		process[ "hasIncludes" ]       = directoryExists( cwd & "_includes" ) ? true : false;
		process[ "hasData" ]           = directoryExists( cwd & "_data" ) ? true : false;
		process[ "hasConfig" ]         = fileExists( cwd & "ssg-config.json" ) ? true : false;
		process[ "layouts" ]           = [];
		process[ "views" ]             = [];
	}

	/**
	 * Load the current build configuration from file if it exists, otherweise return defaults
	 */
	function getSSGConfig(){
		config = deserializeJSON( fileRead( cwd & "ssg-config.json", "utf-8" ) );
		for ( var dir in config.ignore ) {
			if ( directoryExists( cwd & dir ) ) ignoreDirs.append( cwd & dir );
		}
	}

	/**
	 * Load layouts and views and any associated front matter
	 */
	function getIncludes(){
		// build arrays of valid layouts/views
		var fileStem = "";
		var tmp      = globber( cwd & "_includes/layouts/*.cfm" ).asArray().matches();
		for ( var layout in tmp ) {
			fileStem = listFirst( getFileFromPath( layout ), "." );
			process.layouts.append( fileStem );
			baseData[ "layouts" ][ fileStem ] = getTemplateData( layout );
			baseData[ "layouts" ][ fileStem ].delete( "content" );
		}
		tmp = globber( cwd & "_includes/*.cfm" )
			.setExcludePattern( [ "/layouts", "applicationHelper.cfm" ] )
			.asArray()
			.matches();
		for ( var view in tmp ) {
			fileStem = listFirst( getFileFromPath( view ), "." );
			process.views.append( fileStem );
			baseData[ "views" ][ fileStem ] = getTemplateData( view );
			baseData[ "views" ][ fileStem ].delete( "content" );
		}
	}

	/**
	 * Load `_data/**.json` files to `collections.global` if any exist
	 */
	function getGlobalData(){
		// load json data into `data` node
		globber( [ cwd & "_data/**.json" ] ).apply( ( dataFile ) => {
			var fileStem  = getFileFromPath( dataFile ).listFirst( "." );
			var pathParts = fileSystemUtil
				.normalizeSlashes( getDirectoryFromPath( dataFile ) )
				.replace( cwd & "_data", "" )
				.listToArray( "/" );

			var obj = collections.global;
			// walk the path tree
			for ( var p in pathParts ) {
				if ( !obj.keyExists( p ) ) obj[ p ] = {};
				obj = obj[ p ];
			}

			obj[ fileStem ] = deserializeJSON( fileRead( dataFile, "utf-8" ) );
		} );
	}

	/**
	 * Get applicationHelper.cfm if it exists
	 */
	function getApplicationHelper(){
		try {
			include cwd & "_includes/applicationHelper.cfm";
		} catch ( any e ) {
			error( "Error loading applicationHelper.cfm :: " & e.message );
		}
	}

	/**
	 * Purge output directory and move static files
	 */
	function processPassthruFiles(){
		// delete the _site directory if it exists
		if ( directoryExists( cwd & "_site" ) ) {
			directoryDelete( cwd & "_site", true );
		}
		// recreate the directory
		directoryCreate( cwd & "_site" );

		try {
			// passthru directories
			for ( var dir in config.passthru ) {
				if ( fileExists( cwd & dir ) ) {
					fileCopy( cwd & dir, cwd & "_site/" & dir );
				} else {
					directoryCopy( cwd & dir, cwd & "_site/" & dir, true );
				}
			}
		} catch ( any e ) {
			error( e.message );
		}
	}

	/**
	 * Builds the PRC scope for a given template
	 *
	 * @template full path to the template to read
	 */
	function processTemplate( template ){
		var prc = {
			"build_start"            : buildTime,
			"fileSlug"               : getFileFromPath( template ).listFirst( "." ),
			"inFile"                 : fileSystemUtil.normalizeSlashes( template ),
			"outFile"                : "",
			"title"                  : "",
			"description"            : "",
			"published"              : true,
			"date"                   : dateTimeFormat( getFileInfo( template ).lastModified, "yyyy-mm-dd HH:nn" ),
			"content"                : "",
			"type"                   : "page",
			"layout"                 : "main",
			"view"                   : "",
			"permalink"              : "",
			"fileExt"                : "html",
			"excludeFromCollections" : false
		};

		// Try reading the front matter from the template
		prc.append( getTemplateData( template ) );

		// merge in layout/view metadata. skip if it overwrites an existing value
		if ( baseData.layouts.keyExists( prc.layout ) ) {
			prc.append( duplicate( baseData.layouts[ prc.layout ] ), false );
		}

		if ( baseData.views.keyExists( prc.type ) && !len( prc.view ) ) {
			prc.append( duplicate( baseData.views[ prc.type ] ), false );
		} else if ( baseData.views.keyExists( prc.view ) && len( prc.view ) ) {
			// `view` overrides `type`, if it exists
			prc.append( duplicate( baseData.views[ prc.view ] ), false );
		}

		// if the template is `published` process it
		if ( isBoolean( prc.published ) && prc.published ) {
			getOutfile( prc );

			// process permalinks
			// todo: clean up
			if ( len( prc.permalink ) ) {
				// permalink was specified, break it apart
				prc.outFile = cwd & "_site" & prc.permalink;

				var temp = prc.permalink.listToArray( "/" ).reverse();
				var slug = temp[ 1 ].listFirst( "." );
				var ext  = temp[ 1 ].listRest( "." );

				prc.permalink = "/" & temp.reverse().toList( "/" );
				prc.fileExt   = len( ext ) ? ext : "html";
			} else {
				// try to calculate the permalink based on the template
				getPermalink( prc );
			}

			// set the view according to type if view is not populated
			if ( !prc.view.len() && prc.type.len() ) {
				prc.view = prc.type;
			}

			// add this template to `collections.all`
			templates.append( prc );
		}
	}

	/**
	 * Generates data for `collections` scope
	 */
	function processCollectionsData(){
		templates.each( ( template ) => {
			if ( !template.excludeFromCollections && !template.keyExists( "pagination" ) ) {
				collections.all.append( template );
				if ( !collections.keyExists( template.type ) && template.type.len() ) collections[ template.type ] = [];

				// do not track the main page if it is paginated data
				if ( template.type.len() && !template.keyExists( "pagination" ) )
					collections[ lCase( template.type ) ].append( template );
			}
		} );

		// Special processing where `type` is post
		if ( collections.keyExists( "post" ) ) {
			// descending date sort
			collections.post.sort( function( e1, e2 ){
				return dateCompare( e2.date, e1.date );
			} );

			// build the taglist
			collections.post.each( ( post ) => {
				for ( var tag in post.tags ) {
					if ( !collections.tags.findNoCase( tag ) ) {
						collections.tags.append( tag );
					}

					var slugifiedTag = generateSlug( tag );
					if ( !collections.byTag.keyExists( slugifiedTag ) ) collections.byTag[ slugifiedTag ] = [];
					collections.byTag[ slugifiedTag ].append( post );
				}
			} );

			collections.tags = collections.tags.sort( "text" );
		}
	}

	/**
	 * Generate templates based on paginated data
	 */
	function processPagination(){
		templates.each( ( prc ) => {
			if ( prc.keyExists( "pagination" ) ) {
				var data      = prc.pagination.data;
				var size      = prc.pagination.keyExists( "size" ) ? prc.pagination.size : 1;
				var targetKey = prc.pagination.keyExists( "alias" ) ? prc.pagination.alias : "pagedData";
				// data is a string, try to retrieve from variables
				if ( isSimpleValue( data ) ) {
					data = structGet( prc.pagination.data );
					// if data is a structure, return the struct key list as an array
					if ( isStruct( data ) ) {
						// if data is a struct, return the struct keys for iteration
						data = structKeyList( data ).listSort( "textnocase", "asc" ).listToArray();
					}
				}
				var paged = paginate( data = data, pageSize = size );
				paged.each( ( page, index ) => {
					var page_prc          = duplicate( prc );
					var rendered_content  = "";
					page_prc[ targetKey ] = page;
					page_prc.permalink    = page_prc.permalink.replace( "{{" & targetKey & "}}", page );
					page_prc.outFile      = cwd & config.outputDir & page_prc.permalink;
					if ( isSimpleValue( prc.pagination.data ) && isStruct( structGet( prc.pagination.data ) ) ) {
						page_prc.append( structGet( prc.pagination.data )[ page ] );
					}
					getPermalink( page_prc );
					collections.all.append( page_prc );
					// tag and template type processing
					if ( page_prc.keyExists( "tags" ) && page_prc.tags.len() ) {
						for ( var tag in page_prc.tags ) {
							if ( !collections.tags.findNoCase( tag ) ) collections.tags.append( tag );
							var slugifiedTag = generateSlug( tag );
							if ( !collections.byTag.keyExists( slugifiedTag ) ) collections.byTag[ slugifiedTag ] = [];
							collections.byTag[ slugifiedTag ].append( page_prc );
						}
					}
					// add page to types
					if ( !collections.keyExists( page_prc.type ) && page_prc.type.len() )
						collections[ page_prc.type ] = [];
					if ( page_prc.type.len() ) collections[ lCase( page_prc.type ) ].append( page_prc );
				} );
			}
		} );
	}

	/**
	 * Write generated content to files
	 */
	function generateStatic(){
		collections.all.each( ( prc ) => {
			if ( prc.published ) {
				var contents = renderTemplate( prc );
				directoryCreate(
					getDirectoryFromPath( prc.outFile ),
					true,
					true
				);

				if ( process.verbose ) {
					print.greyline( "Writing file: /" & replace( prc.outFile, cwd, "", "all" ) & " from file " & replace(
						prc.inFile,
						cwd,
						"",
						"all"
					) );
				} else {
					print.greyline( "Writing file: /" & replace( prc.outFile, cwd, "", "all" ) );
				}

				fileWrite( prc.outFile, contents );
			}
		} );
	}

	// ========================================================================
	// Ancillary methods
	// ========================================================================

	/**
	 * Generate a slug for a given input
	 * https://stackoverflow.com/questions/36856269/coldfusion-regex-to-generate-slug
	 *
	 * @input  a string you would like to slugify
	 * @spacer default spacer is a dash
	 */
	function generateSlug( required string input, string spacer = "-" ){
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

	/**
	 * Calculate the output filename
	 *
	 * @prc request context for the page
	 */
	function getOutfile( required struct prc ){
		var outDir  = "";
		var outFile = "";
		var temp    = "";

		if ( prc.type == "post" ) {
			outFile   = prc.inFile.replace( cwd, "" );
			temp      = outFile.listToArray( "/" ).reverse();
			temp[ 1 ] = ( prc.keyExists( "slug" ) ? prc.slug : prc.fileSlug ) & "." & prc.fileExt;
			outFile   = cwd & "_site/" & temp.reverse().toList( "/" );
		} else {
			if ( len( prc.permalink ) ) {
				outFile = cwd & "_site" & prc.permalink;
			} else {
				outFile = getFileFromPath( prc.inFile ).listFirst( "." );
				outDir  = getDirectoryFromPath( prc.inFile ).replace( cwd, "/" );
				outFile = cwd & "_site" & outDir & outFile & "." & prc.fileExt;
			}
		}
		prc.outfile = fileSystemUtil.normalizeSlashes( outfile );
	}

	/**
	 * Calculate permalink
	 *
	 * @prc request context for the page
	 */
	function getPermalink( required struct prc ){
		var permalink = "";
		permalink     = prc.outFile
			.replace( cwd & "_site/", "" )
			.listToArray( "/" )
			.reverse();
		if ( prc.fileExt == "html" ) permalink[ 1 ] = listFirst( permalink[ 1 ], "." );
		if ( permalink[ 1 ] == "index" ) permalink[ 1 ] = "";
		prc.permalink = "/" & permalink.reverse().toList( "/" );
	}

	/**
	 *  Reads a template and returns front matter and template data
	 *
	 * @fname the name of the template to read
	 */
	function getTemplateData( required string fname ){
		var payload  = {};
		var yaml     = "";
		var body     = "";
		var isCFM    = fname.findNoCase( ".cfm" ) ? true : false;
		var openFile = fileOpen( fname, "read" );
		var lines    = [];

		try {
			while ( !fileIsEOF( openFile ) ) {
				arrayAppend( lines, rTrim( fileReadLine( openFile ) ) );
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
	 * a function to quickly paginate data
	 *
	 * @data     the data to be paginated
	 * @pageSize items per page
	 */
	function paginate( required array data, required numeric pageSize ){
		var output       = [];
		var currentChunk = 1;

		if ( pageSize > 1 ) output[ 1 ] = [];
		data.each( ( item, index ) => {
			if ( pageSize > 1 ) {
				output[ currentChunk ].append( item );
			} else {
				output.append( item, true );
			}
			if ( index % pageSize == 0 && index < data.len() && pageSize > 1 ) output[ ++currentChunk ] = [];
		} );
		return output;
	}

	/**
	 * returns rendered html for a template and view
	 *
	 * @prc request context for the current page
	 */
	function renderTemplate( prc ){
		var renderedHtml = "";
		var template     = "";

		try {
			// template is CF markup
			if ( prc.inFile.findNoCase( ".cfm" ) ) {
				if ( process.hasIncludes && process.views.find( prc.view ) && prc.layout != "none" ) {
					// render the cfml in the template first
					template = fileSystemUtil.makePathRelative( prc.inFile );

					savecontent variable="prc.content" {
						include template;
					}

					// overlay the view
					template = fileSystemUtil.makePathRelative( cwd & "_includes/" & prc.view & ".cfm" );

					savecontent variable="renderedHtml" {
						include template;
					}
				} else {
					// view was not found, just render the template
					template = fileSystemUtil.makePathRelative( prc.inFile );

					savecontent variable="renderedHtml" {
						include template;
					}
				}
			}
			// template is markdown
			if ( prc.inFile.findNoCase( ".md" ) ) {
				if ( process.hasIncludes && process.views.find( prc.view ) ) {
					template = fileSystemUtil.makePathRelative( cwd & "_includes/" & prc.view & ".cfm" );

					savecontent variable="renderedHtml" {
						include template;
					}
				} else {
					renderedHtml = prc.content;
				}
			}
			// skip layout if "none" is specified
			if (
				prc.layout != "none" &&
				process.hasIncludes &&
				process.layouts.find( prc.layout )
			) {
				template = fileSystemUtil.makePathRelative( cwd & "_includes/layouts/" & prc.layout & ".cfm" );

				savecontent variable="renderedHtml" {
					include template;
				}
			}
		} catch ( any e ) {
			error( prc.inFile & " :: " & e.message );
		}
		// a little whitespace management
		return trim( renderedHtml );
	}

}
