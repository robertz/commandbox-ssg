<cfscript>

function serializeYaml( required any content ) {
    return application.wirebox.getInstance( "Parser@cbyaml" ).serialize( arguments.content );
}

function deserializeYaml( required string content ) {
    return application.wirebox.getInstance( "Parser@cbyaml" ).deserialize( arguments.content );
}

</cfscript>
