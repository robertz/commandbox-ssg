component {

	this.name         = "cbyaml";
	this.author       = "Eric Peterson";
	this.webUrl       = "https://github.com/elpete/cbyaml";
	this.cfmapping    = "cbyaml";
	this.dependencies = [ "cbjavaloader" ];

	function configure() {
		settings = { "autoLoadHelpers" : true };
	}

	function onLoad() {
		wirebox.getInstance( "loader@cbjavaloader" ).appendPaths( variables.modulePath & "/lib" );

		if ( variables.keyExists( "controller" ) && settings.autoLoadHelpers ) {
			var helpers = controller.getSetting( "applicationHelper" );
			helpers.append( "#moduleMapping#/helpers.cfm" );
			controller.setSetting( "applicationHelper", helpers );
		}
	}

	function onUnload() {
		if ( variables.keyExists( "controller" ) && settings.autoLoadHelpers ) {
			controller.setSetting(
				"applicationHelper",
				controller
					.getSetting( "applicationHelper" )
					.filter( function( helper ) {
						return helper != "#moduleMapping#/helpers.cfm";
					} )
			);
		}
	}

}
