component {

	LIB_PATHS = directoryList(
		getDirectoryFromPath( getCurrentTemplatePath() ) & "lib",
		false,
		"path"
	);

	JSoup function init(){
		variables.jsoup = createObject( "java", "org.jsoup.Jsoup", LIB_PATHS );
		return this;
	}

	function parse( html ){
		return variables.jsoup.parse( html );
	}

}
