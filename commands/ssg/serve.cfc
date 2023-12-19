component extends="commandbox.system.BaseCommand" {

	/**
	 * Startup a static web server to handle showing content
	 *
	 * @author Robert Zehnder
	 */
	function run(){
		var cwd      = resolvePath( "." );
		var htaccess = [
			"RewriteEngine On",
			"RewriteCond %{REQUEST_FILENAME} !-f",
			"RewriteCond %{REQUEST_FILENAME} !-d",
			"RewriteRule ^([^\.]+)$ $1.html [NC,L]"
		];
		var server_json =
		{
			"app" : { "cfengine" : "none" },
			"web" : {
				"rewrites" : { "config" : ".htaccess", "enable" : "true" },
				"webroot"  : "_site/"
			}
		};

		if ( !fileExists( cwd & ".htaccess" ) ) {
			fileWrite(
				cwd & ".htaccess",
				htaccess.toList( chr( 10 ) ),
				"utf-8"
			);
		}

		if ( !fileExists( cwd & "server.json" ) ) {
			fileWrite(
				cwd & "server.json",
				serializeJSON( server_json ),
				"utf-8"
			);
		}

		command( "start" ).run();
	}

}
