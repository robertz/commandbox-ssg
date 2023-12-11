component {

	function run( string name = "SSG Project", boolean verbose = false ){
		var pwd = resolvePath( "." );

		var contents = directoryList( pwd, false, "name" );
		if ( contents.len() ) {
			return error( "Directory is not empty." );
		}

		command( "coldbox create app" )
			.params(
				name     = arguments.name,
				skeleton = "robertz/ssg-skeleton",
				verbose  = arguments.verbose
			)
			.run();

		var files = directoryList(
			path     = resolvePath( "ssg-skeleton" ),
			recurse  = true,
			listInfo = "query",
			type     = "file"
		);

		files.each( ( file ) => {
			directoryCreate(
				file.directory.replace( "/ssg-skeleton", "" ),
				true,
				true
			);
			fileWrite(
				trim( file.directory.replace( "/ssg-skeleton", "" ) & "/" & file.name ),
				fileRead( file.directory & "/" & file.name ),
				"utf-8"
			);
			print.greenLine( "Writing " & file.directory.replace( "/ssg-skeleton", "" ) & "/" & file.name );
		} );

		directoryDelete( resolvePath( "ssg-skeleton" ), true );

		print.greenLine( "SSG project scaffolded." );
	}

}
