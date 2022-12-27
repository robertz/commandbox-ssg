component extends="commandbox.system.BaseCommand" {

	function run() {
		var files = directoryList(
			fileSystemUtil.resolvePath( "src/posts" ),
			false,
			"query"
		);
		print.line( files );
	}

}
