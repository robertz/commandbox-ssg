/**
 * I generate a static site from the current working directory
 */
component extends="commandbox.system.BaseCommand" {

	property name="process";
	property name="SSGService" inject="SSGService@commandbox-ssg";
	property name="fsUtil" inject="Filesystem";

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
			outFile   = prc.inFile.replace( prc.rootDir, "" );
			temp      = outFile.listToArray( "/" ).reverse();
			temp[ 1 ] = ( prc.keyExists( "slug" ) ? prc.slug : prc.fileSlug ) & "." & prc.fileExt;
			outFile   = prc.rootDir & "/_site/" & temp.reverse().toList( "/" );
		} else {
			if ( len( prc.permalink ) ) {
				outFile = prc.rootDir & "/_site" & prc.permalink;
			} else {
				// outFile = prc.inFile.replace( prc.rootDir, "" ).listFirst( "." );
				outFile = getFileFromPath( prc.inFile.replace( prc.rootDir, "" ) ).listFirst( "." );
				outDir  = getDirectoryFromPath( prc.inFile ).replace( prc.rootDir, "" );
				outFile = prc.rootDir & "/_site" & outDir & outFile & "." & prc.fileExt;
			}
		}
		return fsUtil.normalizeSlashes( outfile );
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
		pagePoolClear();

		var cwd       = fsUtil.normalizeSlashes( resolvePath( "." ) );
		var rootDir   = left( cwd, len( cwd ) - 1 ); // remove trailing slash to match directoryList query
		var baseData  = { "layouts" : {}, "views" : {} }; // cache front matter from templates and views
		var file_stem = ""; // filename without extension

		variables.process = {
			"has_includes" : directoryExists( cwd & "_includes" ) ? true : false,
			"has_data"     : directoryExists( cwd & "_data" ) ? true : false,
			"has_config"   : fileExists( cwd & "ssg-config.json" ) ? true : false,
			"layouts"      : [],
			"views"        : []
		};

		if ( process.has_includes ) {
			// build arrays of valid layouts/views
			var tmp = globber( cwd & "_includes/layouts/*.cfm" ).asArray().matches();
			for ( var l in tmp ) {
				file_stem = listFirst( getFileFromPath( l ), "." );
				process.layouts.append( file_stem );
				baseData.layouts[ file_stem ] = SSGService.getTemplateData( l );
				baseData.layouts[ file_stem ].delete( "content" );
			}
			tmp = globber( cwd & "_includes/*.cfm" )
				.setExcludePattern( "/layouts" )
				.asArray()
				.matches();
			for ( var v in tmp ) {
				file_stem = listFirst( getFileFromPath( v ), "." );
				process.views.append( file_stem );
				baseData.views[ file_stem ] = SSGService.getTemplateData( v );
				baseData.views[ file_stem ].delete( "content" );
			}
		}

		// paginated templates that should be removed before render
		var paginated_templates = [];


		// delete the _site directory if it exists
		if ( directoryExists( cwd & "_site" ) ) directoryDelete( cwd & "_site", true );
		// recreate the directory
		directoryCreate( cwd & "_site" );

		print.line();
		print.yellowLine( "Building source directory: " & rootDir );
		print.line();

		// get the configuration
		var conf = {};
		if ( process.has_config ) {
			conf = deserializeJSON( fileRead( cwd & "ssg-config.json", "utf-8" ) );
			if ( !conf.keyExists( "ignore" ) ) {
				conf[ "ignore" ] = [];
			}
		} else {
			conf = { "outputDir" : "_site", "passthru" : [], "ignore" : [] };
		}

		// passthru directories
		for ( var dir in conf.passthru ) {
			if ( fileExists( rootDir & dir ) ) {
				fileCopy( rootDir & dir, rootDir & "/_site" & dir );
			} else {
				directoryCopy( rootDir & dir, rootDir & "/_site" & dir, true );
			}
		}

		// ability to ignore directories when generating the build
		var ignoreDirs = [ cwd & "_includes", cwd & ".*" ];

		if ( conf.keyExists( "ignore" ) ) {
			for ( var dir in conf.ignore ) {
				ignoreDirs.append( rootDir & dir );
			}
		}

		var templateList = globber( [ cwd & "**.cfm", cwd & "**.md" ] )
			.setExcludePattern( ignoreDirs )
			.asQuery()
			.matches();

		var collections = { "all" : [], "tags" : [] };

		// build initial prc
		templateList.each( function( template ){
			var prc = {
				"build_start"            : getTickCount(),
				"rootDir"                : rootDir,
				"directory"              : fsUtil.normalizeSlashes( template.directory ),
				"fileSlug"               : template.name.listFirst( "." ),
				"inFile"                 : fsUtil.normalizeSlashes( template.directory & "/" & template.name ),
				"outFile"                : "",
				"headers"                : [],
				// core properties
				"title"                  : "",
				"description"            : "",
				"image"                  : "",
				"published"              : true,
				"publishDate"            : "",
				// other
				"content"                : "",
				"type"                   : "page",
				"layout"                 : "main",
				"view"                   : "",
				"permalink"              : "",
				"fileExt"                : "html",
				"excludeFromCollections" : false
			};

			// ensure the config does not mutate
			prc.append( duplicate( conf ) );

			// Try reading the front matter from the template
			prc.append( SSGService.getTemplateData( fname = template.directory & "/" & template.name ) );

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
				prc[ "outFile" ] = getOutfile( prc = prc );

				// process permalinks
				// todo: clean up
				if ( len( prc.permalink ) ) {
					// permalink was specified, break it apart
					prc.outFile = rootDir & "/_site" & prc.permalink;

					var temp = prc.permalink.listToArray( "/" ).reverse();
					var slug = temp[ 1 ].listFirst( "." );
					var ext  = temp[ 1 ].listRest( "." );

					prc.permalink = "/" & temp.reverse().toList( "/" );
					prc.fileExt   = len( ext ) ? ext : "html";
				} else {
					// try to calculate the permalink based on the template
					prc.permalink = getPermalink( prc );
				}

				// set the view according to type if view is not populated
				if ( !prc.view.len() && prc.type.len() ) {
					prc.view = prc.type;
				}

				// add this template to `collections.all`
				collections.all.append( prc );
			}
		} ); // templateList each


		/**
		 * Post-processing templates
		 */

		// build tag list and collections by tag
		collections[ "tags" ]  = [];
		collections[ "byTag" ] = {};

		// build template list by type
		collections.all.each( function( template ){
			if ( !collections.keyExists( template.type ) && template.type.len() ) collections[ template.type ] = [];
			if ( template.type.len() ) collections[ lCase( template.type ) ].append( template );
		} );

		// Special processing where `type` is post
		if ( collections.keyExists( "post" ) ) {
			// descending date sort
			collections.post.sort( function( e1, e2 ){
				return dateCompare( e2.publishDate, e1.publishDate );
			} );

			// build the taglist
			collections.post.each( function( post ){
				for ( var tag in post.tags ) {
					if ( !collections.tags.findNoCase( tag ) ) {
						collections.tags.append( tag );
					}

					var slugifiedTag = SSGService.generateSlug( input = tag );
					if ( !collections.byTag.keyExists( slugifiedTag ) ) collections.byTag[ slugifiedTag ] = [];
					collections.byTag[ slugifiedTag ].append( post );
				}
			} );

			collections.tags = collections.tags.sort( "text" );
		}

		/*
		 * Pagination handling
		 */
		collections.all.each( function( prc, index ){
			if ( prc.keyExists( "pagination" ) ) {
				// main paginated templates are removed from `collections.all` and replaced with rendered pages
				paginated_templates.append( index );
				var data      = prc.pagination.data;
				var size      = prc.pagination.keyExists( "size" ) ? prc.pagination.size : 1;
				var targetKey = prc.pagination.keyExists( "alias" ) ? prc.pagination.alias : "pagedData";
				var paged     = SSGService.paginate( data = data, pageSize = size );
				paged.each( ( page, index ) => {
					var page_prc          = duplicate( prc );
					var rendered_content  = "";
					page_prc[ targetKey ] = page;
					page_prc.permalink    = page_prc.permalink.replace( "{{" & targetKey & "}}", page );
					page_prc.outFile      = cwd & prc.outputDir & page_prc.permalink;
					page_prc.delete( "pagination" );
					collections.all.append( page_prc );
				} );
			}
		} );
		/*
		 * END: Pagination handling
		 */

		// remove original templates with pagination
		paginated_templates = paginated_templates.sort( "numeric", "desc" );
		paginated_templates.each( function( idx ){
			collections.all.deleteAt( idx );
		} );

		var generated_templates = 0;

		// Everything has been generated, write it out to _site folder
		collections.all.each( ( prc ) => {
			if ( prc.published ) {
				var contents = SSGService.renderTemplate(
					prc         = prc,
					collections = collections,
					process     = process
				);
				// .listToArray( chr( 10 ) );

				// var cleaned = [];
				// for ( var c in contents ) {
				// 	if ( !len( trim( c ) ) == 0 ) cleaned.append( c );
				// }

				directoryCreate(
					getDirectoryFromPath( prc.outFile ),
					true,
					true
				);

				// fileWrite( prc.outFile, cleaned.toList( chr( 10 ) ) );
				print.greyline( "Writing file: " & replace( prc.outFile, rootDir, "", "all" ) );
				fileWrite( prc.outFile, contents );
				generated_templates++;
			}
		} ); // collections.all.each

		print.line();
		print.greenLine( "Compiled " & generated_templates & " template(s) in " & ( getTickCount() - startTime ) & "ms." );
		print.line();
	}

}
