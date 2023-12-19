component extends="commandbox.system.BaseCommand" {

	/*
	 * @author Robert Zehnder
	 * Watch for cfml and markdown changes in the current directory, rebuild static files when a change is detected
	 */
	function run(){
		watch()
			.paths( [ "**.cfm", "**.md" ] )
			.inDirectory( resolvePath( "." ) )
			.withDelay( 500 )
			.onChange( function(){
				print.line( "Change detected. Rebuilding..." );
				print.line();
				command( "ssg build" ).run();
			} )
			.start();
	}

}
