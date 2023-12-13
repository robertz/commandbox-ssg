component extends="commandbox.system.BaseCommand" {

	function run(){
		systemCacheClear();

		var files = globber( [
			resolvePath( "." ) & "**.cfm",
			resolvePath( "." ) & "**.md"
		] ).setExcludePattern( [
				resolvePath( "." ) & "_includes/",
				resolvePath( "." ) & ".netlify/"
			] )
			.asArray()
			.matches();

		print.line( files );
	}

}
