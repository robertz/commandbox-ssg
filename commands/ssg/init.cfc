component extends="commandbox.system.BaseCommand" {

	/**
	 * @author Robert Zehnder
	 * Initialize the current directory with the ssg-skeleton app
	 */
	function run( string name = "SSG Project", boolean verbose = false ){
		var pwd = resolvePath( "." );

		var contents = directoryList( pwd, false, "name" );
		if ( contents.len() ) {
			return error( "Directory is not empty." );
		}

		command( "install commandbox-ssg-skeleton" ).run();

		print.greenLine( "SSG project scaffolded." );
	}

}
