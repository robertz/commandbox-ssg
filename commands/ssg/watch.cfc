/**
 * I watch the current working directory for changes and rebuild the static site when detected
 */
component extends="commandbox.system.BaseCommand" {

	/*
	 * Watch for cfml and markdown changes in the current directory, rebuild static files when a change is detected
	 */
	function run(){
		watch()
			.paths( [
				"**.cfm",
				"**.md",
				"**.css",
				"**.js",
				"**.json"
			] )
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
