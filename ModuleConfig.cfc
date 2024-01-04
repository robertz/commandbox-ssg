component {

	this.modelNamespace = "commandbox-ssg";
	this.cfmapping      = "commandbox-ssg";

	function configure(){
	}

	function preCommand(){
		pagePoolClear();
		// systemCacheClear();
		wirebox.getInstance( "moduleService" ).reload( "commandbox-ssg" );
	}

}
