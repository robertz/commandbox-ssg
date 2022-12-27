component extends="commandbox.system.BaseCommand" {

	function run() {
		watch()
			.paths( [ "**.cfm", "**.md" ] )
			.inDirectory( resolvePath( "." ) )
			.withDelay( 500 )
			.onChange( function() {
				print.line( "Change detected. Rebuilding..." );
				print.line();
				command( "jasper build" ).run();
			} )
			.start();
	}

}
