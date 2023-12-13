component extends="commandbox.system.BaseCommand" output="false" {

	property name="SSGService" inject="SSGService@commandbox-ssg";

	/**
	 * Calculate the output filename
	 *
	 * @prc request context for the page
	 */
	function getOutfile( required struct prc ){
		var outFile = "";
		if ( prc.type == "page" ) {
			outFile = prc.inFile.replace( prc.rootDir, "" ).listFirst( "." );
			outFile = prc.rootDir & "/_site" & outFile & "." & prc.fileExt
		} else {
			outFile   = prc.inFile.replace( prc.rootDir, "" );
			var temp  = outFile.listToArray( "/" ).reverse();
			temp[ 1 ] = prc.slug & "." & prc.fileExt;
			outFile   = prc.rootDir & "/_site/" & temp.reverse().toList( "/" );
		}
		return outfile;
	}


	/**
	 * Calculate permalink
	 *
	 * @prc request context for the page
	 */
	function getPermalink( required struct prc ){
		var permalink = "";
		permalink     = prc.outFile
			.replace( prc.rootDir & "/_site", "" )
			.listToArray( "/" )
			.reverse();
		if ( prc.fileExt == "html" ) permalink[ 1 ] = listFirst( permalink[ 1 ], "." );
		if ( permalink[ 1 ] == "index" ) permalink[ 1 ] = "";
		return "/" & permalink.reverse().toList( "/" );
	}

	/**
	 * Generate static site
	 */
	function run(){
		var startTime = getTickCount();

		// make generateSlug available to the variables scope
		variables.generateSlug = SSGService.generateSlug;

		// clear the template cache
		systemCacheClear();

		var rootDir = resolvePath( "." );
		rootDir     = left( rootDir, len( rootDir ) - 1 ); // remove trailing slash to match directoryList query

		// delete the _site directory if it exists
		if ( directoryExists( rootDir & "/_site" ) ) directoryDelete( rootDir & "/_site", true );
		// recreate the directory
		directoryCreate( rootDir & "/_site" );
		// get the configuration
		var conf = deserializeJSON( fileRead( rootDir & "/ssg-config.json", "utf-8" ) );

		// passthru directories
		for ( var dir in conf.passthru ) {
			if ( fileExists( rootDir & dir ) ) {
				fileCopy( rootDir & dir, rootDir & "/_site" & dir )
			} else {
				directoryCopy( rootDir & dir, rootDir & "/_site" & dir, true );
			}
		}

		print.yellowLine( "Building source directory: " & rootDir );

		var templateList = SSGService.list( rootDir );
		var collections  = { "all" : [], "tags" : [] };

		// build initial prc
		templateList.each( ( template ) => {
			var prc = {
				"build_start" : startTime,
				"rootDir"     : rootDir,
				"directory"   : template.directory,
				"fileSlug"    : template.name.listFirst( "." ),
				"inFile"      : template.directory & "/" & template.name,
				"outFile"     : "",
				"headers"     : [],
				"meta"        : {
					"title"       : "",
					"description" : "",
					"author"      : "",
					"url"         : ""
				},
				// core properties
				"title"                  : "",
				"description"            : "",
				"image"                  : "",
				"published"              : false,
				"publishDate"            : "",
				// other
				"content"                : "",
				"type"                   : "page",
				"layout"                 : "main",
				"permalink"              : true,
				"fileExt"                : "html",
				"excludeFromCollections" : false
			};

			// ensure the config does not mutate
			prc.append( duplicate( conf ) );

			// Try reading the front matter from the template
			prc.append( SSGService.getTemplateData( fname = template.directory & "/" & template.name ) );

			prc[ "outFile" ] = getOutfile( prc = prc );

			if ( !isBoolean( prc.permalink ) ) {
				prc.outFile = rootDir & prc.permalink

				var temp = prc.permalink.listToArray( "/" ).reverse();
				var slug = temp[ 1 ].listFirst( "." );
				var ext  = temp[ 1 ].listRest( "." );

				prc.permalink = "/" & temp.reverse().toList( "/" );
				prc.fileExt   = len( ext ) ? ext : "html";
			} else {
				prc.permalink = getPermalink( prc );
			}

			// handle facebook/twitter meta
			switch ( prc.type ) {
				case "post":
					prc.meta.title = prc.meta.title & " - " & prc.title;
					// set social tags
					prc.headers.append( { "property" : "og:title", "content" : "#prc.title#" } );
					prc.headers.append( {
						"property" : "og:description",
						"content"  : "#prc.description#"
					} );
					prc.headers.append( { "property" : "og:image", "content" : "#prc.image#" } );
					prc.headers.append( {
						"name"    : "twitter:card",
						"content" : "summary_large_image"
					} );
					prc.headers.append( { "name" : "twitter:title", "content" : "#prc.title#" } );
					prc.headers.append( {
						"name"    : "twitter:description",
						"content" : "#prc.description#"
					} );
					prc.headers.append( { "name" : "twitter:image", "content" : "#prc.image#" } );
					break;
				default:
					break;
			};

			collections.all.append( prc );
		} ); // templateList each

		// build template list by type
		collections.all.each( ( template ) => {
			if ( !collections.keyExists( template.type ) ) collections[ template.type ] = [];
			collections[ lCase( template.type ) ].append( template )
		} );

		// build tags
		collections[ "tags" ]  = [];
		collections[ "byTag" ] = {};

		if ( collections.keyExists( "post" ) ) {
			// descending date sort
			collections.post.sort( ( e1, e2 ) => {
				return dateCompare( e2.publishDate, e1.publishDate );
			} );

			// build the taglist
			collections.post.each( ( post ) => {
				for ( var tag in post.tags ) {
					if ( !collections.tags.findNoCase( tag ) ) {
						collections.tags.append( tag );
					}

					var slugifiedTag = SSGService.generateSlug( input = tag );
					if ( !collections.byTag.keyExists( slugifiedTag ) ) collections.byTag[ slugifiedTag ] = [];
					collections.byTag[ slugifiedTag ].append( post );
				}
			} );
		}

		// process pagination
		collections.all.each( ( prc ) => {
			if ( prc.keyExists( "pagination" ) ) {
				var data = prc.pagination.data.findNoCase( "collections." ) == 1 ? structGet( prc.pagination.data ) : structGet( "prc." & prc.pagination.data );

				var targetKey = prc.pagination.keyExists( "alias" ) ? prc.pagination.alias : "pagedData";

				prc[ "pagination" ][ targetKey ] = [];

				prc.pagination[ targetKey ].append(
					SSGService.paginate( data = data, pageSize = prc.pagination.size ),
					true
				);

				// prc.pagination[ targetKey ].each( ( el ) => {
				// 	variables[ targetKey ]= el;
				// 	var dupPRC            = duplicate( prc );
				// 	savecontent variable  ="dupPRC.content" {
				// 		writeOutput( prc.content );
				// 	};
				// 	dupPRC.permalink.replace( "{{" & targetKey & "}}", el );
				// 	dupPRC.outFile.replace( "{{" & targetKey & "}}", el );
				// 	collections.all.append( dupPRC );
				// } );
				// generate paginated template
			}
		} );

		// write the files
		collections.all.each( ( prc ) => {
			var computedPath = prc.directory.replace( prc.rootDir, "" );

			var fname     = "";
			var shortName = "";

			if ( lCase( prc.type ) == "post" ) {
				shortName = computedPath & "/" & prc.slug & "." & prc.fileExt;
			} else {
				shortName = computedPath & "/" & prc.fileSlug & "." & prc.fileExt;
			}

			fname = prc.rootDir & "/_site/" & shortName;
			directoryCreate(
				prc.rootDir & "/_site/" & computedPath,
				true,
				true
			);

			if ( !prc.permalink.find( "{{" ) ) {
				var contents = SSGService
					.renderTemplate( prc = prc, collections = collections )
					.listToArray( chr( 10 ) );

				var cleaned = [];
				for ( var c in contents ) {
					if ( !len( trim( c ) ) == 0 ) cleaned.append( c );
				}
				fileWrite( fname, cleaned.toList( chr( 10 ) ) );
			}
		} ); // collections.all.each

		print.greenLine( "Compiled " & collections.all.len() & " template(s) in " & ( getTickCount() - startTime ) & "ms." )
	}

}
