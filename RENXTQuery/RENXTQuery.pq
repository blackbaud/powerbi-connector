// -----------------------------------------------------------------------------
// This file contains the Blackbaud RENXT Query Power Query connector definition
// -----------------------------------------------------------------------------
[Version = "1.0.0"]
section RENXTQuery;

[DataSource.Kind="RENXTQuery", Publish="RENXTQuery.Publish"]
shared RENXTQuery.Contents = () => GetNavigationTable();

// Data Source Kind description
RENXTQuery = [
    // TestConnection is required to enable the connector through the Gateway
    TestConnection = (dataSourcePath) => { "RENXTQuery.Contents" },

    // SKY API uses OAuth implementation
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = RefreshToken,
            Label = Extension.LoadString("ConnectionLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
RENXTQuery.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ConnectorName"), Extension.LoadString("ConnectorTooltip") },
    LearnMoreUrl = "https://docs.blackbaud.com/microsoft-connectors-docs/microsoft-power-platform",
    SourceImage = RENXTQuery.Icons,
    SourceTypeImage = RENXTQuery.Icons
];

RENXTQuery.Icons = [
    Icon16 = { Extension.Contents("b_AppIcon_Round_16.png"), Extension.Contents("b_AppIcon_Round_20.png"), Extension.Contents("b_AppIcon_Round_24.png"), Extension.Contents("b_AppIcon_Round_32.png") },
    Icon32 = { Extension.Contents("b_AppIcon_Round_32.png"), Extension.Contents("b_AppIcon_Round_40.png"), Extension.Contents("b_AppIcon_Round_48.png"), Extension.Contents("b_AppIcon_Round_64.png") }
];

// ---------------------------------------------------------------------------------------
// SKY API Authorization implementation (OAuth2)
// ---------------------------------------------------------------------------------------
client_id = LoadFromResource("keys_client_id.txt");
client_secret = LoadFromResource("keys_client_secret.txt");
authorization_url = "https://oauth2.sky.blackbaud.com/authorization";
token_url = "https://oauth2.sky.blackbaud.com/token";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 615;
windowHeight = 635;

// The StartLogin function will be called when the user clicks "Connect", and will build a record with the
// properties that Power BI needs to initiate the OAuth process
//
// resourceUrl: Derived from the required arguments to the data source function
//              and is used when the OAuth flow requires a specific resource to
//              be passed in, or the authorization URL is calculated (i.e. when
//              the tenant name/ID is included in the URL). In this example, we
//              are hardcoding the use of the "common" tenant, as specified by
//              the 'authorize_uri' variable.
// state:       Client state value we pass through to the service.
// display:     Used by certain OAuth services to display information to the
//              user.
//
// Returns a record containing the following fields:
// LoginUri:     The full URI to use to initiate the OAuth flow dialog.
// CallbackUri:  The return_uri value. The client will consider the OAuth
//               flow complete when it receives a redirect to this URI. This
//               generally needs to match the return_uri value that was
//               registered for your application/client.
// WindowHeight: Suggested OAuth window height (in pixels).
// WindowWidth:  Suggested OAuth window width (in pixels).
// Context:      Optional context value that will be passed in to the FinishLogin
//               function once the redirect_uri is reached.
StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorization_url & "?" & Uri.BuildQueryString([
            response_type = "code",
            client_id = client_id,
            redirect_uri = redirect_uri,
            state = state
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

// FinishLogin will be called once the user has completed the OAuth flow.  If the user
// provided consent, we'll pick off the code from the query string and exchange it for
// an access token.
//
// context:     The value of the Context field returned by StartLogin. Use this to
//              pass along information derived during the StartLogin call (such as
//              tenant ID)
// callbackUri: The callbackUri containing the authorization_code from the service.
// state:       State information that was specified during the call to StartLogin.
FinishLogin = (context, callbackUri, state) =>
    let
        // parse the full callbackUri, and extract the Query string
        parts = Uri.Parts(callbackUri)[Query],

		// if the query string contains an "error" field, raise an error
		// otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    GetToken("authorization_code", parts[code])
    in
        result;

// RefreshToken will be called when the access token has expired and needs to be refreshed
//
// resourceUrl:
// refresh_token:
RefreshToken = (resourceUrl, refresh_token) =>
    GetToken("refresh_token", refresh_token);

// GetToken wraps up calling the OAuth /token endpoint to exchange an authorization code or refresh a token
//
// grantType:   Indicates the grant type (authorization_code or refresh_token)
// code:        The authorization code or refresh token value to exchange
GetToken = (grantType, code) =>
    let
        body = [
            client_id = client_id,
            client_secret = client_secret,
            grant_type = grantType,
            redirect_uri = redirect_uri
        ],

        fieldName =
            if (grantType = "authorization_code") then
                "code"
            else
                "refresh_token",

        bodyWithCode = Record.AddField(body, fieldName, code),

        tokenResponse = Web.Contents(token_url, [
            Content = Text.ToBinary(Uri.BuildQueryString(bodyWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400}
        ]),

        json = Json.Document(tokenResponse),

        result =
            if (Record.HasFields(json, {"error", "error_description"})) then
                error Error.Record(json[error], json[error_description], json)
            else
                json
    in
        json;

// ---------------------------------------------------------------------------------------
// Load helper functions
// ---------------------------------------------------------------------------------------

// Note that in the future, the M language will have better support for refactoring into separate files.  For now, leverage the approach described here:
// https://docs.microsoft.com/en-us/power-query/samples/trippin/7-advancedschema/readme#refactoring-common-code-into-separate-files
Extension.LoadFunction = (fileName as text) =>
  let
      binary = Extension.Contents(fileName),
      asText = Text.FromBinary(binary)
  in
      try
        Expression.Evaluate(asText, #shared)
      catch (e) =>
        error [
            Reason = "Extension.LoadFunction Failure",
            Message.Format = "Loading '#{0}' failed - '#{1}': '#{2}'",
            Message.Parameters = {fileName, e[Reason], e[Message]},
            Detail = [File = fileName, Error = e]
        ];

// Load the helper functions described here, as well as other functions factored into separate files for easier maintenance
// https://learn.microsoft.com/en-us/power-query/helper-functions
Record.RemoveNullFields = Extension.LoadFunction("Record.RemoveNullFields.pqm");

Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Table.GenerateByPage = Extension.LoadFunction("Table.GenerateByPage.pqm");
Table.SchemaTransformTable = Extension.LoadFunction("Table.SchemaTransformTable.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");

Uri.FromParts = Extension.LoadFunction("Uri.FromParts.pqm");
Uri.GetHost = Extension.LoadFunction("Uri.GetHost.pqm");
Uri.ValidateUrlScheme = Extension.LoadFunction("Uri.ValidateUrlScheme.pqm");

Value.WaitFor = Extension.LoadFunction("Value.WaitFor.pqm");

Web.ContentsCustomRetry = (url as text, optional options as record) => Value.WaitFor(
    (i) =>
        let
            options2 = if options = null then [] else options,
            options3 = if i = 0 then options2 else options2 & [IsRetry = true],
            result = Web.Contents(url, options3 & [ManualStatusHandling = {429}]),
            buffered = Binary.Buffer(result), /* avoid risk of double request */
            status = if buffered = null then 0 else Value.Metadata(result)[Response.Status],
            actualResult = if status = 429 then null else buffered
        in
            actualResult,

    (i) => #duration(0, 0, 0, i * 0.1));

// used for loading secrets from files in the project
LoadFromResource = (name as text) as text =>
    try
        Text.FromBinary(Extension.Contents(name))
    otherwise
        error Error.Unexpected(Text.Format(
            Extension.LoadString("resourceNotFound"),
            name
        ));

// ---------------------------------------------------------------------------------------
// Connector implementation
// ---------------------------------------------------------------------------------------
BaseUrl = "https://api.sky.blackbaud.com";
Product = "RE";
Module = "None";

POLL_MAX_RETRIES = 36;
POLL_DELAY_SECONDS = 5;

DefaultRequestHeaders = [
    // default content type
    #"Content-Type" = "application/json",

    // requests to SKY API require a subscription key
    #"Bb-Api-Subscription-Key" = LoadFromResource("keys_subscription_key.txt")
];

// Assign UI-facing functions
RENXTQueryUI.Contents = Value.ReplaceType(RENXTQueryUI, RENXTQueryUIMetadata);
RENXTAdHocQueryUI.Contents = Value.ReplaceType(RENXTAdHocQueryUI, RENXTAdHocQueryUIMetadata);

// ---------------------------------------------------------------------------------------
// UI-facing functions
// ---------------------------------------------------------------------------------------
RENXTQueryUI = (
    queryId as number,
    formattingMode as nullable text,
    sqlGenerationMode as nullable text,
    timeZoneOffsetInMinutes as nullable number,
    useStaticQuery as nullable logical,
    displayCodeTableLongDescription as nullable logical,
    askFields as nullable text
) as table =>
    GetQueryResultsTable(queryId, formattingMode, sqlGenerationMode, timeZoneOffsetInMinutes, useStaticQuery, displayCodeTableLongDescription, askFields);

RENXTAdHocQueryUI = (
    queryDefinition as text,
    formattingMode as nullable text,
    sqlGenerationMode as nullable text,
    timeZoneOffsetInMinutes as nullable number,
    useStaticQuery as nullable logical,
    displayCodeTableLongDescription as nullable logical
) as table =>
    GetQueryResultsTable(queryDefinition, formattingMode, sqlGenerationMode, timeZoneOffsetInMinutes, useStaticQuery, displayCodeTableLongDescription, null);

// --------------------------------------------------------------------------------
// Type functions with UI metadata
// --------------------------------------------------------------------------------

// More information here:
// https://learn.microsoft.com/en-us/power-query/handling-documentation
// https://github.com/microsoft/DataConnectors/blob/master/samples/HelloWorldWithDocs/HelloWorldWithDocs.pq
//
RENXTQueryUIMetadata = type function (
    queryId as QueryIdParameterType,
    formattingMode as FormattingModeParameterType,
    sqlGenerationMode as SqlGenerationModeParameterType,
    timeZoneOffsetInMinutes as TimeZoneOffsetInMinutesParameterType,
    useStaticQuery as UseStaticQueryParameterType,
    displayCodeTableLongDescription as DisplayCodeTableLongDescriptionParameterType,
    askFields as AskFieldsParameterType
) as table meta [
    Documentation.Name = "GetQueryResults",
    Documentation.LongDescription = Extension.LoadString("RENXTQueryUIMetadata.Documentation.LongDescription"),
    Documentation.Examples = {
    [
        Description = Extension.LoadString("RENXTQueryUIMetadata.Example.Description"),
        Code = "= #""Query by ID"".Contents(918, ""None"", ""Query"", -240, false, false, null)",
        Result = Extension.LoadString("RENXTQueryUIMetadata.Example.Result")
    ]}
];

RENXTAdHocQueryUIMetadata = type function (
    queryDefinition as QueryDefinitionParameterType,
    formattingMode as FormattingModeParameterType,
    sqlGenerationMode as SqlGenerationModeParameterType,
    timeZoneOffsetInMinutes as TimeZoneOffsetInMinutesParameterType,
    useStaticQuery as UseStaticQueryParameterType,
    displayCodeTableLongDescription as DisplayCodeTableLongDescriptionParameterType
) as table meta [
    Documentation.Name = "GetQueryResults",
    Documentation.LongDescription = Extension.LoadString("RENXTAdHocQueryUIMetadata.Documentation.LongDescription"),
    Documentation.Examples = {
    [
        Description = Extension.LoadString("RENXTAdHocQueryUIMetadata.Example.Description"),
        Code = "= #""Ad hoc query"".Contents(queryJson, ""None"", ""Query"", -240, false, false)",
        Result = Extension.LoadString("RENXTAdHocQueryUIMetadata.Example.Result")
    ]}    
];

// --------------------------------------------------------------------------------
// Parameter types with UI metadata
// --------------------------------------------------------------------------------

// Note:  Unfortunately, according to these links the Documentation.FieldDescription will not be shown in the UI if the function has metadata applied.  
// Since the function documentation is more comprehensive, we'll have to live without FieldDescription for now.
//  https://community.fabric.microsoft.com/t5/Issues/Documentation-Description/idc-p/1059892/highlight/true#M56225
//  https://ssbi-blog.de/blog/technical-topics-english/writing-documentation-for-custom-m-functions-part3/
QueryIdParameterType = type number meta [
    Documentation.FieldCaption = Extension.LoadString("QueryIdParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("QueryIdParameterType.FieldDescription"),
    Documentation.SampleValues = {"506, 918"}
];

QueryDefinitionParameterType = type text meta [
    Documentation.FieldCaption = Extension.LoadString("QueryDefinitionParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("QueryDefinitionParameterType.FieldDescription"),
    Documentation.SampleValues = { Extension.LoadString("QueryDefinitionParameterType.SampleValues") },
    Formatting.IsMultiLine = true,
    Formatting.IsCode = true
];

FormattingModeParameterType = type nullable text meta [
    Documentation.FieldCaption = Extension.LoadString("FormattingModeParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("FormattingModeParameterType.FieldDescription"),
    Documentation.AllowedValues = {"None", "UI", "Export"}
];

SqlGenerationModeParameterType = type nullable text meta [
    Documentation.FieldCaption = Extension.LoadString("SqlGenerationModeParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("SqlGenerationModeParameterType.FieldDescription"),
    Documentation.AllowedValues = {"Query", "Export", "Report"}
];

TimeZoneOffsetInMinutesParameterType = type nullable number meta [
    Documentation.FieldCaption = Extension.LoadString("TimeZoneOffsetInMinutesParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("TimeZoneOffsetInMinutesParameterType.FieldDescription"),
    Documentation.SampleValues = {"-240"}
];

UseStaticQueryParameterType = type nullable logical meta [
    Documentation.FieldCaption = Extension.LoadString("UseStaticQueryParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("UseStaticQueryParameterType.FieldDescription"),
    Documentation.AllowedValues = {"true", "false"}
];

DisplayCodeTableLongDescriptionParameterType = type nullable logical meta [
    Documentation.FieldCaption = Extension.LoadString("DisplayCodeTableLongDescriptionParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("DisplayCodeTableLongDescriptionParameterType.FieldDescription"),
    Documentation.AllowedValues = {"true", "false"}
];

AskFieldsParameterType = type nullable text meta [
    Documentation.FieldCaption = Extension.LoadString("AskFieldsParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("AskFieldsParameterType.FieldDescription"),
    Documentation.SampleValues = { Extension.LoadString("AskFieldsParameterType.SampleValues") },
    Formatting.IsMultiLine = true,
    Formatting.IsCode = true
];

RequiredAskFieldsParameterType = type text meta [
    Documentation.FieldCaption = Extension.LoadString("AskFieldsParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("AskFieldsParameterType.FieldDescription"),
    Documentation.SampleValues = { Extension.LoadString("AskFieldsParameterType.SampleValues") },
    Formatting.IsMultiLine = true,
    Formatting.IsCode = true
];

// --------------------------------------------------------------------------------
// Navigation tables
// --------------------------------------------------------------------------------
GetNavigationTable = () as table =>
    let
        rows = {
            {"allQueries", GetQueryListNavTable(null, null, null, false, false, false), "Folder", "Folder", false},
            {"myQueries", GetQueryListNavTable(null, null, null, true, false, false), "Folder", "Folder", false},
            {"favorites", GetQueryListNavTable(null, null, null, false, true, false), "Folder", "Folder", false},
            {"mergedQueries", GetQueryListNavTable(null, null, null, false, false, true), "Folder", "Folder", false},
            {"categories", GetQueryCategoryNavTable(), "Folder", "Folder", false},
            {"types", GetQueryTypeNavTable(), "Folder", "Folder", false},
            {"format", GetQueryFormatNavTable(), "Folder", "Folder", false},

            {"queryById", RENXTQueryUI.Contents, "Function", "Function", true},
            {"adHocQuery", RENXTAdHocQueryUI.Contents, "Function", "Function", true}
        },

        // insert the localized name for each node
        rowsWithName = List.Transform(rows, each 
            List.InsertRange(_, 0, { Extension.LoadString(_{0}) })
        ),

        navTable = #table(
            NavigationTableType,
            rowsWithName
        ),

        // Convert to navigation table
        result = Table.ToNavigationTable(navTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        result;

GetQueryListNavTable = (
    categoryId as nullable number,
    typeId as nullable number,
    format as nullable text,
    myQueriesOnly as logical,
    favoritesOnly as logical,
    mergedQueriesOnly as logical
) as table =>
    let
            
        // define a curried function with `id` and `name` bound per row
        curriedFunction = (queryId as number, name as text) => 
            let 
                curried = (
                    formattingMode as nullable text, 
                    sqlGenerationMode as nullable text, 
                    timeZoneOffsetInMinutes as nullable number, 
                    useStaticQuery as nullable logical,
                    displayCodeTableLongDescription as nullable logical
                ) =>
                    GetQueryResultsTable(queryId, formattingMode, sqlGenerationMode, timeZoneOffsetInMinutes, useStaticQuery, displayCodeTableLongDescription, null),
        
                curriedDocs = type function (
                    formattingMode as FormattingModeParameterType,
                    sqlGenerationMode as SqlGenerationModeParameterType,
                    timeZoneOffsetInMinutes as TimeZoneOffsetInMinutesParameterType,
                    useStaticQuery as UseStaticQueryParameterType,
                    displayCodeTableLongDescription as DisplayCodeTableLongDescriptionParameterType
                ) as table meta [
                    Documentation.Name = "GetQueryResults",
                    Documentation.LongDescription = Text.Format(
                        Extension.LoadString("GetQueryResults.Documentation.LongDescriptionName"),
                        {name}
                    ),
                    Documentation.Examples = {
                        [
                            Description = Text.Format(
                                Extension.LoadString("GetQueryListNavTable.Documentation.Description"),
                                {name}
                            ),
                            Code = Text.Format(
                                "= #""#{0}"".Contents(""None"", ""Query"", -240, false, false)",
                                {name}
                            ),
                            Result = Text.Format(
                                Extension.LoadString("GetQueryListNavTable.Documentation.Result"),
                                {name}
                            )
                        ]
                    }
                ]
            in
                Value.ReplaceType(curried, curriedDocs),

        // define a curried function including ask fields with `id` and `name` bound per row
        curriedFunctionWithAskFields = (queryId as number, name as text) => 
            let
                curried = (
                    formattingMode as nullable text, 
                    sqlGenerationMode as nullable text, 
                    timeZoneOffsetInMinutes as nullable number, 
                    useStaticQuery as nullable logical,
                    displayCodeTableLongDescription as nullable logical,
                    askFields as text
                ) =>
                    GetQueryResultsTable(queryId, formattingMode, sqlGenerationMode, timeZoneOffsetInMinutes, useStaticQuery, displayCodeTableLongDescription, askFields),
                
                curriedDocs = type function (
                    formattingMode as FormattingModeParameterType,
                    sqlGenerationMode as SqlGenerationModeParameterType,
                    timeZoneOffsetInMinutes as TimeZoneOffsetInMinutesParameterType,
                    useStaticQuery as UseStaticQueryParameterType,
                    displayCodeTableLongDescription as DisplayCodeTableLongDescriptionParameterType,
                    askFields as RequiredAskFieldsParameterType
                ) as table meta [
                    Documentation.Name = "GetQueryResults",
                    Documentation.LongDescription = Text.Format(
                        Extension.LoadString("GetQueryResults.Documentation.LongDescriptionName"),
                        {name}
                    ),
                    Documentation.Examples = {
                        [
                            Description = Text.Format(
                                Extension.LoadString("GetQueryListNavTable.Documentation.Description"),
                                {name}
                            ),
                            Code = Text.Format(
                                "= #""#{0}"".Contents(""None"", ""Query"", -240, false, false, askFieldsJson)",
                                {name}
                            ),
                            Result = Text.Format(
                                Extension.LoadString("GetQueryListNavTable.Documentation.Result"),
                                {name}
                            )
                        ]
                    }
                ]
            in
                Value.ReplaceType(curried, curriedDocs),

        // get the set of queries
        queries = GetQueryListTable(categoryId, typeId, format, myQueriesOnly, favoritesOnly, mergedQueriesOnly),

        // Transform the table to a list of navigation records
        navTableList = Table.TransformRows(queries, each [
            Key = [id],
            Name = [name],
            Data = 
                if [has_ask_fields] then 
                    curriedFunctionWithAskFields([id], [name])
                else
                    curriedFunction([id], [name]),
            ItemKind = "Function",
            ItemName = "Function",
            IsLeaf = true
        ]),

        // Convert to a list of lists, which is needed for the #table operator
        rows = List.Transform(navTableList, each {_[Name], _[Key], _[Data], _[ItemKind], _[ItemName], _[IsLeaf]}),

        // Convert the list of records into a proper table (which may be empty)
        navTable = #table(
            NavigationTableType,
            rows
        ),

        // Convert to navigation table
        result = Table.ToNavigationTable(navTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        result;

GetQueryCategoryNavTable = () as table =>
    let
        // get the set of query categories
        categories = GetQueryCategoryTable(),

        // modifying the existing table is more performant than Table.TransformRows() + Table.FromRecords(), and it's fewer lines - but just doesn't read as clean IMO
        // withData = Table.AddColumn(categories, "Data", each GetQueryListNavTable([id], null, null, false, false, false), type function),
        // withKind = Table.AddColumn(withData, "ItemKind", each "Folder", type text),
        // withName = Table.AddColumn(withKind, "ItemName", each "Folder", type text),
        // withLeaf = Table.AddColumn(withName, "IsLeaf", each false, type logical),
        // navTable = Table.RenameColumns(withLeaf, {{"id", "Key"}, {"name", "Name"}}),

        // Transform each row into a curried function record (as list of records)
        navTableList = Table.TransformRows(categories, each [
            Key = [id],
            Name = [name],
            Data = GetQueryListNavTable([id], null, null, false, false, false),
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ]),

        // Convert the list of records into a proper table
        navTable = Table.FromRecords(navTableList),

        // Convert to navigation table
        result = Table.ToNavigationTable(navTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        result;

GetQueryTypeNavTable = () as table =>
    let
        // get the set of query types
        types = GetQueryTypeTable(),

        // Transform each row into a curried function record (as list of records)
        navTableList = Table.TransformRows(types, each [
            Key = [id],
            Name = [name],
            Data = GetQueryListNavTable(null, [id], null, false, false, false),
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ]),

        // Convert the list of records into a proper table
        navTable = Table.FromRecords(navTableList),

        // Convert to navigation table
        result = Table.ToNavigationTable(navTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        result;

GetQueryFormatNavTable = () as table =>
    let 
        // get the list of query format
        formats = {"dynamic", "static"},

        // Transform each item into a curried function record (as list of records)
        navTableList = List.Transform(formats, each [
            Key = _,
            Name = Extension.LoadString(_),
            Data = GetQueryListNavTable(null, null, _, false, false, false),
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ]),

        // Convert the list of records into a proper table
        navTable = Table.FromRecords(navTableList),

        // Convert to navigation table
        result = Table.ToNavigationTable(navTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        result;

// --------------------------------------------------------------------------------
// Query SKY API functions
// --------------------------------------------------------------------------------

// https://developer.sky.blackbaud.com/api#api=query&operation=GetQueryCategories
GetQueryCategoryTable = () as table =>
    let
        response = Web.ContentsCustomRetry(
            BaseUrl,
            [
                RelativePath = "/query/categories",
                Query = [
                    product = Product,
                    module = Module
                ],
                Headers = DefaultRequestHeaders
            ]
        ),
        bodyJson = Json.Document(response),

        rawTable = Table.FromRecords(bodyJson[categories], null, MissingField.UseNull),
        result = Table.ChangeType(rawTable, QueryCategoryTableType)
    in
        result;

// https://developer.sky.blackbaud.com/api#api=query&operation=GetQueryTypes
GetQueryTypeTable = () as table =>
    let
        response = Web.ContentsCustomRetry(
            BaseUrl,
            [
                RelativePath = "/query/querytypes",
                Query = [
                    product = Product,
                    module = Module
                ],
                Headers = DefaultRequestHeaders
            ]
        ),
        bodyJson = Json.Document(response),

        rawTable = Table.FromRecords(bodyJson[query_types], null, MissingField.UseNull),
        result = Table.ChangeType(rawTable, QueryTypeTableType)
    in
        result;

// https://developer.sky.blackbaud.com/api#api=query&operation=GetQueryList
GetQueryListPageByOffset = (
    categoryId as nullable number,
    typeId as nullable number,
    format as nullable text,
    myQueriesOnly as logical,
    favoritesOnly as logical,
    mergedQueriesOnly as logical,
    offset as number
) as table =>
    let
        pageSize = 200,

        response = Web.ContentsCustomRetry(
            BaseUrl,
            [
                RelativePath = "/query/queries",
                Query = Record.RemoveNullFields([
                    product = Product,
                    module = Module,
                    category = TextOrNull(categoryId),
                    query_type_id = TextOrNull(typeId),
                    query_format = format,
                    my_queries_only = TrueOrNull(myQueriesOnly),
                    my_fav_queries_only = TrueOrNull(favoritesOnly),
                    merged_queries_only = TrueOrNull(mergedQueriesOnly),
                    limit = Text.From(pageSize),
                    offset = Text.From(offset)
                ]),
                Headers = DefaultRequestHeaders
            ]
        ),    
        bodyJson = Json.Document(response),
        queries = try bodyJson[queries] otherwise {},
        count = try bodyJson[count] otherwise 0,
        
        new_offset = 
            if (count > 0 and count >= offset) then
                offset + pageSize
            else 
                count,

        data = Table.FromRecords(queries, null, MissingField.UseNull)
    in
        data meta [Count = count, Offset = new_offset];

GetQueryListTable = (
    categoryId as nullable number,
    typeId as nullable number,
    format as nullable text,
    myQueriesOnly as logical,
    favoritesOnly as logical,
    mergedQueriesOnly as logical
) as table =>
    let
        // fetch all results
        allResults = Table.GenerateByPage((previous) => 
            let
                // if previous is null, then this is our first page of data
                offset = 
                    if (previous = null) then 
                        0
                    else 
                        Value.Metadata(previous)[Offset]?,

                count = 
                    if (previous = null) then 
                        1
                    else 
                        Value.Metadata(previous)[Count]?,

                // if Count <= Offset set by the previous call, we know we have no more data
                page = 
                    if (count > offset) then 
                        GetQueryListPageByOffset(
                            categoryId, 
                            typeId, 
                            format, 
                            myQueriesOnly, 
                            favoritesOnly, 
                            mergedQueriesOnly,
                            offset
                        ) 
                    else 
                        null
            in
                page
        ),

        // filter out queries that can't be executed
        result = Table.SelectRows(allResults, each 
            [can_execute] = true and 
            (([supported_execution_modes] = "ById") or ([supported_execution_modes] = "Both"))
        )
    in
        result;

// https://developer.sky.blackbaud.com/api#api=query&operation=GetJob
GetQueryStatus = (jobId as text, retry as number) as record =>
    let
        response = Web.ContentsCustomRetry(
            BaseUrl,
            [
                RelativePath = "/query/jobs/" & Text.Trim(jobId),
                Query = [
                    product = Product,
                    module = Module,
                    include_read_url = "OnceCompleted",
                    content_disposition = "Attachment",
                    _retry = Text.From(retry),
                    _ts = GetTimestamp()
                ],
                Headers = DefaultRequestHeaders
            ]
        ),
        bodyJson = Json.Document(response)
    in
        bodyJson;

// https://developer.sky.blackbaud.com/api#api=query&operation=StartQueryExecutionJobByID
StartQueryJob = (
    queryId as number,
    formattingMode as text,
    sqlGenerationMode as text,
    timeZoneOffsetInMinutes as number,
    useStaticQuery as logical,
    displayCodeTableLongDescription as logical,
    askFields as nullable text
) as record =>
    let
        response = Web.ContentsCustomRetry(
            BaseUrl,
            [
                RelativePath = "/query/queries/executebyid",
                Query = [
                    product = Product,
                    module = Module,
                    _ts = GetTimestamp()
                ],
                Headers = DefaultRequestHeaders,
                Content = Text.ToBinary(
                    Text.FromBinary(
                        Json.FromValue([
                            id = queryId,
                            ux_mode = "Synchronous",
                            output_format = "Json",
                            formatting_mode = formattingMode,
                            sql_generation_mode = sqlGenerationMode,
                            use_static_query_id_set = useStaticQuery,
                            display_code_table_long_description = displayCodeTableLongDescription,
                            time_zone_offset_in_minutes = timeZoneOffsetInMinutes,
                            ask_fields = if askFields = null then null else Json.Document(askFields)
                        ])
                    )
                )
            ]
        ),
        bodyJson = Json.Document(response)
    in
        bodyJson;

// https://developer.sky.blackbaud.com/api#api=query&operation=StartQueryExecutionJob
StartAdHocQueryJob = (
    query as text,
    formattingMode as text,
    sqlGenerationMode as text,
    timeZoneOffsetInMinutes as number,
    useStaticQuery as logical,
    displayCodeTableLongDescription as logical
) as record =>
    let
        response = Web.ContentsCustomRetry(
            BaseUrl,
            [
                RelativePath = "/query/queries/execute",
                Query = [
                    product = Product,
                    module = Module,
                    _ts = GetTimestamp()
                ],
                Headers = DefaultRequestHeaders,
                Content = Text.ToBinary(
                    Text.FromBinary(
                        Json.FromValue([
                            query = Json.Document(query),
                            ux_mode = "Synchronous",
                            output_format = "Json",
                            formatting_mode = formattingMode,
                            sql_generation_mode = sqlGenerationMode,
                            use_static_query_id_set = useStaticQuery,
                            display_code_table_long_description = displayCodeTableLongDescription,
                            time_zone_offset_in_minutes = timeZoneOffsetInMinutes
                        ])
                    )
                )
            ]
        ),
        bodyJson = Json.Document(response)
    in
        bodyJson;

GetQueryResultsTable = (
    queryIdOrDefinition as any,
    formattingMode as nullable text,
    sqlGenerationMode as nullable text,
    timeZoneOffsetInMinutes as nullable number,
    useStaticQuery as nullable logical,
    displayCodeTableLongDescription as nullable logical,
    askFields as nullable text
) as table =>
    let
        _formattingMode = if formattingMode = null then "None" else formattingMode,
        _sqlGenerationMode = if sqlGenerationMode = null then "Query" else sqlGenerationMode,
        _timeZoneOffsetInMinutes = if timeZoneOffsetInMinutes = null then GetTimeZoneOffetMinutes() else timeZoneOffsetInMinutes,
        _useStaticQuery = if useStaticQuery = null then false else useStaticQuery,
        _displayCodeTableLongDescription = if displayCodeTableLongDescription = null then false else displayCodeTableLongDescription,
        _askFields = askFields,

        // start a query execution job
        startJson = 
            if Type.Is(Value.Type(queryIdOrDefinition), Number.Type) then 
                StartQueryJob(queryIdOrDefinition, _formattingMode, _sqlGenerationMode, _timeZoneOffsetInMinutes, _useStaticQuery, _displayCodeTableLongDescription, _askFields)
            else
                StartAdHocQueryJob(queryIdOrDefinition, _formattingMode, _sqlGenerationMode, _timeZoneOffsetInMinutes, _useStaticQuery, _displayCodeTableLongDescription),

        jobId = startJson[id],

        // define a recursive function to poll for the job status
        pollJob = (retry as number, maxRetries as number, pollSeconds as number) =>
            let
                timestamp = DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss"),
                _ = if retry > maxRetries then error Extension.LoadString("maxRetriesExceeded") else null,

                statusJson = GetQueryStatus(jobId, retry),
                status = statusJson[status],
                _x = Diagnostics.Trace(TraceLevel.Information, timestamp & " - Polling attempt " & Text.From(retry) & ": Last status = " & status, null)
            in
                // if the job status is completed, then return the JSON response
                if status = "Completed" then
                    statusJson
                else if status = "Canceled" then 
                    error Extension.LoadString("queryJobCanceled")
                else if status = "Failed" then
                    error Extension.LoadString("queryJobFailed")
                else
                    // otherwise, poll again after delaying
                    Function.InvokeAfter(() =>
                        @pollJob(retry + 1, maxRetries, pollSeconds),
                        #duration(0, 0, 0, pollSeconds)
                    ),

        // poll the query job status
        jobResultJson = pollJob(0, POLL_MAX_RETRIES, POLL_DELAY_SECONDS),

        // fetch the query results from the SAS URI returned when the job completes
        sasUri = jobResultJson[sas_uri],
        resultJson = Json.Document(Web.Contents(sasUri)),
        result = Table.FromRecords(resultJson)
    in
        result;

// --------------------------------------------------------------------------------
// Misc functions
// --------------------------------------------------------------------------------

// Return "true" if the given value is true, otherwise null
TrueOrNull = (b as nullable logical) =>
    let
        result = if b = true then "true" else null
    in
        result;

// Convert the given value to text or return null
TextOrNull = (value as any) =>
    let
        result = if value = null then null else Text.From(value)
    in
        result;

// The intent of this is to include an ever-changing parameter in API requests to prevent Power Query caching from interfering 
// with polling (without this, the request looks to be "the same" as one already submitted so the cached response is used).
// This also ensures that a query is executed each time it is invoked instead of using a cached result.
GetTimestamp = () as text => 
    let
        utcNow = DateTimeZone.UtcNow(),
        epoch = #datetimezone(1970, 1, 1, 0, 0, 0, 0, 0),
        duration = utcNow - epoch,

        // Extract milliseconds from the fractional seconds
        secondsWithFraction = Duration.Seconds(duration),
        wholeSeconds = Number.RoundDown(secondsWithFraction),
        fractionalSeconds = secondsWithFraction - wholeSeconds,
        ms = Number.RoundDown(fractionalSeconds * 1000),

        totalMs =
            Duration.Days(duration) * 86400000 +
            Duration.Hours(duration) * 3600000 +
            Duration.Minutes(duration) * 60000 +
            wholeSeconds * 1000 +
            ms,
            // When debugging, it's easier to see the formatted date in Fiddler
            // result = Text.From(utcNow)
            result = Number.ToText(totalMs)
    in
        result;

// Get the current local timezone offset in minutes
GetTimeZoneOffetMinutes = () as number =>
    let
        // Get the current local time (this will have the local timezone information if run in Desktop)
        localTimeWithZone = DateTimeZone.LocalNow(),

        // Get the offset hours from the local time
        offsetHours = DateTimeZone.ZoneHours(localTimeWithZone),

        // Get the offset minutes from the local time
        offsetMinutes = DateTimeZone.ZoneMinutes(localTimeWithZone),

        // computed the (signed) offset in minutes
        result = (offsetHours * 60) + offsetMinutes
    in
        result;

// --------------------------------------------------------------------------------
// Table type definitions
// --------------------------------------------------------------------------------

// https://learn.microsoft.com/en-us/power-query/handling-navigation-tables
NavigationTableType = type table [
    Name = text,
    Key = any,
    Data = function,
    ItemKind = text,
    ItemName = text,
    IsLeaf = logical
];

// https://developer.sky.blackbaud.com/api#api=query&operation=GetQueryCategories
// todo: resolve if number is sufficient or if you have to qualify Int32
QueryCategoryTableType = type table [
    id = number,
    name = nullable text,
    sequence = nullable number
];

// https://developer.sky.blackbaud.com/api#api=query&operation=GetQueryTypes
QueryTypeTableType = type table [
    id = number,
    name = nullable text
];

/*
---------------------
Questions/Ideas 
---------------------
- It's not clear when/whether a typed response is needed from some SKY API calls (ex: GetQueryStatus, StartQueryJob, StartAdHocQueryJob)

- Get PKCE working:
    https://github.com/microsoft/DataConnectors/blob/master/samples/OAuthPKCE/PKCESample.pq
    https://community.fabric.microsoft.com/t5/Power-Query/OAuth2-Data-Connector-with-PKCE/td-p/959361

*/