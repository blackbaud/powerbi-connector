// ---------------------------------------------------------------
// This file contains the Blackbaud Power BI connector definition
// ---------------------------------------------------------------
//
section Blackbaud;

// Data source description
[DataSource.Kind="Blackbaud", Publish="Blackbaud.Publish"]
shared Blackbaud.Contents = () => GetNavigationTable();

// Data source Kind description
Blackbaud = [
    // TestConnection is required to enable the connector through the Gateway
    // TODO: this reuses the full Navigator build (env detection + branch construction),
    // unlike the lightweight ping used by the standalone BlackbaudRENXTQuery connector.
    // Revisit whether this is fine for gateway refresh reliability, or whether it should
    // be replaced with something cheaper.
    TestConnection = (dataSourcePath) => { "Blackbaud.Contents" },

    // Describe the API Authorization implementation
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
Blackbaud.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ConnectorName"), Extension.LoadString("ConnectorTooltip") },
    LearnMoreUrl = "https://docs.blackbaud.com/microsoft-connectors-docs/microsoft-power-platform",
    SourceImage = Blackbaud.Icons,
    SourceTypeImage = Blackbaud.Icons
];

Blackbaud.Icons = [
    Icon16 = { Extension.Contents("Blackbaud16.png"), Extension.Contents("Blackbaud20.png"), Extension.Contents("Blackbaud24.png"), Extension.Contents("Blackbaud32.png") },
    Icon32 = { Extension.Contents("Blackbaud32.png"), Extension.Contents("Blackbaud40.png"), Extension.Contents("Blackbaud48.png"), Extension.Contents("Blackbaud64.png") }
];

// ---------------------------------------------------------------
// SKY API Authorization implementation (OAuth2)
// ---------------------------------------------------------------
client_id = LoadFromResource("client_id.txt");
client_secret = LoadFromResource("client_secret.txt");
authorization_url = "https://oauth2.sky.blackbaud.com/authorization";
token_url = "https://oauth2.sky.blackbaud.com/token";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 615;
windowHeight = 535;

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
//
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
//
RefreshToken = (resourceUrl, refresh_token) => 
    GetToken("refresh_token", refresh_token);

// GetToken wraps up calling the OAuth /token endpoint to exchange an authorization code or refresh a token
// 
// grantType:   Indicates the grant type (authorization_code or refresh_token)
// code:        The authorization code or refresh token value to exchange
//
GetToken = (grantType, code) =>
    let
        body = [
            client_id = client_id,
            client_secret = client_secret,
            grant_type = grantType,
            redirect_uri = redirect_uri
        ],

        fieldName = if (grantType = "authorization_code") then 
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

        result = if (Record.HasFields(json, {"error", "error_description"})) then 
                    error Error.Record(json[error], json[error_description], json)
                 else
                    json
    in
        json;

// ---------------------------------------------------------------
// Load helper functions
// ---------------------------------------------------------------
// 
// Note that in the future, the M language will have better support for refactoring into separate files.  For now, leverage the approach described here:
// https://docs.microsoft.com/en-us/power-query/samples/trippin/7-advancedschema/readme#refactoring-common-code-into-separate-files
// 
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Load the helper functions described here, as well as other functions factored into separate files for easier maintenance
// https://docs.microsoft.com/en-us/power-query/helperfunctions
//
Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Table.GenerateByPage = Extension.LoadFunction("Table.GenerateByPage.pqm");
Table.SchemaTransformTable = Extension.LoadFunction("Table.SchemaTransformTable.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");

Uri.FromParts = Extension.LoadFunction("Uri.FromParts.pqm");
Uri.GetHost = Extension.LoadFunction("Uri.GetHost.pqm");
Uri.ValidateUrlScheme = Extension.LoadFunction("Uri.ValidateUrlScheme.pqm");

Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) => if state{1} <> null
                then {null, state{1}}
                else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);

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
    (i) => #duration(0, 0, 0, i*0.1));

// used for loading secrets from files in the project
LoadFromResource = (name as text) as text =>
    try
        Text.FromBinary(Extension.Contents(name))
    otherwise
        error Error.Unexpected("Resource '" & name & "' was not found.  Does the file exist in the project, and is the Build Action set to 'Compile'?");

// ---------------------------------------------------------------
// Pagination
// ---------------------------------------------------------------
// todo: would like to move these to .pqm files but can't get it to work due to some EoF error
GetPageByNextLink = (url as text, optional schema as type) as table =>
    let
        response = Web.ContentsCustomRetry(url, [Headers = DefaultRequestHeaders]),
        body = Json.Document(response),
        nextLink = GetNextLink(body),

        // If we have no schema, use Table.FromRecords() instead
        // (and hope that our results all have the same fields).
        // If we have a schema, expand the record using its field names
        data =
            //if (schema <> null) then // error in Microsoft tutorial?
            if (schema = null) then
                //Table.FromRecords(body[value])
                Table.FromList(body[value], Splitter.SplitByNothing(), {"value"})
            else
                let
                    // convert the list of records into a table (single column of records)
                    asTable = Table.FromList(body[value], Splitter.SplitByNothing(), {"Column1"}),
                    fields = Record.FieldNames(Type.RecordFields(Type.TableRow(schema))),
                    //expanded = Table.ExpandRecordColumn(asTable, fields)
                    expanded = Table.ExpandRecordColumn(asTable, "Column1",fields)
                in
                    expanded
    in
        data meta [NextLink = nextLink];

// Read all pages of data.
// After every page, we check the "NextLink" record on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
GetAllPagesByNextLink = (url as text, optional schema as type) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null) then GetPageByNextLink(nextLink, schema) else null
        in
            page
    );

GetPageByOffset = (url as text, optional schema as type, optional offset as number, optional limit as number) as table =>
    let
        response = if (offset > 0) then
            Web.ContentsCustomRetry(url & "&offset=" & Number.ToText(offset), [Headers = DefaultRequestHeaders])
        else
            Web.ContentsCustomRetry(url, [Headers = DefaultRequestHeaders]),
        body = Json.Document(response),
        recordCount = GetRecordCount(body),
        new_offset = if (recordCount > 0 and recordCount >= offset and limit > 0) then offset + limit else recordCount,
        responseRaw = GetResponseRecords(body),

        // If we have no schema, use Table.FromRecords() instead
        // (and hope that our results all have the same fields).
        // If we have a schema, expand the record using its field names
        data =
            if (schema = null) then
                Table.FromRecords(responseRaw)
            else
                let
                    responseList = if Value.Is(responseRaw, type list) then responseRaw else {responseRaw},
                    // convert the list of records into a table (single column of records)
                    asTable = Table.FromList(responseList, Splitter.SplitByNothing(), {"Column1"}),
                    fields = Record.FieldNames(Type.RecordFields(Type.TableRow(schema))),
                    expanded = Table.ExpandRecordColumn(asTable, "Column1", fields)
                in
                    expanded
    in
        data meta [RecordCount = Number.ToText(recordCount), Offset = Number.ToText(new_offset)];

// Read all pages of data.
// After every page, we check the "RecordCount" and "Offset" values on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
GetAllPagesByOffset = (url as text, optional schema as type, optional limit as number) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            offset = if (previous = null) then 
                0
            else 
                Number.FromText(Value.Metadata(previous)[Offset]?),
            recordCount = if (previous = null) then 
                1
            else 
                Number.FromText(Value.Metadata(previous)[RecordCount]?),
            // if RecordCount <= Offset set by the previous call, we know we have no more data
            page = if (recordCount > offset) then 
                GetPageByOffset(url, schema, offset, limit) 
            else 
                null
        in
            page
    );

// In this implementation, 'response' will be the parsed body of the response after the call to Json.Document.
// We look for the 'next_link' field and simply return null if it doesn't exist.
GetNextLink = (body) as nullable text => 
    Record.FieldOrDefault(body, "next_link");

GetRecordCount = (body) as nullable number => 
    if Value.Is(body, type record) then 
        Record.FieldOrDefault(body, "count", 0) 
    else 
        0;

GetResponseRecords = (body) as nullable any =>
    if Value.Is(body, type record) then
        // Most SKY API list endpoints wrap their records in a "value" field. A handful of
        // endpoints outside the RENXT product line use their own field name instead - e.g.
        // the Consent API's "constituent_consents". "value" is checked first and unconditionally,
        // so every existing endpoint's behavior is unchanged; the second field name is only
        // consulted when "value" is absent.
        Record.FieldOrDefault(body, "value", Record.FieldOrDefault(body, "constituent_consents", body))
    else
        body;

// ---------------------------------------------------------------
// Connector implementation
// ---------------------------------------------------------------

BaseUrl = "https://api.sky.blackbaud.com";

// todo: this isn't a universal value - it can vary on a per-endpoint basis
DefaultRecLimit = 5000; 

// requests to SKY API require a subscription key
DefaultRequestHeaders = [
    #"Bb-Api-Subscription-Key" = LoadFromResource("subscription_key.txt")
];

// Create a navigation table grouping for the each endpoint parent reference
GetNavigationTable = () as table =>
    let
        // start with an empty nav table
        emptyTable = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {}
        ),
        
        // if the environment has fundraising features
        nodes1 =
            if EnvironmentHasRENXT() then
                Table.InsertRows(emptyTable, 0, GetRENXTNavTableRows())
            else
                emptyTable,
        nodes2 =
            if EnvironmentHasFENXT() then
                Table.InsertRows(nodes1, 0, GetFENXTNavTableRows())
            else
                nodes1,
        NavTable = Table.ToNavigationTable(nodes2, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

GetRENXTNavTableRows = () as list =>
    let
        branches = {branchConstituent, branchGifts, branchFundraising, branchOpportunities, branchLists, branchEvents},
        branchRows = GetNavTableRows(branches),

        // add a "Raiser's Edge NXT Query" folder exposing the RENXT Query feature (folded in from
        // the BlackbaudRENXTQuery connector). Module is always "None" for RE - see
        // GetFENXTNavTableRows below for the FE counterpart, which requires a module.
        queryRow = [
            Name = Extension.LoadString("raisersEdgeNXTQueryFolder"),
            Key = "RaisersEdgeNXTQuery",
            Data = GetQueryNavTable("RE", "None"),
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ]
    in
        branchRows & {queryRow};

GetFENXTNavTableRows = () as list =>
    let
        branches = {branchGeneralLedger},
        branchRows = GetNavTableRows(branches),

        // add a "Financial Edge NXT Query" folder exposing the same Query feature as RE above, but
        // FE queries require an explicit module (there is no "None" module for FE) - so this is a
        // folder of modules, each containing its own full copy of the browse/query structure.
        queryRow = [
            Name = Extension.LoadString("financialEdgeNXTQueryFolder"),
            Key = "FinancialEdgeNXTQuery",
            Data = GetFEQueryModuleNavTable(),
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ]
    in
        branchRows & {queryRow};

GetNavTableRows = (branches as list) as list => 
    let
        rows = List.Transform(branches, each [Name=_, Key=_, Data=NXTNavTable(_), ItemKind="Folder", ItemName="Folder", IsLeaf=false])
    in
        rows;

// Evaluate whether the current environment has Raiser's Edge NXT
//
// Failing open matters here: these run while the Navigator is being built, and GetNavigationTable
// calls them from a plain `if`, so anything HasAccess throws propagates out of Blackbaud.Contents
// and takes the whole Get Data experience with it - not just one branch. TestConnection also
// builds the full Navigator, so a transient failure would break a gateway refresh's connection
// test. Hiding a branch the user does have is worse than showing one they don't: an unusable
// branch just 403s on click, which is how this behaved before the probes were live. The probe is
// a convenience, not a security control - SKY API authorizes every endpoint server-side anyway.
EnvironmentHasRENXT = () as logical =>
    let
        // this will use the Environment API in the future, for now probe a representative endpoint
        return = try HasAccess("constituent/v1/titles") otherwise true
    in
        return;

// Evaluate whether the current environment has Financial Edge NXT - fails open, see above
EnvironmentHasFENXT = () as logical =>
    let
        // this will use the Environment API in the future, for now probe a representative endpoint
        return = try HasAccess("generalledger/v1/transactioncodes") otherwise true
    in
        return;

// 429 is handled rather than thrown so a rate-limited probe reads as "reachable" instead of an
// error. Anything else outside this list still throws, which the callers above absorb.
//
// Note this can't just delegate to Web.ContentsCustomRetry to pick up its 429 backoff: that helper
// merges its own ManualStatusHandling = {429} last, which would overwrite the list below, and it
// returns the buffered binary rather than the response, so there'd be no metadata to read a status from.
HasAccess = (route as text) as logical =>
    let
        url = Uri.Combine(BaseUrl, route),
        result = Web.Contents(url, [Headers = DefaultRequestHeaders, ManualStatusHandling={401, 403, 429, 500}]),
        buffered = Binary.Buffer(result),
        status = if buffered = null then 0 else Value.Metadata(result)[Response.Status]
    in
        (status <> 401 and status <> 403 and status <> 500);

NXTNavTable = (branch as text) as table =>
    let
        // Group endpoints into their respective parent references according to the branch in the SchemaTable
        schemaRows = Table.SelectRows(SchemaTable, each [Branch] = branch) as table,
        entities = Table.SelectColumns(schemaRows, {"Entity", "Endpoint", "Type"}),
        rename = Table.RenameColumns(entities, {{"Entity", "Name"}}),

        // Add Data as a calculated column if a text endpoint has been passed in. Otherwise just use the function pointer
        withData = Table.AddColumn(rename, "Data", each if Value.Is([Endpoint], type text) then GetEntity(Uri.Combine(BaseUrl, [Endpoint]), [Name]) else [Endpoint], type table),

        // Add ItemKind and ItemName as fixed text values.
        // ItemName drives Preview.DelayColumn (see Table.ToNavigationTable.pqm): a text value
        // delays previewing of the row's Data, a null value does not. Table and Folder rows
        // keep text so their (expensive) API calls / nested nav tables stay lazy. Function
        // rows use null - a delayed function row renders as static text instead of the
        // invocation UI, leaving no way to supply arguments or run it.
        withItemKind = Table.AddColumn(withData, "ItemKind", each if Value.Is([Endpoint], type text) then "Table" else if [Type] <> null then "Function" else "Folder", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each if Value.Is([Endpoint], type text) then "Table" else if [Type] <> null then null else "Folder", type nullable text),

        // Indicate that the node should either be a leaf, as in not expandable, or a further expandable
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each (Value.Is([Endpoint], type text) or [Type] <> null), type logical),
        withKey = Table.AddColumn(withIsLeaf, "Key", each if (Value.Is([Endpoint], type text) or [Type] <> null) then [Name] else branch & "_" & Text.Replace([Name], " ", "")),

        // Generate the nav table
        navTable = Table.ToNavigationTable(withKey, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

CreateListsNavTable = (listType as text, public as logical, listHandler as function) as table => 
    let
        url = Uri.Combine(BaseUrl, "list/v1/lists?list_type=" & listType),
        data = Blackbaud.Feed(url, true, ListOfListsType, 0),
        appliedSchema = Table.ChangeType(data, ListOfListsType),
        filterRows = Table.SelectRows(appliedSchema, each [is_public] = public),
        renameCols = Table.RenameColumns(filterRows, {{"id", "Key"}}),
        withData = Table.AddColumn(renameCols, "Data", each listHandler([Key])),
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Table"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true),
        NavTable = Table.ToNavigationTable(withIsLeaf, {"Key"}, "name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

Blackbaud.Feed = (url as text, hasNextLink as logical, optional schema as type, optional limit as number) as table => 
    if hasNextLink then 
        GetAllPagesByNextLink(url, schema) 
    else 
        GetAllPagesByOffset(url, schema, limit);

GetEntity = (url as text, entity as text) as table => 
    let
        limit = GetLimitForEntity(entity),
        fullUrl = if (limit > 0) then
            url & (if (Text.Contains(url, "?")) then "&" else "?") & "limit=" & Number.ToText(limit)
        else
            url,
        schema = GetSchemaForEntity(entity),
        modifier = GetModifierForEntity(entity),
        hasNextLink = GetHasNextLinkForEntity(entity),
        data = Blackbaud.Feed(fullUrl, hasNextLink, schema, limit),
        appliedSchema = if (schema <> null) then Table.ChangeType(data, schema) else data,
        result = if (modifier <> null) then
            modifier(appliedSchema)
        else
            appliedSchema
    in
        result;

GetSchemaForEntity = (entity as text) as any => try SchemaTable{[Entity=entity]}[Type] otherwise error "Couldn't find entity: '" & entity &"'";
GetModifierForEntity = (entity as text) as any => try SchemaTable{[Entity=entity]}[Function] otherwise error "Couldn't find entity: '" & entity &"'";
GetLimitForEntity = (entity as text) as number => try SchemaTable{[Entity=entity]}[Limit] otherwise error "Couldn't find entity: '" & entity &"'";
GetHasNextLinkForEntity = (entity as text) as logical => try SchemaTable{[Entity=entity]}[HasNextLink] otherwise error "Couldn't find entity: '" & entity &"'";

branchConstituent = "Constituents";
branchLists = "Lists";
branchFundraising = "Fundraising";
branchGifts = "Gifts";
branchOpportunities = "Opportunities";
branchGeneralLedger = "General Ledger";
branchEvents = "Events";

// define the schema table
SchemaTable = #table(
    {"Entity", "Type", "Endpoint", "Branch", "Function", "Limit", "HasNextLink"}, 
    {
        // Constituent
        {"Constituent (all)", ConstituentListType, urlConstitList & "?include_inactive=true&include_deceased=true", branchConstituent, ConstituentLayout, DefaultRecLimit, true},
        {"Constituent (all, no expansions)", ConstituentListType, urlConstitList & "?include_inactive=true&include_deceased=true", branchConstituent, ConstituentNoExpansLayout, DefaultRecLimit, true},
        {"Constituent (filtered)", ConstituentListType, ConstituentFiltered.Contents, branchConstituent, ConstituentLayout, DefaultRecLimit, true},
        {"Constituent (by list)", ConstituentListType, ConstituentByList.Contents, branchConstituent, ConstituentLayout, DefaultRecLimit, true},
        {"Constituent action", ActionListType, "constituent/v1/actions", branchConstituent, ConstituentActionLayout, DefaultRecLimit, true},
        {"Constituent action fundraisers", ActionListType, "constituent/v1/actions", branchConstituent, ConstituentActionFundraisersLayout, DefaultRecLimit, true},
        {"Constituent addresses", AddressListType, "constituent/v1/addresses?include_inactive=true", branchConstituent, ConstituentAddressesLayout, DefaultRecLimit, true},
        {"Constituent codes", ConstituentCodeListType, "constituent/v1/constituents/constituentcodes?include_inactive=true", branchConstituent, ConstituentCodesLayout, DefaultRecLimit, true},
        {"Constituent custom fields", CustomFieldListType, "constituent/v1/constituents/customfields", branchConstituent, ConstituentCustomFieldsLayout, DefaultRecLimit, true},
        {"Constituent education", EducationListType, "constituent/v1/educations", branchConstituent, ConstituentEducationLayout, DefaultRecLimit, true},
        // {"Constituent education majors", EducationListType, "constituent/v1/educations", branchConstituent, ConstituentEducationMajorsLayout, DefaultRecLimit, true},
        // {"Constituent education minors", EducationListType, "constituent/v1/educations", branchConstituent, ConstituentEducationMinorsLayout, DefaultRecLimit, true},
        {"Constituent emails", EmailListType, "constituent/v1/emailaddresses?include_inactive=true", branchConstituent, ConstituentEmailsLayout, DefaultRecLimit, true},
        {"Constituent membership", MembershipListType, "constituent/v1/memberships", branchConstituent, ConstituentMembershipLayout, DefaultRecLimit, true},
        // {"Constituent membership members", MembershipListType, "constituent/v1/memberships", branchConstituent, ConstituentMembershipMembersLayout, DefaultRecLimit, true},
        {"Constituent notes", NotesListType, "constituent/v1/notes", branchConstituent, ConstituentNotesLayout, DefaultRecLimit, true},
        {"Constituent online presence", OnlinePresenceListType, "constituent/v1/onlinepresences?include_inactive=true", branchConstituent, ConstituentOnlinePresenceLayout, DefaultRecLimit, true},
        {"Constituent phones", PhoneListType, "constituent/v1/phones?include_inactive=true", branchConstituent, ConstituentPhonesLayout, DefaultRecLimit, true},
        {"Constituent relationships", RelationshipListType, "constituent/v1/relationships", branchConstituent, RelationshipsLayout, DefaultRecLimit, true},
        {"Constituent code types", null, "constituent/v1/constituentcodetypes", branchConstituent, null, DefaultRecLimit, true},
        {"Constituent custom field categories", CustomFieldCategoryType, "constituent/v1/constituents/customfields/categories/details ", branchConstituent, null, DefaultRecLimit, true},
        // Separate Consent API (api.sky.blackbaud.com/consent), not the Constituent API. Paginated
        // by offset/count like most endpoints (HasNextLink = false), but its records are wrapped in
        // a "constituent_consents" field instead of the usual "value" - see GetResponseRecords.
        {"Constituent consents", ConsentListType, "consent/constituents/consents", branchConstituent, null, DefaultRecLimit, false},
        {"Public Lists", null, CreateListsNavTable("Constituent", true, ConstituentByList), branchConstituent, null, null, null},
        {"My Private Lists", null, CreateListsNavTable("Constituent", false, ConstituentByList), branchConstituent, null, null, null},

        // Lists
        {"Constituent Lists", ListOfListsType, "list/v1/lists?list_type=Constituent", branchLists, ListsLayout, 0, true},

        // Fundraising
        {"Appeal", AppealListType, "fundraising/v1/appeals?include_inactive=true", branchFundraising, AppealLayout, DefaultRecLimit, true},
        {"Appeal packages", PackageListType, "fundraising/v1/packages?include_inactive=true", branchFundraising, AppealPackagesLayout, DefaultRecLimit, true},
        {"Campaign", CampaignListType, "fundraising/v1/campaigns?include_inactive=true", branchFundraising, CampaignLayout, DefaultRecLimit, true},
        {"Fund", FundListType, "fundraising/v1/funds?include_inactive=true", branchFundraising, FundLayout, DefaultRecLimit, true},

        // Gift
        {"Gift", GiftListType, "gift/v1/gifts", branchGifts, GiftLayout, DefaultRecLimit, true},
        // {"Gift acknowledgements", GiftListType, "gift/v1/gifts", branchGifts, GiftAcknowledgementsLayout, DefaultRecLimit, true},
        {"Gift custom fields", CustomFieldListType, "gift/v1/gifts/customfields", branchGifts, GiftCustomFieldsLayout, DefaultRecLimit, true},
        {"Gift fundraisers", GiftListType, "gift/v1/gifts", branchGifts, GiftFundraisersLayout, DefaultRecLimit, true},
        {"Gift payments", GiftListType, "gift/v1/gifts", branchGifts, GiftPaymentsLayout, DefaultRecLimit, true},
        {"Gift receipts", GiftListType, "gift/v1/gifts", branchGifts, GiftReceiptsLayout, DefaultRecLimit, true},
        {"Gift soft credits", GiftListType, "gift/v1/gifts", branchGifts, GiftSoftCreditsLayout, DefaultRecLimit, true},
        {"Gift splits", GiftListType, "gift/v1/gifts", branchGifts, GiftSplitsLayout, DefaultRecLimit, true},
        {"Gift batch", GiftBatchListType, "gift-batch/v1/giftbatches", branchGifts, GiftBatchLayout, DefaultRecLimit, true},
        {"Public Lists", null, CreateListsNavTable("Gift", true, GiftByList), branchGifts, null, null, null},
        {"My Private Lists", null, CreateListsNavTable("Gift", false, GiftByList), branchGifts, null, null, null},

        // Opportunity
        {"Opportunity", OpportunityListType, "opportunity/v1/opportunities?include_inactive=true", branchOpportunities, OpportunityLayout, DefaultRecLimit, true},
        {"Opportunity fundraisers", OpportunityListType, "opportunity/v1/opportunities?include_inactive=true", branchOpportunities, OpportunityFundraisersLayout, DefaultRecLimit, true},
        {"Opportunity linked gifts", OpportunityListType, "opportunity/v1/opportunities?include_inactive=true", branchOpportunities, OpportunityLinkedGiftsLayout, DefaultRecLimit, true},

        // Event
        {"Event", EventListType, "event/v1/eventlist?include_inactive=true", branchEvents, EventLayout, 500, true},
        {"Event participants (by event ID)", EventParticipantListType, EventParticipantsByEventId.Contents, branchEvents, null, DefaultRecLimit, false},

        // General Ledger
        {"Account", AccountSearchType, "generalledger/v1/accounts", branchGeneralLedger, AccountLayout, DefaultRecLimit, false},
        // {"Account custom fields", AccountSearchType, "generalledger/v1/accounts", branchGeneralLedger, AccountCustomFieldsLayout, DefaultRecLimit, false},
        // {"Account default transaction codes", AccountSearchType, "generalledger/v1/accounts", branchGeneralLedger, AccountDefaultTransactionCodesLayout, DefaultRecLimit, false},
        {"Project", ProjectSearchType, "generalledger/v1/projects", branchGeneralLedger, ProjectLayout, DefaultRecLimit, false},
        // {"Project contacts", ProjectSearchType, "generalledger/v1/projects", branchGeneralLedger, ProjectContactsLayout, DefaultRecLimit, false},
        // {"Project custom fields", ProjectSearchType, "generalledger/v1/projects", branchGeneralLedger, ProjectCustomFieldsLayout, DefaultRecLimit, false},
        {"Budget scenario list", BudgetScenarioListType, "generalledger/v1/budgets/scenarios ", branchGeneralLedger, BudgetScenarioListLayout, 0, false},
        {"Budget list", BudgetListType, "generalledger/v1/budgets ", branchGeneralLedger, BudgetListLayout, 0, false},
        {"Transaction code list", TransactionCodeListType, "generalledger/v1/transactioncodes", branchGeneralLedger, TransactionCodeListLayout, 0, false},
        // {"Transaction distribution (all)", TransactionDistributionListType, urlTranDistrib, branchGeneralLedger, TransactionDistributionLayout, DefaultRecLimit, false},    //Deprecated since either proj id and/or account num are required per Eddie 1/23
        {"Transaction distribution", TransactionDistributionListType, TransactionDistributionFiltered.Contents, branchGeneralLedger, TransactionDistributionLayout, DefaultRecLimit, false},
        {"Transaction distribution transaction code values", TransactionDistributionListType, TransactionDistributionCodesLayout.Contents, branchGeneralLedger, TransactionDistributionCodesLayout, DefaultRecLimit, false},
        // {"Transaction distribution transaction code values", TransactionDistributionListType, urlTranDistrib, branchGeneralLedger, TransactionDistributionCodesLayout, DefaultRecLimit, false}
        {"Budget", BudgetType, BudgetFiltered.Contents, branchGeneralLedger, null, DefaultRecLimit, true},
        {"Budget detail", BudgetDetailType, BudgetDetailFiltered.Contents, branchGeneralLedger, BudgetDetailLayout, DefaultRecLimit, false},
        {"Budget detail (multi select)", BudgetDetailType, BudgetDetailMultiFiltered.Contents, branchGeneralLedger, BudgetDetailLayout, DefaultRecLimit, false},
        {"Budget detail lines list", BudgetDetailLinesListType, BudgetDetailLinesListFiltered.Contents, branchGeneralLedger, BudgetDetailLinesListLayout, DefaultRecLimit, false},
        {"Budget detail lines list periods", BudgetDetailLinesListType, BudgetDetailLinesListPeriodsLayout.Contents, branchGeneralLedger, BudgetDetailLinesListPeriodsLayout, DefaultRecLimit, false}

        // Categories that require individual calls per parent id - uncomment below to display in data connector
        // // Constituent
        // {"Constituent action custom fields", ActionListType, "constituent/v1/actions", branchConstituent, ConstituentActionCustomFieldsLayout, DefaultRecLimit, true},
        // {"Constituent aliases", ConstituentListType, urlConstitList & "?include_inactive=true&include_deceased=true", branchConstituent, ConstituentAliasesLayout, DefaultRecLimit, true},
        // {"Constituent assigned fundraisers", ConstituentListType, urlConstitList & "?include_inactive=true&include_deceased=true", branchConstituent, AssignedFundraisersLayout, DefaultRecLimit, true},
        // {"Constituent communication preferences", ConstituentListType, urlConstitList & "?include_inactive=true&include_deceased=true", branchConstituent, CommunicationPrefsLayout, DefaultRecLimit, true},
        // {"Constituent first gift", ConstituentListType, urlConstitList & "?include_inactive=true&include_deceased=true", branchConstituent, FirstGiftLayout, DefaultRecLimit, true},
        // {"Constituent greatest gift", ConstituentListType, urlConstitList & "?include_inactive=true&include_deceased=true", branchConstituent, GreatestGiftLayout, DefaultRecLimit, true},
        // {"Constituent latest gift", ConstituentListType, urlConstitList & "?include_inactive=true&include_deceased=true", branchConstituent, LatestGiftLayout, DefaultRecLimit, true},
        // {"Constituent lifetime giving", ConstituentListType, urlConstitList & "?include_inactive=true&include_deceased=true", branchConstituent, LifetimeGivingLayout, DefaultRecLimit, true},
        // {"Constituent profile picture", ConstituentListType, urlConstitList & "?include_inactive=true&include_deceased=true", branchConstituent, ProfilePictureLayout, DefaultRecLimit, true},
        // {"Constituent prospect status", ConstituentListType, urlConstitList & "?include_inactive=true&include_deceased=true", branchConstituent, ProspectStatusLayout, DefaultRecLimit, true},
        // {"Constituent ratings", ConstituentListType, urlConstitList & "?include_inactive=true&include_deceased=true", branchConstituent, ConstituentRatingsLayout, DefaultRecLimit, true},
        // 
        // // Fundraising
        // {"Appeal custom fields", AppealListType, "fundraising/v1/appeals?include_inactive=true", branchFundraising, AppealCustomFieldsLayout, DefaultRecLimit, true},
        // {"Campaign custom fields", CampaignListType, "fundraising/v1/campaigns?include_inactive=true", branchFundraising, CampaignCustomFieldsLayout, DefaultRecLimit, true},
        // {"Fund custom fields", FundListType, "fundraising/v1/funds?include_inactive=true", branchFundraising, FundCustomFieldsLayout, DefaultRecLimit, true},
        // 
        // // Opportunity
        // {"Opportunity custom fields", OpportunityListType, "opportunity/v1/opportunities?include_inactive=true", branchOpportunities, OpportunityCustomFieldsLayout, DefaultRecLimit, true}
        // {"Public Lists", null, CreateListsNavTable("Opportunity", true, OpportunityByList), branchOpportunities, null, null, null},
        // {"My Private Lists", null, CreateListsNavTable("Opportunity", false, OpportunityyList), branchOpportunities, null, null, null},
        //
        // // General Ledger
        // {"Project notes", ProjectSearchType, "generalledger/v1/projects", branchGeneralLedger, ProjectNotesLayout, DefaultRecLimit, false}
    }
);
        
// ------ Begin Public Functions -----

// todo: is this used anywhere?
shared BB_GetImageData = (url as text) as text =>
    let
        data = Web.ContentsCustomRetry(url),
        result = "data:image/png;base64, " & Binary.ToText(data, BinaryEncoding.Base64)
    in
        result;

// todo: is this used anywhere?
shared BB_ExtractGiftAcknowledgements = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"gift_id", "acknowledgements"})),
        expandAcknowledgements = Table.ExpandTableColumn(removeCols, "acknowledgements",
            {
                "status",
                "date",
                "letter"
            },
            {
                "status",
                "date",
                "letter"
            }),
        transformDate = ConvertToDateCol(expandAcknowledgements, "date")
    in
        transformDate;

// todo: is this used anywhere?
shared BB_ExtractProjectContactMethods = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"contact_id", "address_contact_methods"})),
        expandContactMethods = Table.ExpandTableColumn(removeCols, "address_contact_methods",
            {
                "contact_method_id",
                "contact_type",
                "contact_info"
            },
            {
                "contact_method_id",
                "contact_type",
                "contact_info"
            }),
            finalFilter = Table.SelectRows(expandContactMethods, each [contact_method_id] <> null)
    in
        finalFilter;

// ------ End Public Functions -----


// ------ Begin Type Definitions -----

// 1. Common types

// Any Public Custom Field List Endpoint
CustomFieldListType = type table [
    parent_id = nullable text,
    id = nullable text,
    category = nullable text,
    #"type" = nullable text,
    // value's shape depends on type (a {y,m,d} record for FuzzyDate, a number for Number/Currency),
    // so it stays untyped here and is converted to text by CustomFieldValueToText in the layouts
    value = nullable any,
    date = nullable text,   //Should ideally be typed as datetime directly here
    comment = nullable text,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Consent API constituent consent (ConstituentConsentRead). No field is required and the API omits
// fields without a value, so this schema is what keeps the columns stable across records.
ConsentListType = type table [
    constituent_id = nullable text,
    id = nullable text,
    channel = nullable text,
    inactive = nullable logical,
    date = nullable datetimezone,
    response = nullable text,
    category = nullable text,
    category_id = nullable text,
    source = nullable text,
    privacy_notice = nullable text,
    consent_statement = nullable text,
    date_added = nullable datetimezone
];

// standard fuzzy date type
FuzzyDateType = type [
    y = nullable Int64.Type,
    m = nullable Int64.Type,
    d = nullable Int64.Type
];

SeasonalDateType = type [
    m = nullable Int64.Type,
    d = nullable Int64.Type
];

ValueType = type [
    value = nullable number
];

SimpleIdValuePairType = type [
    id = nullable text,
    description = nullable text
];

CustomFieldCategoryType = type table [
    name = nullable text,
    #"type" = nullable text
];

// 2. Constituent API

// 2.1. Public Endpoints (no context, i.e. return all records)

urlConstitApi = "constituent/v1";
urlConstitList = urlConstitApi & "/constituents";

ConstituentListType = type table [
    id = nullable text,
    lookup_id = nullable text,
    name = nullable text,
    #"type" = nullable text,
    first = nullable text,
    middle = nullable text,
    last = nullable text,
    preferred_name = nullable text,
    title = nullable text,
    title_2 = nullable text,    
    suffix = nullable text,
    suffix_2 = nullable text,
    former_name = nullable text,
    gender = nullable text,
    marital_status = nullable text,
    fundraiser_status = nullable text,
    age = nullable number,
    birthdate = nullable FuzzyDateType,
    deceased = nullable logical,
    deceased_date = nullable FuzzyDateType,
    spouse = nullable SpouseType,
    address = nullable AddressType,
    email = nullable EmailType,
    phone = nullable PhoneType,
    online_presence = nullable OnlinePresenceType,
    gives_anonymously = nullable logical,
    inactive = nullable logical,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

shared ConstituentFiltered.Contents = Value.ReplaceType(ConstituentFiltered, ConstituentFilteredDocs);
shared ConstituentByList.Contents = Value.ReplaceType(ConstituentByList, ConstituentByListDocs);

ConstituentFilteredDocs = type function (
    optional constituentCode as (type text meta [
        Documentation.FieldCaption = "Constituent Code",
        Documentation.FieldDescription = "A comma-separated list of constituent codes. Returns constituents if any of the specified constituent codes match any of their active constituent codes.",
        Documentation.SampleValues = {"abc, xyz"}
    ]),
    optional customFieldCategory as (type text meta [
        Documentation.FieldCaption = "Custom Field Category",
        Documentation.FieldDescription = "A comma-separated list of custom field categories. Returns constituents if any of the specified custom field categories match any of their active custom fields.",
        Documentation.SampleValues = {"abc, xyz"}
    ]),
    optional fundraiserStatus as (type text meta [
        Documentation.FieldCaption = "Fundraiser Status",
        Documentation.FieldDescription = "A comma-separated list of fundraiser statuses. Returns constituents if any of the specified fundraiser statuses match the constituent's fundraiser status.",
        Documentation.AllowedValues = {"Active", "Inactive", "None", "Active,Inactive", "Active,None", "Inactive,None"}
    ]),
    optional includeDeceased as (type logical meta [
        Documentation.FieldCaption = "Include Deceased",
        Documentation.FieldDescription = "Set this parameter to ""true"" to include deceased constituents."
    ]),
    optional includeInactive as (type logical meta [
        Documentation.FieldCaption = "Include Inactive",
        Documentation.FieldDescription = "Set this parameter to ""true"" to include inactive constituents."
    ]),
    optional postCode as (type text meta [
        Documentation.FieldCaption = "Postal Code",
        Documentation.FieldDescription = "A comma-separated list of postal codes. Returns constituents if any of the specified postal codes match the postal code for their preferred address.",
        Documentation.SampleValues = {"29492, 29401"}
    ]))
    as table meta [
        Documentation.Name = "Constituent (filtered)",
        Documentation.LongDescription = "Returns a list of constituents, filtered by the specified parameters",
        Documentation.Examples = {
        [
            Description = "No parameters specified",
            Code = "= #""Constituent (filtered)"".Contents()",
            Result = "Returns all active, non-deceased constituents"
        ],
        [
            Description = "Constituent Code parameter usage",
            Code = "= #""Constituent (filtered)"".Contents(""Board Member,Volunteer"")",
            Result = "Returns constituents whose active constituent codes include either ""Board Member"" or ""Volunteer"""
        ],
        [
            Description = "Custom Field Category parameter usage",
            Code = "= #""Constituent (filtered)"".Contents(null, ""Interests,Anniversary"")",
            Result = "Returns constituents whose active custom fields include either ""Interests"" or ""Anniversary"""
        ],
        [
            Description = "Fundraiser Status parameter usage",
            Code = "= #""Constituent (filtered)"".Contents(null, null, ""Active,None"")",
            Result = "Returns constituents whose fundraiser status matches Active or None"
        ],
        [
            Description = "Include Deceased parameter usage",
            Code = "= #""Constituent (filtered)"".Contents(null, null, null, true)",
            Result = "Indicates that deceased constituents should be returned"
        ],
        [
            Description = "Include Inactive parameter usage",
            Code = "= #""Constituent (filtered)"".Contents(null, null, null, null, true)",
            Result = "Indicates that inactive constituents should be returned"
        ],
        [
            Description = "Postal Code parameter usage",
            Code = "= #""Constituent (filtered)"".Contents(null, null, null, null, null, ""99577,14623"")",
            Result = "Returns constituents whose preferred address has a postal code that matches or starts with 99577 or 14623, such as 99577, 14623, or 99577-0727"
        ]}
    ];

ConstituentByListDocs = type function (
    listId as (type text meta [
        Documentation.FieldCaption = "List Id",
        Documentation.FieldDescription = "A list identifier used to filter the set of constituents to those included in the specified list.",
        Documentation.SampleValues = {"<enter a list id here>"}
    ]))
    as table meta [
        Documentation.Name = "Constituent (by list)",
        Documentation.LongDescription = "Returns a list of constituents, filtered by the specified list",
        Documentation.Examples = {
        [
            Description = "Use the id column value, from the Constituent Lists table, corresponding to the list you want to use",
            Code = "= #""Constituent (by list)"".Contents(""XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"")",
            Result = "Returns constituents limited to only those included in the specified list"
        ]}
    ];

ConstituentFiltered = (optional constituentCode as text, optional customFieldCategory as text, optional fundraiserStatus as text, optional includeDeceased as logical, optional includeInactive as logical, optional postCode as text) as table =>
    let
        limit = DefaultRecLimit,
        url = Uri.Combine(BaseUrl, urlConstitList & "?limit=" & Number.ToText(limit)),
        postCodeList = CleanUserInputList(postCode),
        urlPostCode = url & (if not List.IsEmpty(postCodeList) then "&postal_code=" & Text.Combine(postCodeList, ",") else ""),
        urlDeceased = urlPostCode & (if (includeDeceased <> null) then "&include_deceased=" & Logical.ToText(includeDeceased) else ""),
        urlInactive = urlDeceased & (if (includeInactive <> null) then "&include_inactive=" & Logical.ToText(includeInactive) else ""),
        urlFundraiser = urlInactive & (if (fundraiserStatus <> null) then "&fundraiser_status=" & fundraiserStatus else ""),
        urlConstitCode = urlFundraiser & AddMultipleQueryStringValues("constituent_code", constituentCode),
        urlCustomField = urlConstitCode & AddMultipleQueryStringValues("custom_field_category", customFieldCategory),
        data = Blackbaud.Feed(urlCustomField, true, ConstituentListType, limit),
        appliedSchema = Table.ChangeType(data, ConstituentListType),
        result = ConstituentLayout(appliedSchema)
    in
        result;

ConstituentByList = (listId as text) as table =>
    let
        limit = DefaultRecLimit,
        url = Uri.Combine(BaseUrl, urlConstitList & "?limit=" & Number.ToText(limit)),
        urlListId = url & "&list_id=" & listId,
        data = Blackbaud.Feed(urlListId, true, ConstituentListType, limit),
        appliedSchema = Table.ChangeType(data, ConstituentListType),
        result = ConstituentLayout(appliedSchema)
    in
        result;

// Relationship List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentRelationshipsAllConstituents
RelationshipListType = type table [
    constituent_id = nullable text,
    id = nullable text,
    relation_id = nullable text,
    name = nullable text,
    #"type" = nullable text,
    reciprocal_type = nullable text,
    start = nullable FuzzyDateType,
    end = nullable FuzzyDateType,
    is_spouse = nullable logical,
    is_organization_contact = nullable logical,
    is_primary_business = nullable logical,
    organization_contact_type = nullable text,
    position = nullable text,
    comment = nullable text,
    reciprocal_relationship_id = nullable text,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Constituent Custom Field List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentCustomFieldsAllConstituents
// CustomFieldListType

// Action List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListActionsAllConstituents
ActionListType = type table [
    constituent_id = nullable text,
    id = nullable text,
    opportunity_id = nullable text,
    category = nullable text,
    #"type" = nullable text,
    priority = nullable text,
    date = nullable text,   //Should ideally be typed as datetime directly here
    start_time = nullable time,
    end_time = nullable time,
    summary = nullable text,
    description = nullable text,
    direction = nullable text,
    location = nullable text,
    status = nullable text,
    status_code = nullable text,
    computed_status = nullable text,
    completed = nullable logical,
    completed_date = nullable text, //Should ideally be typed as datetime directly here
    outcome = nullable text,
    fundraisers = {nullable text},  //This data gets rolled out into its own table
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Phone List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentPhonesAllConstituents
PhoneListType = type table [
    constituent_id = nullable text,
    id = nullable text,
    #"type" = nullable text,
    number = nullable text,
    primary = nullable logical,
    do_not_call = nullable logical,
    inactive = nullable logical,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Email Address List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentEmailAddressesAllConstituents
EmailListType = type table [
    constituent_id = nullable text,
    id = nullable text,
    #"type" = nullable text,
    address = nullable text,
    primary = nullable logical,
    do_not_email = nullable logical,
    inactive = nullable logical,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Address List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentAddressesAllConstituents
AddressListType = type table [
    constituent_id = nullable text,
    id = nullable text,
    #"type" = nullable text,
    formatted_address = nullable text,
    preferred = nullable logical,
    do_not_mail = nullable logical,
    inactive = nullable logical,
    start = nullable text,  //Should ideally be typed as datetime directly here
    end = nullable text,    // "
    seasonal_start = nullable SeasonalDateType,
    seasonal_end = nullable SeasonalDateType,
    country = nullable text,
    address_lines = nullable text,
    city = nullable text,
    state = nullable text,
    suburb = nullable text,
    county = nullable text,
    postal_code = nullable text,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Education List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentEducationsAllConstituents
EducationListType = type table [
    constituent_id = nullable text,
    id = nullable text,
    school = nullable text,
    #"type" = nullable text,
    campus = nullable text,
    primary = nullable logical,
    known_name = nullable text,
    social_organization = nullable text,
    subject_of_study = nullable text,
    class_of_degree = nullable text,
    degree = nullable text,
    gpa = nullable number,
    class_of = nullable text,
    date_entered = nullable FuzzyDateType,
    date_graduated = nullable FuzzyDateType,
    date_left = nullable FuzzyDateType,
    status = nullable text,
    department = nullable text,
    faculty = nullable text,
    registration_number = nullable text,
    majors = {nullable text},   //This data gets rolled out into its own table
    minors = {nullable text},   // "
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Constituent Code List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentCodesAllConstituents
ConstituentCodeListType = type table [
    constituent_id = nullable text,
    id = nullable text,
    description = nullable text,
    start = nullable FuzzyDateType,
    end = nullable FuzzyDateType,
    inactive = nullable logical,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Online Presence List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentOnlinePresencesAllConstituents
OnlinePresenceListType = type table [
    constituent_id = nullable text,
    id = nullable text,
    #"type" = nullable text,
    address = nullable text,
    primary = nullable logical,
    inactive = nullable logical,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Note List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentNotesAllConstituents
NotesListType = type table [
    constituent_id = nullable text,
    id = nullable text,
    #"type" = nullable text,
    date = nullable FuzzyDateType,
    summary = nullable text,
    text = nullable text,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Membership List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListMemberships
MembershipListType = type table [
    constituent_id = nullable text,
    id = nullable text,
    dues = nullable ValueType,
    program = nullable text,
    category = nullable text,
    subcategory = nullable text,
    joined = nullable text,     //Should ideally be typed as datetime directly here
    expires = nullable text,    // "
    standing = nullable text,
    members = nullable MemberType,  //This data gets rolled out into its own table
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// 2.2. Public Endpoints (called in the context of the parent id)

//Prospect status - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/GetConstituentProspectStatus
ProspectStatusType = type [
//     constituent_id = nullable text,  Not needed, since this is available in the parent Constituent entity
    status = nullable text,
    start = nullable text,  //Should ideally be typed as datetime directly here
    comments = nullable text
    //days_elapsed = nullable text,
];

//Fundraiser Assignment List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentFundraiserAssignmentsSingleConstituent
AssignedFundraisersType = type table [
    constituent_id = nullable text,
    fundraiser_id = nullable text,
    #"type" = nullable text,
    start = nullable text,  //Should ideally be typed as datetime directly here
    end = nullable text,    // "
    amount = nullable ValueType,
    campaign_id = nullable text,
    fund_id = nullable text,
    appeal_id = nullable text,
    id = nullable text
];

//Alias List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentAliasesSingleConstituent
AliasType = type table [
    constituent_id = nullable text,
    id = nullable text,
    name = nullable text,
    #"type" = nullable text
];

//Communication Preference List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentCommunicationPreferencesSingleConstituent
CommunicationPrefsType = type table [
    constituent_id = nullable text,
    id = nullable text,
    solicit_code = nullable text,
    start = nullable text,  //Should ideally be typed as datetime directly here
    end = nullable text     // "
];

//First Gift - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/GetConstituentGiftFirst
//Greatest Gift - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/GetConstituentGiftGreatest
//Latest Gift - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/GetConstituentGiftLatest
GivingSummaryType = type [
    id = nullable text,
    #"type" = nullable text,
    date = nullable text,   //Should ideally be typed as datetime directly here
    amount = nullable ValueType,
    funds = {nullable SimpleIdValuePairType},
    campaigns = {nullable SimpleIdValuePairType},
    appeals = {nullable SimpleIdValuePairType}
];

//Lifetime Giving - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/GetConstituentGivingSummaryLifetime
LifetimeGivingType = type [
    consecutive_years_given = nullable Int64.Type,
    constituent_id = nullable text,
    total_committed_matching_gifts = nullable ValueType,
    total_giving = nullable ValueType,
    total_pledge_balance = nullable ValueType,
    total_received_giving = nullable ValueType,
    total_received_matching_gifts = nullable ValueType,
    total_soft_credits = nullable ValueType,
    total_years_given = nullable Int64.Type
];

//Rating List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListConstituentRatingsSingleConstituent
RatingsType = type table [
    id = nullable text,
    category = nullable text,
    comment = nullable text,
    constituent_id = nullable text,
    date = nullable text,   //Should ideally be typed as datetime directly here
    inactive = nullable logical,
    source = nullable text,
    #"type" = nullable text,
    value = nullable text
];

//Action Custom Field List - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListActionCustomFieldsSingleAction
//CustomFieldListType

//Profile Picture - https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/GetConstituentProfilePicture
ProfilePictureType = type [
//     constituent_id = nullable text,  Not needed, since this is available in the parent Constituent entity
    thumbnail_url = nullable text,
    url = nullable text
];

// 2.3. Sub data types

SpouseType = type [
    id = nullable text,
    first = nullable text,
    last = nullable text
];

AddressType = type [
    id = nullable text,
//     constituent_id = nullable text,  Not needed, since this is available in the parent Constituent entity
    #"type" = nullable text,
    formatted_address = nullable text,
    preferred = nullable logical,
    do_not_mail = nullable logical,
    inactive = nullable logical,
    start = nullable text,  //Should ideally be typed as datetime directly here
    end = nullable text,    // "
    seasonal_start = nullable SeasonalDateType,
    seasonal_end = nullable SeasonalDateType,
    country = nullable text,
    address_lines = nullable text,
    city = nullable text,
    state = nullable text,
    suburb = nullable text,
    county = nullable text,
    postal_code = nullable text,    
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

EmailType = type [
    id = nullable text,
//    constituent_id = nullable text,   Not needed, since this is available in the parent Constituent entity
    #"type" = nullable text,
    address = nullable text,
    primary = nullable logical,
    do_not_email = nullable logical,
    inactive = nullable logical,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
]; 

PhoneType = type [
    id = nullable text,
//    constituent_id = nullable text,   Not needed, since this is available in the parent Constituent entity
    #"type" = nullable text,
    number = nullable text,
    primary = nullable logical,
    do_not_call = nullable logical,
    inactive = nullable logical,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

OnlinePresenceType = type [
    id = nullable text,
//    constituent_id = nullable text,   Not needed, since this is available in the parent Constituent entity
    #"type" = nullable text,
    address = nullable text,
    primary = nullable logical,
    inactive = nullable logical,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

MemberType = type table [
    id = nullable text,
    constituent_id = nullable text,
    primary = nullable logical
];

// 3. Gift API
urlGiftList = "gift/v1/gifts";

// 3.1. Public Endpoints (no context, i.e. return all records)

// Gift List - https://developer.sky.blackbaud.com/docs/services/58bdd5edd7dcde06046081d6/operations/ListGifts
GiftListType = type table [
    id = nullable text,
    constituent_id = nullable text,
    #"type" = nullable text,
    subtype = nullable text,
    date = nullable text,   //Should ideally be typed as datetime directly here
    amount = nullable ValueType,
    reference = nullable text,
    lookup_id = nullable text,
    constituency = nullable text,
    is_anonymous = nullable logical,
    post_status = nullable text,
    post_date = nullable text,  //Should ideally be typed as datetime directly here
    gift_status = nullable text,
    origin = nullable text,
    balance = nullable ValueType,
    batch_number = nullable text,
    recurring_gift_schedule = nullable RecurringGiftScheduleType,
    recurring_gift_status_date = nullable FuzzyDateType,
    gift_aid_amount = nullable ValueType,
    gift_aid_qualification_status = nullable text,
    acknowledgements = nullable AcknowledgementType,    //This data gets rolled out into its own table
    fundraisers = nullable GiftFundRaiserType,          // "
    gift_splits = nullable GiftSplitType,               // "
    payments = nullable PaymentType,                    // "
    receipts = nullable ReceiptType,                    // "
    soft_credits = nullable SoftCreditType,             // "
    linked_gifts = {nullable text},                     // "
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Gift Custom Field List - https://developer.sky.blackbaud.com/docs/services/58bdd5edd7dcde06046081d6/operations/ListGiftCustomFieldsAllGifts
// CustomFieldListType

// 3.2. Sub data types

RecurringGiftScheduleType = type [
    frequency = nullable text,
    start_date = nullable text, //Should ideally be typed as datetime directly here
    end_date = nullable text    // "
];

AcknowledgementType = type table [
    status = nullable text,
    date = nullable text,   //Should ideally be typed as datetime directly here
    letter = nullable text
];

GiftFundRaiserType = type table [
    constituent_id = nullable text,
    amount = nullable ValueType
];

GiftSplitType = type table [
    id = nullable text,
    amount = nullable ValueType,
    appeal_id = nullable text,
    campaign_id = nullable text,
    fund_id = nullable text,
    gift_aid_amount = nullable ValueType,
    gift_aid_qualification_status = nullable text,
    package_id = nullable text  
];

PaymentType = type table [
    payment_method = nullable text,
    reference = nullable text,
    reference_date = nullable FuzzyDateType,
    check_number = nullable text,
    check_date = nullable FuzzyDateType,
    account_token = nullable text,
    checkout_transaction_id = nullable text,
    bbps_configuration_id = nullable text,
    bbps_transaction_id = nullable text
];

ReceiptType = type table [
    status = nullable text,
    date = nullable text,   //Should ideally be typed as datetime directly here
    amount = nullable ValueType,
    number = nullable Int64.Type
];

SoftCreditType = type table [
    constituent_id = nullable text,
    gift_id = nullable text,
    amount = nullable ValueType,
    id = nullable text
];

GiftByList = (listId as text) as table =>
    let
        limit = DefaultRecLimit,
        url = Uri.Combine(BaseUrl, urlGiftList & "?limit=" & Number.ToText(limit)),
        urlListId = url & "&list_id=" & listId,
        data = Blackbaud.Feed(urlListId, true, GiftListType, limit),
        appliedSchema = Table.ChangeType(data, GiftListType),
        result = GiftLayout(appliedSchema)
    in
        result;

// 4. Gift Batch API 
GiftBatchListType = type table [
    id = nullable text,
    actual_amount = nullable number,
    batch_description = nullable text,
    batch_number = nullable text,
    added_by = nullable text,
    date_added = nullable text,   //Should ideally be typed as datetime directly here
    has_exceptions = nullable logical,
    approved = nullable logical,
    number_of_gifts = nullable Int64.Type
];

// 5. Opportunity API

// 5.1. Public Endpoints (no context, i.e. return all records)

// Opportunity List - https://developer.sky.blackbaud.com/docs/services/58e3b2597c1af25c58b9c4e3/operations/ListOpportunities
OpportunityListType = type table [
    id = nullable text,
    constituent_id = nullable text,
    purpose = nullable text,
    name = nullable text,
    status = nullable text,
    deadline = nullable text,   //Should ideally be typed as datetime directly here
    inactive = nullable logical,
    ask_date = nullable text,   //Should ideally be typed as datetime directly here
    ask_amount = nullable ValueType,
    expected_date = nullable text,  //Should ideally be typed as datetime directly here
    expected_amount = nullable ValueType,
    funded_date = nullable text,    //Should ideally be typed as datetime directly here
    funded_amount = nullable ValueType,
    campaign_id = nullable text,
    fund_id = nullable text,
    fundraisers = nullable OpportunityFundRaiserType,   //This data gets rolled out into its own table
    linked_gifts = {nullable text},                     // "
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone,
    opportunity_likelihood_name = nullable text,
    opportunity_likelihood_id = nullable text
];

// 5.2. Public Endpoints (called in the context of the parent id)

//Opportunity Custom Field List - https://developer.sky.blackbaud.com/docs/services/58e3b2597c1af25c58b9c4e3/operations/ListOpportunityCustomFieldsSingleOpportunity
//CustomFieldListType

// 5.3. Sub data types

OpportunityFundRaiserType = type table [
    constituent_id = nullable text,
    credit_amount = nullable ValueType
];

// 6. Fundraising API

// 6.1. Public Endpoints (no context, i.e. return all records)

// Campaign List - https://developer.sky.blackbaud.com/docs/services/58bdd6c8d7dcde06046081d7/operations/ListCampaigns
CampaignListType = type table [
    id = nullable text,
    lookup_id = nullable text,
    description = nullable text,
    start_date = nullable text, //Should ideally be typed as datetime directly here
    end_date = nullable text,   // "
    category = nullable text,
    goal = nullable ValueType,
    inactive = nullable logical,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Fund List - https://developer.sky.blackbaud.com/docs/services/58bdd6c8d7dcde06046081d7/operations/ListFunds
FundListType = type table [
    id = nullable text,
    lookup_id = nullable text,
    description = nullable text,
    start_date = nullable text, //Should ideally be typed as datetime directly here
    end_date = nullable text,   // "
    category = nullable text,
    type = nullable text,
    goal = nullable ValueType,
    inactive = nullable logical,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Appeal List - https://developer.sky.blackbaud.com/docs/services/58bdd6c8d7dcde06046081d7/operations/ListAppeals
AppealListType = type table [
    id = nullable text,
    lookup_id = nullable text,
    description = nullable text,
    start_date = nullable text, //Should ideally be typed as datetime directly here
    end_date = nullable text,   // "
    category = nullable text,
    goal = nullable ValueType,
    inactive = nullable logical,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// Package List - https://developer.sky.blackbaud.com/docs/services/58bdd6c8d7dcde06046081d7/operations/ListPackages
PackageListType = type table [
    appeal_id = nullable text,
    id = nullable text,
    lookup_id = nullable text,
    description = nullable text,
    start = nullable text,  //Should ideally be typed as datetime directly here
    end = nullable text,    // "
    goal = nullable ValueType,
    default_gift_amount = nullable ValueType,
    category = nullable text,
    notes = nullable text,
    recipient_count = Int64.Type,
    inactive = nullable logical,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// 6.2. Public Endpoints (called in the context of the parent id)

//Campaign Custom Field List - https://developer.sky.blackbaud.com/docs/services/58bdd6c8d7dcde06046081d7/operations/ListCampaignCustomFieldsSingleCampaign
//CustomFieldListType

//Fund Custom Field List - https://developer.sky.blackbaud.com/docs/services/58bdd6c8d7dcde06046081d7/operations/ListFundCustomFieldsSingleFund
//CustomFieldListType

//Appeal Custom Field List - https://developer.sky.blackbaud.com/docs/services/58bdd6c8d7dcde06046081d7/operations/ListAppealCustomFieldsSingleAppeal
//CustomFieldListType

// 7. General Ledger API

// 7.1. Public Endpoints (no context, i.e. return all records)

    // 7.1.1. Transaction distribution (List) - https://developer.sky.blackbaud.com/docs/services/56eb17a0a9db9516c46bff6f/operations/ListTransactionDistributions
    urlTranDistrib = "generalledger/v1/transactiondistributions";

    TransactionDistributionListType = type table [
        transaction_id = nullable Int32.Type,
        transaction_amount = nullable number,
        distribution_id = nullable Int32.Type,
        batch_id = nullable Int32.Type,
        distribution_amount = nullable number,
        account_number = nullable text,
        account_class = nullable text,
        ui_project_id = nullable text,
        post_date = nullable text,  //Should ideally be typed as datetime directly here
        type_code = nullable text,
        reference = nullable text,
        journal = nullable text,
        encumbrance = nullable text,
        transaction_code_values = nullable TransactionCodeValueType,    //This data gets rolled out into its own table
        date_added = nullable datetime,
        added_by = nullable text,
        date_modified = nullable datetime,
        modified_by = nullable text,
        post_status = nullable text
    ];

    shared TransactionDistributionFiltered.Contents = Value.ReplaceType(TransactionDistributionFiltered, TransactionDistributionFilteredDocs);

    TransactionDistributionFilteredDocs = type function (
        optional projectId as (type text meta [
            Documentation.FieldCaption = "Project Id",
            Documentation.FieldDescription = "A comma-separated list of project user-visible identifiers.",
            Documentation.SampleValues = {"abc, xyz"}
        ]),
        optional accountNumber as (type text meta [
            Documentation.FieldCaption = "Account Number",
            Documentation.FieldDescription = "A comma-separated list of account numbers.",
            Documentation.SampleValues = {"abc, xyz"}
        ]),
        optional fromDate as (type date meta [
            Documentation.FieldCaption = "From Post Date",
            Documentation.FieldDescription = "The minimum post date to include records."
        ]),
        optional toDate as (type date meta [
            Documentation.FieldCaption = "To Post Date",
            Documentation.FieldDescription = "The maximum post date to include records."
        ])        )
        as table meta [
            Documentation.Name = "Transaction distribution",
            Documentation.LongDescription = "Returns a list of transactions, filtered by the specified parameters",
            Documentation.Examples = {
            [
                Description = "Project Id parameter usage",
                Code = "= #""Transaction distribution"".Contents(""1001,2001"")",
                Result = "Returns transactions for project user-visible identifiers ""1001"" or ""2001"""
            ],
            [
                Description = "Account Number parameter usage",
                Code = "= #""Transaction distribution"".Contents(null, ""01-1000-00,01-3000-01"")",
                Result = "Returns transactions for account numbers ""01-1000-00"" or ""01-3000-01"""
            ],
            [
                Description = "From Post Date parameter usage",
                Code = "= #""Transaction distribution"".Contents(""1001"", null, #date(2002, 1, 27))",
                Result = "Returns transactions posted on or after 1/27/2002 for the project user-visible identifier ""1001"""
            ],
            [
                Description = "To Post Date parameter usage",
                Code = "= #""Transaction distribution"".Contents(""1001"", null, null, #date(2010, 8, 31))",
                Result = "Returns transactions posted on or before 8/31/2010 for the project user-visible identifier ""1001"""
            ]}
        ];

    TransactionDistributionFiltered = (optional projectId as text, optional accountNumber as text, optional fromDate as date, optional toDate as date) as table =>
        let
            projectIdList = CleanUserInputList(projectId),
            accountNumberList = CleanUserInputList(accountNumber),
            result = 
                if not List.IsEmpty(projectIdList) or not List.IsEmpty(accountNumberList) then
                    let
                        limit = DefaultRecLimit,
                        url = Uri.Combine(BaseUrl, urlTranDistrib & "?limit=" & Number.ToText(limit)),
                        urlFromDate = url & (if (fromDate <> null) then "&from_date=" & Date.ToText(fromDate, "MM/dd/yyyy") else ""),
                        urlToDate = urlFromDate & (if (toDate <> null) then "&to_date=" & Date.ToText(toDate, "MM/dd/yyyy") else ""),
                        urlProjectId = urlToDate & (if List.Count(projectIdList) = 1 then "&ui_project_id=" & projectIdList{0} else ""),
                        urlAccountNumber = urlProjectId & (if List.Count(accountNumberList) = 1 then "&account_number=" & accountNumberList{0} else ""),
                        dataList =
                            if List.Count(projectIdList) > 1 then
                                if List.Count(accountNumberList) > 1 then
                                    let
                                        idList = List.Transform(projectIdList, each [P=_,A=accountNumberList]),
                                        idTable = Table.FromList(idList, Record.FieldValues, {"Proj","Acct"}),
                                        qsTable = Table.AddColumn(Table.ExpandListColumn(idTable, "Acct"), "QueryString", each "&ui_project_id=" & [Proj] & "&account_number=" & [Acct]),
                                        qsList = Table.ToList(Table.RemoveColumns(qsTable, {"Proj","Acct"})),
                                        resultList = List.Transform(qsList, each Blackbaud.Feed(urlAccountNumber & _, false, TransactionDistributionListType, limit))
                                    in
                                        resultList
                                else
                                    List.Transform(projectIdList, each Blackbaud.Feed(urlAccountNumber & "&ui_project_id=" & _, false, TransactionDistributionListType, limit))
                            else if List.Count(accountNumberList) > 1 then
                                List.Transform(accountNumberList, each Blackbaud.Feed(urlAccountNumber & "&account_number=" & _, false, TransactionDistributionListType, limit))
                            else
                                {Blackbaud.Feed(urlAccountNumber, false, TransactionDistributionListType, limit)},
                        appliedSchema = Table.ChangeType(Table.Combine(dataList), TransactionDistributionListType)
                    in
                        TransactionDistributionLayout(appliedSchema)
                else
                    error Error.Record("Either Project Id or Account Number is required")
        in
            result;

    // 7.1.2. Budget - https://developer.sky.blackbaud.com/docs/services/56eb17a0a9db9516c46bff6f/operations/GetBudget
    urlBudget = "generalledger/v1/budgets/#{0}";

    BudgetType = type table [
        category = nullable text,
        fiscal_year = nullable text,
        total_amount = nullable number,
        fiscal_period = nullable Int32.Type,
        period_amount = nullable number
    ];

    shared BudgetFiltered.Contents = Value.ReplaceType(BudgetFiltered, BudgetFilteredDocs);

    BudgetFilteredDocs = type function (
        scenarioId as (type number meta [
            Documentation.FieldCaption = "Budget Scenario Id (Test)",
            Documentation.FieldDescription = "A budget scenario identifier."
        ]))
        as table meta [
            Documentation.Name = "Budget",
            Documentation.LongDescription = "Returns details for every fiscal period for the specified budget scenario",
            Documentation.Examples = {
            [
                Description = "Use the budget_scenario_id column value, from the Budget List table, corresponding to the budget scenario you want to use",
                Code = "= #""Budget"".Contents(18)",
                Result = "Returns fiscal period details for the budget scenario identifier 18"
            ]}
        ];

    BudgetFiltered = (scenarioId as number) as table =>
        let
            url = Uri.Combine(BaseUrl, Text.Format(urlBudget, {Number.ToText(scenarioId)})),
            // Passing in true for the hasNextLink parameter below because a count value is returned in the response BUT the endpoint does not support limit/offset
            data = Blackbaud.Feed(url, true, BudgetType),
            appliedSchema = Table.ChangeType(data, BudgetType),
            addId = Table.AddColumn(appliedSchema, "budget_scenario_id", each scenarioId, Int32.Type)
        in
            addId;

    // 7.1.3. Budget detail - https://developer.sky.blackbaud.com/docs/services/56eb17a0a9db9516c46bff6f/operations/GetBudgetDetail
    urlBudgetDetail = urlBudget & "/details";

    BudgetDetailType = type table [
        scenario_id = nullable text,
        description = nullable text,
        budget_type = nullable text,
        status = nullable text,
        start_fiscal_year = nullable text,
        end_fiscal_year = nullable text,
        start_fiscal_period = nullable Int32.Type,
        end_fiscal_period = nullable Int32.Type,
        locked = nullable logical,
        total_revenue = nullable number,
        total_expense = nullable number,
        added_by = nullable text,
        date_added = nullable datetime,
        modified_by = nullable text,
        date_modified = nullable datetime
    ];

    shared BudgetDetailFiltered.Contents = Value.ReplaceType(BudgetDetailFiltered, BudgetDetailFilteredDocs);
    shared BudgetDetailMultiFiltered.Contents = Value.ReplaceType(BudgetDetailMultiFiltered, BudgetDetailMultiFilteredDocs);

    BudgetDetailFilteredDocs = type function (
        scenarioId as (type number meta [
            Documentation.FieldCaption = "Budget Scenario Id",
            Documentation.FieldDescription = "A budget scenario identifier."
        ]),
        optional catch404 as (type logical meta [
            Documentation.FieldCaption = "Catch 404 Errors"
        ]))
        as table meta [
            Documentation.Name = "Budget detail",
            Documentation.LongDescription = "Returns details for the specified budget scenario",
            Documentation.Examples = {
            [
                Description = "Use the budget_scenario_id column value, from the Budget List table, corresponding to the budget scenario you want to use",
                Code = "= #""Budget detail"".Contents(18)",
                Result = "Returns details for the budget scenario identifier 18"
            ]}
        ];

    BudgetDetailMultiFilteredDocs = type function (
        scenarioId as (type text meta [
            Documentation.FieldCaption = "Budget Scenario Id",
            Documentation.FieldDescription = "A comma-separated list of budget scenario identifiers.",
            Documentation.SampleValues = {"123, 789"}
        ]),
        optional catch404 as (type logical meta [
            Documentation.FieldCaption = "Catch 404 Errors"
        ]))
        as table meta [
            Documentation.Name = "Budget detail",
            Documentation.LongDescription = "Returns details for the specified budget scenarios",
            Documentation.Examples = {
            [
                Description = "Use the budget_scenario_id column value, from the Budget List table, corresponding to the budget scenarios you want to use",
                Code = "= #""Budget detail (multi select)"".Contents(18,23)",
                Result = "Returns details for the budget scenario identifiers 18 and 23"
            ]}
        ];

BudgetDetailFiltered = (scenarioId as number, optional catch404 as logical) as table =>
    let
        data = BudgetDetailFilteredWithIdCol(scenarioId, catch404),
        result = BudgetDetailLayout(data)
    in
        result;

BudgetDetailFilteredWithIdCol = (scenarioId as number, optional catch404 as logical) as table =>
        let
            url = Uri.Combine(BaseUrl, Text.Format(urlBudgetDetail, {Number.ToText(scenarioId)})),
            data = try Blackbaud.Feed(url, false, BudgetDetailType),
            errorCheck =
                if data[HasError] then
                    if catch404 <> null and catch404 and Text.Contains(data[Error][Message], "(404)") then
                        Table.RemoveRows(Table.FromValue("0"), 0)
                    else
                        error Error.Record(data[Error][Reason], data[Error][Message], data[Error][Detail])
                else
                    data[Value],
            result =
                if Value.Is(errorCheck, type table) then
                    let
                        appliedSchema = Table.ChangeType(errorCheck, BudgetDetailType),
                        addId = Table.AddColumn(appliedSchema, "budget_scenario_id", each scenarioId, Int32.Type)
                    in
                        addId
                else
                    errorCheck
        in
            result;

    BudgetDetailMultiFiltered = (scenarioId as text, optional catch404 as logical) as table =>
        let
            paramList = CleanUserInputList(scenarioId),
            dataList = List.Transform(paramList, each BudgetDetailFilteredWithIdCol(Number.FromText(_), catch404)),
            data = Table.Combine(dataList),
            appliedSchema = if Table.IsEmpty(data) then Table.ChangeType(data, BudgetDetailType) else data,
            result = BudgetDetailLayout(appliedSchema)
        in
            result;

    // 7.1.4. Budget detail lines (List) - https://developer.sky.blackbaud.com/docs/services/56eb17a0a9db9516c46bff6f/operations/ListBudgetLines
    urlBudgetDetailLinesList = urlBudgetDetail & "/lines";

    BudgetDetailLinesListType = type table [
        account_number = nullable text,
        account_description = nullable text,
        budget_line_id = nullable Int32.Type,
        ui_project_id = nullable text,
        project_description = nullable text,
        grant_description = nullable text,
        total = nullable number,
        periods = nullable PeriodType,
        notes = nullable text
    ];

    shared BudgetDetailLinesListFiltered.Contents = Value.ReplaceType(BudgetDetailLinesListFiltered, BudgetDetailLinesListFilteredDocs);

    BudgetDetailLinesListFilteredDocs = type function (
        scenarioId as (type number meta [
            Documentation.FieldCaption = "Budget Scenario Id",
            Documentation.FieldDescription = "A budget scenario identifier."
        ]))
        as table meta [
            Documentation.Name = "Budget detail lines list",
            Documentation.LongDescription = "Returns budget lines for the specified budget scenario",
            Documentation.Examples = {
            [
                Description = "Use the budget_scenario_id column value, from the Budget List table, corresponding to the budget scenario you want to use",
                Code = "= #""Budget detail lines list"".Contents(18)",
                Result = "Returns budget lines for the budget scenario identifier 18"
            ]}
        ];

    BudgetDetailLinesListFiltered = (scenarioId as number) as table =>
        let
            limit = DefaultRecLimit,
            url = Uri.Combine(BaseUrl, Text.Format(urlBudgetDetailLinesList, {Number.ToText(scenarioId)}) & "?limit=" & Number.ToText(limit)),
            data = Blackbaud.Feed(url, false, BudgetDetailLinesListType, limit),
            appliedSchema = Table.ChangeType(data, BudgetDetailLinesListType),
            addBudgetScenarioId = Table.AddColumn(appliedSchema, "budget_scenario_id", each scenarioId, Int32.Type),
            result = BudgetDetailLinesListLayout(addBudgetScenarioId)
        in
            result;

// Account (Search) - https://developer.sky.blackbaud.com/docs/services/56eb17a0a9db9516c46bff6f/operations/SearchAccounts
AccountSearchType = type table [
    account_id = nullable Int32.Type,
    account_number = nullable text,
    description = nullable text,
    prevent_data_entry = nullable logical,
    prevent_posting_date = nullable text,   //Should ideally be typed as datetime directly here
    class = nullable text,
    cashflow = nullable text,
    working_capital = nullable text,
    custom_fields = nullable CustomFieldsType,                      //This data gets rolled out into its own table
    default_transaction_codes = nullable TransactionCodeValueType , // "
    date_added = nullable datetime,
    added_by = nullable text,
    date_modified = nullable datetime,
    modified_by = nullable text
];

// Project (Search) - https://developer.sky.blackbaud.com/docs/services/56eb17a0a9db9516c46bff6f/operations/SearchProjects
ProjectSearchType = type table [
    project_id = nullable Int32.Type,
    description = nullable text,
    ui_project_id = nullable text,
    start_date = nullable text, //Should ideally be typed as datetime directly here
    end_date = nullable text,   //Should ideally be typed as datetime directly here
    location = nullable text,
    division = nullable text,
    department = nullable text,
    #"type" = nullable text,
    status = nullable text,
    prevent_data_entry = nullable logical,
    prevent_posting_after = nullable logical,
    posting_date = nullable text,
    account_restrictions = nullable AccountRestrictionsType,
    contacts = nullable ProjectContactsType,            //This data gets rolled out into its own table
    custom_fields = nullable CustomFieldsType,          // "
    date_added = nullable datetime,
    date_modified = nullable datetime,
    added_by = nullable text,
    modified_by = nullable text
];

// Transaction code (List) - https://developer.sky.blackbaud.com/docs/services/56eb17a0a9db9516c46bff6f/operations/ListTransactionCodes
TransactionCodeListType = type table [
    transaction_code_id = nullable Int32.Type,
    name = nullable text,
    description = nullable text,
    used_for_grants = nullable logical
];

// Budget scenario (List) - https://developer.sky.blackbaud.com/docs/services/56eb17a0a9db9516c46bff6f/operations/ListBudgetScenarios
BudgetScenarioListType = type table [
    id = nullable Int32.Type,
    value = nullable text,
    description = nullable text,
    inactive = nullable logical
];

// Budget (List) - https://developer.sky.blackbaud.com/docs/services/56eb17a0a9db9516c46bff6f/operations/ListBudgets
BudgetListType = type table [
    budget_scenario_id = nullable Int32.Type,
    description = nullable text,
    start_fiscal_year = nullable text,
    end_fiscal_year = nullable text,
    start_date = nullable text, //Should ideally be typed as datetime directly here
    end_date = nullable text,   //Should ideally be typed as datetime directly here
    status = nullable text,
    budget_type = nullable text,
    locked = nullable text,
    scenario_id = nullable text
];

// 7.2. Public Endpoints (called in the context of the parent id)

// Project notes - https://developer.sky.blackbaud.com/docs/services/56eb17a0a9db9516c46bff6f/operations/GetProjectNotes
ProjectNotesType = type table [
    note_action_id = nullable Int32.Type,
    note_type = nullable text,
    date = nullable text,           //Should ideally be typed as datetime directly here
    content = nullable text,
    description = nullable text,
    #"type" = nullable text,
    is_complete = nullable logical,
    assign_to = nullable text,
    completed_date = nullable text  //Should ideally be typed as datetime directly here
];

// 7.3. Sub data types

AccountRestrictionsType = type [
    allow_or_restrict = nullable text,
    criteria = nullable text
];

ProjectContactsType = type table [
    contact_id = nullable Int32.Type,
    description = nullable text,
    country = nullable text,
    city = nullable text,
    county = nullable text,
    state = nullable text,
    address_line = nullable text,
    postal = nullable text,
    title = nullable text,
    first_name = nullable text,
    middle_name = nullable text,
    last_name = nullable text,
    suffix = nullable text,
    position = nullable text,
    address_contact_methods = nullable ProjectContactMethodsType
];

ProjectContactMethodsType = type table [
    contact_method_id = nullable Int32.Type,
    contact_type = nullable text,
    contact_info = nullable text
];

CustomFieldsType = type table [
    custom_field_id = nullable Int32.Type,
    field_name = nullable text,
    value = nullable text,
    comments = nullable text,
    #"type" = nullable Int32.Type,
    date = nullable text        //Should ideally be typed as datetime directly here
];

TransactionCodeValueType = type table [
    name = nullable text,
    value = nullable text,
    id = nullable Int32.Type,
    inactive = nullable logical
];

PeriodType = type table [
    amount = nullable number,
    sequence = nullable Int32.Type,
    year_id = nullable text
];

// 8. List API

// 8.1. Public Endpoints (no context, i.e. return all records)

// Get a list of lists - https://developer.sky.blackbaud.com/docs/services/list/operations/GetLists
ListOfListsType = type table [
    id = nullable text,
    name = nullable text,
    description = nullable text,
    record_count = nullable Int32.Type,
    date_modified = nullable datetimezone,
    last_modified_by_user_name = nullable text,
    last_modified_by_user_id = nullable text,
    is_public = nullable logical
];

// 9. Event API

// 9.1. Public Endpoints (no context, i.e. return all records)

// Event List - https://developer.sky.blackbaud.com/docs/services/event/operations/GetEventList
EventListType = type table [
    id = nullable text,
    lookup_id = nullable text,
    name = nullable text,
    start_date = nullable text, //Should ideally be typed as datetime directly here
    start_time = nullable text,
    end_date = nullable text,   //Should ideally be typed as datetime directly here
    end_time = nullable text,
    attending_count = nullable Int32.Type,   
    invited_count = nullable Int32.Type,
    revenue = nullable number,
    goal = nullable number,
    percent_of_goal = nullable Int32.Type,  
    capacity = nullable Int32.Type,
    inactive = nullable logical,
    attended_count = nullable Int32.Type,
    category = nullable EventCategoryType,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone
];

// 9.3. Sub data types
EventCategoryType = type [
    category_id = nullable text,
    category_name = nullable text,
    category_inactive = nullable logical
];

ParticipationLevelType = type [
    id = nullable text,
    name = nullable text,
    is_inactive = nullable logical
];

// Event Participant List - https://developer.sky.blackbaud.com/docs/services/event/operations/GetEventParticipantList
//
// Typed explicitly (rather than schema = null) so every page - across every event - gets the same
// column set, with nulls filled in for fields absent from a given response. Without this, Power
// Query's "Invoke Custom Function" + Expand pattern breaks: the Expand step is generated from one
// preview row's columns, and any other row missing a column (e.g. a participant with no email)
// throws "The field 'x' of the record wasn't found." Genuinely complex/nested fields (host, guests,
// memberships, participant_options, registration_form, fees) are left as `any` rather than fully
// modelled - they still come through and can be expanded by the user, just without type coercion.
EventParticipantListType = type table [
    id = nullable text,
    contact_id = nullable text,
    date_added = nullable datetimezone,
    date_modified = nullable datetimezone,
    is_constituent = nullable logical,
    lookup_id = nullable text,
    name = nullable text,
    first_name = nullable text,
    middle_name = nullable text,
    last_name = nullable text,
    preferred_name = nullable text,
    former_name = nullable text,
    title = nullable text,
    suffix = nullable text,
    class_of = nullable text,
    phone = nullable text,
    do_not_call = nullable logical,
    email = nullable text,
    do_not_email = nullable logical,
    participation_level = nullable ParticipationLevelType,
    attended = nullable logical,
    rsvp_status = nullable text,
    invitation_status = nullable text,
    rsvp_date = nullable FuzzyDateType,
    total_paid = nullable number,
    host = nullable any,
    guests = nullable any,
    seat = nullable text,
    seating_notes = nullable text,
    seating_group = nullable text,
    name_tag = nullable text,
    summary_note = nullable text,
    memberships = nullable any,
    participant_options = nullable any,
    registration_form = nullable any,
    donations = nullable number,
    revenue = nullable number,
    online_data_health = nullable text,
    total_fees = nullable number,
    fees = nullable any
];

// 9.4. Bulk extraction helpers
//
// Event participants are the only parameterised (parent-scoped) RENXT endpoint judged worth a
// bulk-extraction shortcut: every other parameterised endpoint is constituent-scoped, and looping
// it over an entire constituent population would be an excessive number of API calls.
//
// A connector-side "all events" fan-out function was also tried here, but Power Query's own
// "Invoke Custom Function" + Expand pattern against this function (driven from the Event table's
// id column) proved noticeably more responsive in the query editor - it plays well with Power
// Query's step-by-step preview, where the connector-side fan-out does not. The all-in-one version
// was removed in favour of this building-block one.
shared EventParticipantsByEventId.Contents = Value.ReplaceType(EventParticipantsByEventId, EventParticipantsByEventIdDocs);

EventParticipantsByEventIdDocs = type function (
    eventId as (type text meta [
        Documentation.FieldCaption = "Event Id",
        Documentation.FieldDescription = "The id of the event whose participants should be returned. Use the id column value from the Event table.",
        Documentation.SampleValues = {"<enter an event id here>"}
    ]))
    as table meta [
        Documentation.Name = "Event participants (by event ID)",
        Documentation.LongDescription = "Returns the participants of a single event, identified by its event ID. Intended to be invoked once per event via Power Query's Invoke Custom Function against the Event table's id column, then expanded.",
        Documentation.Examples = {
        [
            Description = "Use the id column value, from the Event table, corresponding to the event you want participants for",
            Code = "= #""Event participants (by event ID)"".Contents(""XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"")",
            Result = "Returns participants limited to only those included in the specified event"
        ]}
    ];

EventParticipantsByEventId = (eventId as text) as table =>
    let
        // The limit on the URL and the limit handed to the paginator must be the SAME value.
        // GetPageByOffset advances the offset by whatever limit it is given, so if the API were
        // left to apply its own default page size (500) instead, the offset would step past rows
        // and silently skip them. Binding it once here keeps the two in step. The limit also has
        // to be present on the URL at all because this calls GetAllPagesByOffset directly rather
        // than via GetEntity (which is what normally appends it), and because GetPageByOffset's
        // "&offset=" needs an existing query string to append to.
        pageSize = DefaultRecLimit,
        participantsUrl = Uri.Combine(BaseUrl, "event/v1/events/" & eventId & "/participants?limit=" & Number.ToText(pageSize)),
        participants = GetAllPagesByOffset(participantsUrl, EventParticipantListType, pageSize),
        appliedSchema = Table.ChangeType(participants, EventParticipantListType)
    in
        appliedSchema;

// ------ End Type Definitions -----


// ------ Begin Layout Functions -----

//1. Common Functions

LoadTableForSingleRec = (recId as text, route as text, optional tableType as type) as table =>
    let
        fullUrl = Uri.Combine(BaseUrl, Text.Format(route, {recId})),
        result = Blackbaud.Feed(fullUrl, tableType),
        appliedSchema = Table.ChangeType(result, tableType)
    in
        appliedSchema;

LoadRecordForSingleRec = (recId as text, route as text, optional nullRec as record) as record  =>
    let
        fullUrl = Uri.Combine(BaseUrl, Text.Format(route, {recId})),
        body =
            if (nullRec = null) then
                Json.Document(Web.ContentsCustomRetry(fullUrl, [Headers = DefaultRequestHeaders]))
            else
                try Json.Document(Web.ContentsCustomRetry(fullUrl, [Headers = DefaultRequestHeaders])) otherwise nullRec
    in
        body;

ExpandFuzzyDateType = (sourceTable as table, sourceCol as text) as table =>
    let
        expandDate = Table.ExpandRecordColumn(sourceTable, sourceCol,
            {"y", "m", "d"},
            {sourceCol & ".year", sourceCol & ".month", sourceCol & ".day"})
    in
        expandDate;

ExpandSeasonalDateType = (sourceTable as table, sourceCol as text) as table =>
    let
        expandSeasDate = Table.ExpandRecordColumn(sourceTable, sourceCol,
            {"m", "d"},
            {sourceCol & ".month", sourceCol & ".day"})
    in
        expandSeasDate;

ExpandValueType = (sourceTable as table, sourceCol as text) as table =>
    let
        expandValue = Table.ExpandRecordColumn(sourceTable, sourceCol, {"value"}, {sourceCol})
    in
        expandValue;

// ISO 8601-style text for a fuzzy date, using whichever parts are present: 2022-05-13, 2022-05,
// 2022, or --02-09 / --02 / ---09 when there is no year (ISO's notation for an omitted year/month).
// Missing parts may be absent or 0. A day without a month can't be expressed with a year, so
// {y, d} falls back to the year alone.
FuzzyDateToText = (fuzzyDate as record) as nullable text =>
    let
        part = (name as text) => let v = Record.FieldOrDefault(fuzzyDate, name, null) in if v = null or v = 0 then null else v,
        y = part("y"),
        m = part("m"),
        d = part("d"),
        pad = (n as number) => Text.PadStart(Number.ToText(n, "D"), 2, "0"),
        year = if y = null then null else Text.PadStart(Number.ToText(y, "D"), 4, "0")
    in
        if y <> null then
            year & (if m = null then "" else "-" & pad(m) & (if d = null then "" else "-" & pad(d)))
        else if m <> null then
            "--" & pad(m) & (if d = null then "" else "-" & pad(d))
        else if d <> null then
            "---" & pad(d)
        else
            null;

// Custom field values arrive as text, numbers, logicals, or (for FuzzyDate) a {y,m,d} record.
// Numbers are formatted with en-US so the result doesn't depend on the machine's culture.
CustomFieldValueToText = (value as any) as nullable text =>
    if value = null then null
    else if value is record then FuzzyDateToText(value)
    else Text.From(value, "en-US");

TransformCustomFieldValue = (sourceTable as table) as table =>
    Table.TransformColumns(sourceTable, {{"value", CustomFieldValueToText, type nullable text}});

ConvertToDateCol = (sourceTable as table, sourceCol as text) as table =>
    let
        transformDateToDateTime = Table.TransformColumnTypes(sourceTable,{{sourceCol, type datetime}}),
        transformDateTimesToDate = Table.TransformColumns(transformDateToDateTime,{{sourceCol, DateTime.Date, type date}})
    in
        transformDateTimesToDate;

GivingSummaryLayout = (sourceTable as table, route as text) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id"})),
        addGivingSummaryCol = Table.AddColumn(removeCols, "gs col tmp", each LoadRecordForSingleRec([id], "constituent/v1/constituents/#{0}/givingsummary/" & route), GivingSummaryType),
        removeErrors = Table.RemoveRowsWithErrors(addGivingSummaryCol, {"gs col tmp"}),
        expandGivingSummary = Table.ExpandRecordColumn(removeErrors, "gs col tmp", 
            {
                "id"
            }, 
            {
                "gift_id"
            }),
        renameId = Table.RenameColumns(expandGivingSummary, {{"id", "constituent_id"}})
    in
        renameId;

GenericCustomFieldsLayout = (sourceTable as table, route as text, idColPrefix as text) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id"})),
        addCustomFieldsCol = Table.AddColumn(removeCols, "cf col tmp", each LoadTableForSingleRec([id], route, CustomFieldListType), CustomFieldListType),
        renameParentId = Table.RenameColumns(addCustomFieldsCol, {{"id", idColPrefix & "_id"}}),
        expandCustomFields = Table.ExpandTableColumn(renameParentId, "cf col tmp",
            {
                "id",
                "category",
                "type",
                "value",
                "date",
                "comment"
//                 "date_added",
//                 "date_modified"
            },
            {
                "id",
                "category",
                "type",
                "value",
                "date",
                "comment"
//                 "date_added",
//                 "date_modified"
            }),
        transformValue = TransformCustomFieldValue(expandCustomFields),
        transformDate = ConvertToDateCol(transformValue, "date"),
        finalFilter = Table.SelectRows(transformDate, each [id] <> null),
        renameId = Table.RenameColumns(finalFilter, {{"id", idColPrefix & "_custom_field_id"}})
    in
        renameId;

GLCustomFieldsLayout = (sourceTable as table, sourceCol as text) as table =>
    let
        expandCustomFields = Table.ExpandTableColumn(sourceTable, sourceCol,
            {
                "custom_field_id",
                "field_name",
                "value",
                "comments",
                "type",
                "date"
            },
            {
                "custom_field_id",
                "field_name",
                "value",
                "comments",
                "type",
                "date"
            }),
        transformDate = ConvertToDateCol(expandCustomFields, "date"),
        finalFilter = Table.SelectRows(transformDate, each [custom_field_id] <> null)
    in
        finalFilter;

TransactionCodesLayout = (sourceTable as table, sourceCol as text) as table =>
    let
        expandTransactionCodes = Table.ExpandTableColumn(sourceTable, sourceCol,
            {
                "name",
                "value",
                "id",
                "inactive"
            },
            {
                "name",
                "value",
                "transaction_code_id",
                "inactive"
            }),
        finalFilter = Table.SelectRows(expandTransactionCodes, each [transaction_code_id] <> null)
    in
        finalFilter;

AddPrimaryKeyToTable = (sourceTable as table, keyCol as text) as table =>
    let
        result = Table.AddKey(sourceTable, {keyCol}, true)
    in
        result;

RemoveUserStatsColumns = (sourceTable as table) as table =>
    let
        //result = Table.RemoveColumns(sourceTable, {"date_added", "added_by", "date_modified", "modified_by"}, MissingField.Ignore)
        result = Table.RemoveColumns(sourceTable, {"added_by", "modified_by"}, MissingField.Ignore) //Keep two date fields in order to be consistent with RE?
    in
        result;

//2. Table-Specific Functions (in-table record expansion)

ConstituentLayout = (sourceTable as table) as table =>
    let
        expandBirthDate = ExpandFuzzyDateType(sourceTable, "birthdate"),
        expandDeceasedDate = ExpandFuzzyDateType(expandBirthDate, "deceased_date"),
        expandSpouse = Table.ExpandRecordColumn(expandDeceasedDate, "spouse",
            {
                "id",
                "first",
                "last"
            },
            {
                "spouse.constituent_id",
                "spouse.first",
                "spouse.last"
            }),
        expandAddress = Table.ExpandRecordColumn(expandSpouse, "address", 
            {
                "id", 
                "type", 
                "formatted_address", 
                "preferred", 
                "do_not_mail", 
                "inactive", 
                "start", 
                "end", 
                "seasonal_start", 
                "seasonal_end", 
                "country", 
                "address_lines", 
                "city", 
                "state", 
                "suburb", 
                "county", 
                "postal_code"
//                 "date_added", 
//                 "date_modified"
            }, 
            {
                "address.address_id", 
                "address.type", 
                "address.formatted_address", 
                "address.preferred", 
                "address.do_not_mail", 
                "address.inactive", 
                "address.start", 
                "address.end", 
                "address.seasonal_start", 
                "address.seasonal_end", 
                "address.country", 
                "address.address_lines", 
                "address.city", 
                "address.state", 
                "address.suburb", 
                "address.county", 
                "address.postal_code"
//                 "address.date_added", 
//                 "address.date_modified"
            }),
        expandAddressSeasStart = ExpandSeasonalDateType(expandAddress, "address.seasonal_start"),
        expandAddressSeasEnd = ExpandSeasonalDateType(expandAddressSeasStart, "address.seasonal_end"),
        transformAddressStartDate = ConvertToDateCol(expandAddressSeasEnd, "address.start"),
        transformAddressEndDate = ConvertToDateCol(transformAddressStartDate, "address.end"),
        expandEmail = Table.ExpandRecordColumn(transformAddressEndDate, "email", 
            {
                "id",
                "type", 
                "address", 
                "primary", 
                "do_not_email", 
                "inactive"
//                 "date_added", 
//                 "date_modified"
            }, 
            {
                "email.email_id",
                "email.type", 
                "email.address", 
                "email.primary", 
                "email.do_not_email", 
                "email.inactive"
//                 "email.date_added", 
//                 "email.date_modified"
            }),
        expandPhone = Table.ExpandRecordColumn(expandEmail, "phone", 
            {
                "id",
                "type", 
                "number", 
                "primary", 
                "do_not_call", 
                "inactive"
//                 "date_added", 
//                 "date_modified"
            }, 
            {
                "phone.phone_id",
                "phone.type", 
                "phone.number", 
                "phone.primary", 
                "phone.do_not_call", 
                "phone.inactive"
//                 "phone.date_added", 
//                 "phone.date_modified"
            }),
        expandOnlinePresence = Table.ExpandRecordColumn(expandPhone, "online_presence", 
            {
                "id", 
                "type", 
                "address", 
                "primary", 
                "inactive"
//                 "date_added", 
//                 "date_modified"
            }, 
            {
                "online_presence.online_presence_id", 
                "online_presence.type", 
                "online_presence.address", 
                "online_presence.primary", 
                "online_presence.inactive"
//                 "online_presence.date_added", 
//                 "online_presence.date_modified"
            }),
            renameLookup = Table.RenameColumns(expandOnlinePresence, {{"lookup_id", "constituent_lookup_id"}}),
            renameId = Table.RenameColumns(renameLookup, {{"id", "constituent_id"}})
    in
        renameId;

ConstituentNoExpansLayout= (sourceTable as table) as table =>
    let
        renameLookup = Table.RenameColumns(sourceTable, {{"lookup_id", "constituent_lookup_id"}}),
        renameId = Table.RenameColumns(renameLookup, {{"id", "constituent_id"}})
    in
        renameId;

ProspectStatusLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id"})),
        //tempFilter = Table.SelectRows(removeCols, each ([id] = "3930" or [id] = "5630" or [id] = "4364" or [id] = "1009" or [id] = "3727" or [id] = "2502" or [id] = "3540")),
        //nullRec = Record.FromTable(#table({"constituent_id"},{})),
        //addProspectStatusCol = Table.AddColumn(tempFilter, "ps col tmp", each LoadRecordForSingleRec([id], "constituent/v1/constituents/#{0}/prospectstatus", nullRec), ProspectStatusType),
        addProspectStatusCol = Table.AddColumn(removeCols, "ps col tmp", each LoadRecordForSingleRec([id], "constituent/v1/constituents/#{0}/prospectstatus"), ProspectStatusType),
        removeErrors = Table.RemoveRowsWithErrors(addProspectStatusCol, {"ps col tmp"}),
        expandProspectStatus = Table.ExpandRecordColumn(removeErrors, "ps col tmp", 
            {
                "status", 
                "start", 
                "comments"
            }, 
            {
                "status", 
                "start", 
                "comments"
            }),
        transformStartDate = ConvertToDateCol(expandProspectStatus, "start"),
        renameId = Table.RenameColumns(transformStartDate, {{"id", "constituent_id"}})
    in
        renameId;

AssignedFundraisersLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id"})),
        //tempFilter = Table.SelectRows(removeCols, each ([id] = "3930" or [id] = "5630" or [id] = "4364" or [id] = "1009" or [id] = "3727" or [id] = "2502" or [id] = "3540")),
        addFundraiserCol = Table.AddColumn(removeCols, "af col tmp", each LoadTableForSingleRec([id], "constituent/v1/constituents/#{0}/fundraiserassignments?include_inactive=true", AssignedFundraisersType), AssignedFundraisersType),
        renameId = Table.RenameColumns(addFundraiserCol, {{"id", "constituent_id"}}),
        expandFundraiser = Table.ExpandTableColumn(renameId, "af col tmp",
            {
                "id",
                "fundraiser_id",
                "type",
                "start",
                "end",
                "amount",
                "campaign_id",
                "fund_id",
                "appeal_id"
            },
            {
                "fundraiser_assignment_id",
                "fundraiser_constituent_id",
                "type",
                "start",
                "end",
                "amount",
                "campaign_id",
                "fund_id",
                "appeal_id"
            }),
        transformStartDate = ConvertToDateCol(expandFundraiser, "start"),
        transformEndDate = ConvertToDateCol(transformStartDate, "end"),
        expandAmount= ExpandValueType(transformEndDate, "amount"),
        finalFilter = Table.SelectRows(expandAmount, each [fundraiser_assignment_id] <> null)
    in
        finalFilter;

ConstituentAliasesLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id"})),
        addAliasCol = Table.AddColumn(removeCols, "ca col tmp", each LoadTableForSingleRec([id], "constituent/v1/constituents/#{0}/aliases", AliasType), AliasType),
        renameId = Table.RenameColumns(addAliasCol, {{"id", "constituent_id"}}),
        expandAlias = Table.ExpandTableColumn(renameId, "ca col tmp",
            {
                "id",
                "name",
                "type"
            },
            {
                "alias_id",
                "name",
                "type"
            }),
        finalFilter = Table.SelectRows(expandAlias, each [alias_id] <> null)
    in
        finalFilter;

CommunicationPrefsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id"})),
        addCommPrefsCol = Table.AddColumn(removeCols, "cp col tmp", each LoadTableForSingleRec([id], "constituent/v1/constituents/#{0}/communicationpreferences", CommunicationPrefsType), CommunicationPrefsType),
        renameId = Table.RenameColumns(addCommPrefsCol, {{"id", "constituent_id"}}),
        expandFundraiser = Table.ExpandTableColumn(renameId, "cp col tmp",
            {
                "id",
                "solicit_code",
                "start",
                "end"
            },
            {
                "communication_preference_id",
                "solicit_code",
                "start",
                "end"
            }),
        transformStartDate = ConvertToDateCol(expandFundraiser, "start"),
        transformEndDate = ConvertToDateCol(transformStartDate, "end"),
        finalFilter = Table.SelectRows(transformEndDate, each [communication_preference_id] <> null)
    in
        finalFilter;

FirstGiftLayout = (sourceTable as table) as table =>
    let
        result = GivingSummaryLayout(sourceTable, "first")
    in
        result;

GreatestGiftLayout = (sourceTable as table) as table =>
    let
        result = GivingSummaryLayout(sourceTable, "greatest")
    in
        result;

LatestGiftLayout = (sourceTable as table) as table =>
    let
        result = GivingSummaryLayout(sourceTable, "latest")
    in
        result;

LifetimeGivingLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id"})),
        addLiefetimeGivingCol = Table.AddColumn(removeCols, "lg col tmp", each LoadRecordForSingleRec([id], "constituent/v1/constituents/#{0}/givingsummary/lifetimegiving"), LifetimeGivingType),
        removeErrors = Table.RemoveRowsWithErrors(addLiefetimeGivingCol, {"lg col tmp"}),
        expandLifetimeGiving = Table.ExpandRecordColumn(removeErrors, "lg col tmp", 
            {
                "total_years_given",
                "consecutive_years_given",
                "total_received_giving",
                "total_received_matching_gifts",
                "total_pledge_balance",
                "total_committed_matching_gifts",
                "total_soft_credits",
                "total_giving"
            }, 
            {
                "total_years_given",
                "consecutive_years_given",
                "total_received_giving",
                "total_received_matching_gifts",
                "total_pledge_balance",
                "total_committed_matching_gifts",
                "total_soft_credits",
                "total_giving"
            }),
        expandTRGAmount= ExpandValueType(expandLifetimeGiving, "total_received_giving"),
        expandTRMGAmount= ExpandValueType(expandTRGAmount, "total_received_matching_gifts"),
        expandTPBAmount= ExpandValueType(expandTRMGAmount, "total_pledge_balance"),
        expandTCMGAmount= ExpandValueType(expandTPBAmount, "total_committed_matching_gifts"),
        expandTSCAmount= ExpandValueType(expandTCMGAmount, "total_soft_credits"),
        expandTGAmount= ExpandValueType(expandTSCAmount, "total_giving"),
        renameId = Table.RenameColumns(expandTGAmount, {{"id", "constituent_id"}})
    in
        renameId;

ConstituentRatingsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id"})),
        addRatingsCol = Table.AddColumn(removeCols, "cr col tmp", each LoadTableForSingleRec([id], "constituent/v1/constituents/#{0}/ratings?include_inactive=true", RatingsType), RatingsType),
        renameId = Table.RenameColumns(addRatingsCol, {{"id", "constituent_id"}}),
        expandRatings = Table.ExpandTableColumn(renameId, "cr col tmp",
            {
                "id",
                "source",
                "category",
                "type",
                "value",
                "date",
                "comment",
                "inactive"
            },
            {
                "rating_id",
                "source",
                "category",
                "type",
                "value",
                "date",
                "comment",
                "inactive"
            }),
        transformDate = ConvertToDateCol(expandRatings, "date"),
        finalFilter = Table.SelectRows(transformDate, each [rating_id] <> null)
    in
        finalFilter;

RelationshipsLayout = (sourceTable as table) as table =>
    let
        expandStart = ExpandFuzzyDateType(sourceTable, "start"),
        expandEnd = ExpandFuzzyDateType(expandStart, "end"),
        renameId = Table.RenameColumns(expandEnd,{{"id", "relationship_id"}}),
        renameRelationId = Table.RenameColumns(renameId,{{"relation_id", "relation_constituent_id"}})
    in
        renameRelationId;

ConstituentCustomFieldsLayout = (sourceTable as table) as table =>
    let
        renameId = Table.RenameColumns(sourceTable,{{"id", "constituent_custom_field_id"}}),
        renameParentId = Table.RenameColumns(renameId, {{"parent_id", "constituent_id"}}),
        transformValue = TransformCustomFieldValue(renameParentId),
        transformDate = ConvertToDateCol(transformValue, "date")
    in
        transformDate;

ConstituentActionLayout = (sourceTable as table) as table =>
    let
        renameId = Table.RenameColumns(sourceTable,{{"id", "action_id"}}),
        transformDate = ConvertToDateCol(renameId, "date"),
        transformCompletedDate = ConvertToDateCol(transformDate, "completed_date")
        //removeCols = Table.RemoveColumns(transformCompletedDate, {"fundraisers"})
    in
        transformCompletedDate;

ConstituentActionCustomFieldsLayout = (sourceTable as table) as table =>
    let
        result = GenericCustomFieldsLayout(sourceTable, "constituent/v1/actions/#{0}/customfields", "action")
    in
        result;

ConstituentPhonesLayout = (sourceTable as table) as table =>
    let
        renameId = Table.RenameColumns(sourceTable,{{"id", "phone_id"}})
    in
        renameId;

ConstituentEmailsLayout = (sourceTable as table) as table =>
    let
        renameId = Table.RenameColumns(sourceTable,{{"id", "email_id"}})
    in
        renameId;

ConstituentAddressesLayout = (sourceTable as table) as table =>
    let
        renameId = Table.RenameColumns(sourceTable,{{"id", "address_id"}}),
        expandSeasStart = ExpandSeasonalDateType(renameId, "seasonal_start"),
        expandSeasEnd = ExpandSeasonalDateType(expandSeasStart, "seasonal_end"),
        transformStartDate = ConvertToDateCol(expandSeasEnd, "start"),
        transformEndDate = ConvertToDateCol(transformStartDate, "end")
    in
        transformEndDate;

ConstituentEducationLayout = (sourceTable as table) as table =>
    let
        expandDateEntered = ExpandFuzzyDateType(sourceTable, "date_entered"),
        expandDateLeft = ExpandFuzzyDateType(expandDateEntered, "date_left"),
        expandDateGraduated = ExpandFuzzyDateType(expandDateLeft, "date_graduated"),
        renameId = Table.RenameColumns(expandDateGraduated,{{"id", "education_id"}})
        //removeCols = Table.RemoveColumns(renameId, {"majors", "minors"})
    in
        renameId;

ConstituentCodesLayout = (sourceTable as table) as table =>
    let
        expandStart = ExpandFuzzyDateType(sourceTable, "start"),
        expandEnd = ExpandFuzzyDateType(expandStart, "end"),
        renameId = Table.RenameColumns(expandEnd,{{"id", "constituent_code_id"}})
    in
        renameId;

ConstituentOnlinePresenceLayout = (sourceTable as table) as table =>
    let
        renameId = Table.RenameColumns(sourceTable,{{"id", "online_presence_id"}})
    in
        renameId;

ConstituentNotesLayout = (sourceTable as table) as table =>
    let
        expandDate = ExpandFuzzyDateType(sourceTable, "date"),
        renameId = Table.RenameColumns(expandDate,{{"id", "note_id"}})
    in
        renameId;

ConstituentMembershipLayout = (sourceTable as table) as table =>
    let
        renameId = Table.RenameColumns(sourceTable,{{"id", "membership_id"}}),
        expandDues = ExpandValueType(renameId, "dues"),
        transformJoinedDate = ConvertToDateCol(expandDues, "joined"),
        transformExpiresDate = ConvertToDateCol(transformJoinedDate, "expires")
        //removeCols = Table.RemoveColumns(transformExpiresDate, {"members"})
    in
        transformExpiresDate;

ProfilePictureLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id"})),
        addProfilePictureCol = Table.AddColumn(removeCols, "pp col tmp", each LoadRecordForSingleRec([id], "constituent/v1/constituents/#{0}/profilepicture"), ProfilePictureType),
        removeErrors = Table.RemoveRowsWithErrors(addProfilePictureCol, {"pp col tmp"}),
        expandProspectStatus = Table.ExpandRecordColumn(removeErrors, "pp col tmp", 
            {
                "thumbnail_url", 
                "url"
            }, 
            {
                "thumbnail_url", 
                "url"
            }),
        renameId = Table.RenameColumns(expandProspectStatus, {{"id", "constituent_id"}}),
        finalFilter = Table.SelectRows(renameId, each ([thumbnail_url] <> null))
    in
        finalFilter;

GiftLayout = (sourceTable as table) as table =>
    let
        renameId = Table.RenameColumns(sourceTable,{{"id", "gift_id"}}),
        renameLookup = Table.RenameColumns(renameId,{{"lookup_id", "gift_lookup_id"}}),
        expandAmount = ExpandValueType(renameLookup, "amount"),
        expandBalance = ExpandValueType(expandAmount, "balance"),
        expandGiftAid = ExpandValueType(expandBalance, "gift_aid_amount"),
        expandRecurringGiftSchedule = Table.ExpandTableColumn(expandGiftAid, "recurring_gift_schedule",
            {
                "frequency",
                "start_date",
                "end_date"
            },
            {
                "recurring_gift_schedule.frequency",
                "recurring_gift_schedule.start_date",
                "recurring_gift_schedule.end_date"
            }),
        expandRecurringGiftStatusDate = ExpandFuzzyDateType(expandRecurringGiftSchedule, "recurring_gift_status_date"),
        transformDate = ConvertToDateCol(expandRecurringGiftStatusDate, "date"),
        transformPostDate = ConvertToDateCol(transformDate, "post_date"),
        transformRGScheduleStartDate = ConvertToDateCol(transformPostDate, "recurring_gift_schedule.start_date"),
        transformRGScheduleEndDate = ConvertToDateCol(transformRGScheduleStartDate, "recurring_gift_schedule.end_date")
        //removeCols = Table.RemoveColumns(transformRGScheduleEndDate, {"gift_splits", "acknowledgements", "fundraisers", "payments", "receipts", "soft_credits"})
        //removeCols = Table.RemoveColumns(transformRGScheduleEndDate, {"gift_splits", "fundraisers", "payments", "receipts", "soft_credits"})
        //addGrossAmount = Table.AddColumn(removeCols, "amount_plus_gift_aid", each [amount] + [gift_aid_amount]),
        //transformAmountPlusGiftAid = Table.TransformColumnTypes(addGrossAmount,{{"amount_plus_gift_aid", type number}})
    in
        transformRGScheduleEndDate;

GiftBatchLayout = (sourceTable as table) as table =>
    let
        renameId = Table.RenameColumns(sourceTable,{{"id", "gift_batch_id"}})
    in
        renameId;

GiftCustomFieldsLayout = (sourceTable as table) as table =>
    let
        renameId = Table.RenameColumns(sourceTable,{{"id", "gift_custom_field_id"}}),
        renameParentId = Table.RenameColumns(renameId,{{"parent_id", "gift_id"}}),
        transformValue = TransformCustomFieldValue(renameParentId),
        transformDate = ConvertToDateCol(transformValue, "date")
    in
        transformDate;

OpportunityLayout = (sourceTable as table) as table =>
    let
        renameId = Table.RenameColumns(sourceTable,{{"id", "opportunity_id"}}),
        expandAskAmount = ExpandValueType(renameId, "ask_amount"),
        expandExpectedAmount = ExpandValueType(expandAskAmount, "expected_amount"),
        expandFundedAmount = ExpandValueType(expandExpectedAmount, "funded_amount"),
        transformDeadlineDate = ConvertToDateCol(expandFundedAmount, "deadline"),
        transformAskDate = ConvertToDateCol(transformDeadlineDate, "ask_date"),
        transformExpectedDate = ConvertToDateCol(transformAskDate, "expected_date"),
        transformFundedDate = ConvertToDateCol(transformExpectedDate, "funded_date")
        //removeCols = Table.RemoveColumns(transformFundedDate, {"fundraisers", "linked_gifts"})
    in
        transformFundedDate;

OpportunityCustomFieldsLayout = (sourceTable as table) as table =>
    let
        result = GenericCustomFieldsLayout(sourceTable, "opportunity/v1/opportunities/#{0}/customfields", "opportunity")
    in
        result;

CampaignLayout = (sourceTable as table) as table =>
    let
        expandGoal = ExpandValueType(sourceTable, "goal"),
        renameId = Table.RenameColumns(expandGoal,{{"id", "campaign_id"}}),
        renameLookup = Table.RenameColumns(renameId,{{"lookup_id", "campaign_lookup_id"}}),
        transformStartDate = ConvertToDateCol(renameLookup, "start_date"),
        transformEndDate = ConvertToDateCol(transformStartDate, "end_date")
    in
        transformEndDate;

CampaignCustomFieldsLayout = (sourceTable as table) as table =>
    let
        result = GenericCustomFieldsLayout(sourceTable, "fundraising/v1/campaigns/#{0}/customfields", "campaign")
    in
        result;

FundLayout = (sourceTable as table) as table =>
    let
        expandGoal = ExpandValueType(sourceTable, "goal"),
        renameId = Table.RenameColumns(expandGoal,{{"id", "fund_id"}}),
        renameLookup = Table.RenameColumns(renameId,{{"lookup_id", "fund_lookup_id"}}),
        transformStartDate = ConvertToDateCol(renameLookup, "start_date"),
        transformEndDate = ConvertToDateCol(transformStartDate, "end_date")
    in
        transformEndDate;

FundCustomFieldsLayout = (sourceTable as table) as table =>
    let
        result = GenericCustomFieldsLayout(sourceTable, "fundraising/v1/funds/#{0}/customfields", "fund")
    in
        result;

AppealLayout = (sourceTable as table) as table =>
    let
        expandGoal = ExpandValueType(sourceTable, "goal"),
        renameId = Table.RenameColumns(expandGoal,{{"id", "appeal_id"}}),
        renameLookup = Table.RenameColumns(renameId,{{"lookup_id", "appeal_lookup_id"}}),
        transformStartDate = ConvertToDateCol(renameLookup, "start_date"),
        transformEndDate = ConvertToDateCol(transformStartDate, "end_date")
    in
        transformEndDate;

AppealCustomFieldsLayout = (sourceTable as table) as table =>
    let
        result = GenericCustomFieldsLayout(sourceTable, "fundraising/v1/appeals/#{0}/customfields", "appeal")
    in
        result;

AppealPackagesLayout = (sourceTable as table) as table =>
    let
        expandDefaultGiftAmt = ExpandValueType(sourceTable, "default_gift_amount"),
        expandGoal = ExpandValueType(expandDefaultGiftAmt, "goal"),
        renameId = Table.RenameColumns(expandGoal,{{"id", "package_id"}}),
        renameLookup = Table.RenameColumns(renameId,{{"lookup_id", "package_lookup_id"}}),
        transformStartDate = ConvertToDateCol(renameLookup, "start"),
        transformEndDate = ConvertToDateCol(transformStartDate, "end")
    in
        transformEndDate;

AccountLayout = (sourceTable as table) as table =>
    let
        transformPreventPostingDate = ConvertToDateCol(sourceTable, "prevent_posting_date"),
        //removeCols = Table.RemoveColumns(transformPreventPostingDate, {"custom_fields", "default_transaction_codes"})
        removeCols = Table.RemoveColumns(transformPreventPostingDate, {"account_id"}),
        removeStatsCols = RemoveUserStatsColumns(removeCols),
        addKey = AddPrimaryKeyToTable(removeStatsCols, "account_number")
    in
        addKey;

ProjectLayout = (sourceTable as table) as table =>
    let
        expandAccountRestrictions = Table.ExpandRecordColumn(sourceTable, "account_restrictions",
            {
                "allow_or_restrict",
                "criteria"
            },
            {
                "account_restrictions.allow_or_restrict",
                "account_restrictions.criteria"
            }),
        transformStartDate = ConvertToDateCol(expandAccountRestrictions, "start_date"),
        transformEndDate = ConvertToDateCol(transformStartDate, "end_date"),
        transformPostingDate = ConvertToDateCol(transformEndDate, "posting_date"),
        //removeCols = Table.RemoveColumns(transformPostingDate, {"contacts", "custom_fields"})
        removeCols = Table.RemoveColumns(transformPostingDate, {"project_id"}),
        removeStatsCols = RemoveUserStatsColumns(removeCols),
        addKey = AddPrimaryKeyToTable(removeStatsCols, "ui_project_id")
    in
        addKey;

TransactionDistributionLayout = (sourceTable as table) as table =>
    let
        transformPostDate = ConvertToDateCol(sourceTable, "post_date"),
        //removeCols = Table.RemoveColumns(transformPostDate, {"transaction_code_values"})
        removeStatsCols = RemoveUserStatsColumns(transformPostDate),
        addKey = AddPrimaryKeyToTable(removeStatsCols, "distribution_id")
    in
        addKey;

ProjectNotesLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"project_id"})),
        addNotesCol = Table.AddColumn(removeCols, "pn col tmp", each LoadTableForSingleRec(Number.ToText([project_id]), "generalledger/v1/projects/#{0}/notes", ProjectNotesType), ProjectNotesType),
        expandNotes = Table.ExpandTableColumn(addNotesCol, "pn col tmp",
            {
                "note_action_id",
                "note_type",
                "date",
                "content",
                "description",
                "type",
                "is_complete",
                "assign_to",
                "completed_date"
            },
            {
                "note_action_id",
                "note_type",
                "date",
                "content",
                "description",
                "type",
                "is_complete",
                "assign_to",
                "completed_date"
            }),
        transformDate = ConvertToDateCol(expandNotes, "date"),
        transformCompletedDate = ConvertToDateCol(transformDate, "completed_date"),
        finalFilter = Table.SelectRows(transformCompletedDate, each [note_action_id] <> null)
    in
        finalFilter;

ListsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, {"date_modified", "last_modified_by_user_id"})
    in
        removeCols;

BudgetListLayout = (sourceTable as table) as table =>
    let
        transformStartDate = ConvertToDateCol(sourceTable, "start_date"),
        transformEndDate = ConvertToDateCol(transformStartDate, "end_date"),
        addKey = AddPrimaryKeyToTable(transformEndDate, "budget_scenario_id")
    in
        addKey;

EventLayout = (sourceTable as table) as table =>
    let
        expandEventCategory = Table.ExpandRecordColumn(sourceTable, "category", 
            {
                "id", 
                "name", 
                "inactive"
            }, 
            {
                "category_id", 
                "category_name", 
                "category_inactive"
            })
    in
        expandEventCategory;

//3. Table-Specific Functions (table-creating)

ConstituentActionFundraisersLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id", "fundraisers"})),
        renameId = Table.RenameColumns(removeCols,{{"id", "action_id"}}),
        expandFundraisers = Table.ExpandListColumn(renameId, "fundraisers"),
        renameFundraiserId = Table.RenameColumns(expandFundraisers, {{"fundraisers", "fundraiser_constituent_id"}}),
        finalFilter = Table.SelectRows(renameFundraiserId, each [fundraiser_constituent_id] <> null)
    in
        finalFilter;

ConstituentEducationMajorsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id", "majors"})),
        renameId = Table.RenameColumns(removeCols,{{"id", "education_id"}}),
        expandMajors = Table.ExpandListColumn(renameId, "majors"),
        renameGiftId = Table.RenameColumns(expandMajors, {{"majors", "major"}}),
        finalFilter = Table.SelectRows(renameGiftId, each [major] <> null)
    in
        finalFilter;

ConstituentEducationMinorsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id", "minors"})),
        renameId = Table.RenameColumns(removeCols,{{"id", "education_id"}}),
        expandMinors = Table.ExpandListColumn(renameId, "minors"),
        renameGiftId = Table.RenameColumns(expandMinors, {{"minors", "minor"}}),
        finalFilter = Table.SelectRows(renameGiftId, each [minor] <> null)
    in
        finalFilter;

ConstituentMembershipMembersLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id", "members"})),
        renameId = Table.RenameColumns(removeCols,{{"id", "membership_id"}}),
        expandMembers = Table.ExpandTableColumn(renameId, "members",
            {
                "id",
                "constituent_id",
                "primary"
            },
            {
                "membership_member_id",
                "member_constituent_id",
                "primary"
            })
    in
        expandMembers;

GiftSplitsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id", "gift_splits"})),
        renameId = Table.RenameColumns(removeCols,{{"id", "gift_id"}}),
        expandSplits = Table.ExpandTableColumn(renameId, "gift_splits",
            {
                "id",
                "campaign_id",
                "fund_id",
                "appeal_id",
                "package_id",
                "amount",
                "gift_aid_amount",
                "gift_aid_qualification_status"
            },
            {
                "gift_split_id",
                "campaign_id",
                "fund_id",
                "appeal_id",
                "package_id",
                "amount",
                "gift_aid_amount",
                "gift_aid_qualification_status"
            }),
        expandAmount = ExpandValueType(expandSplits, "amount"),
        expandGiftAidAmount = ExpandValueType(expandAmount, "gift_aid_amount")
    in
        expandGiftAidAmount;

GiftAcknowledgementsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id", "acknowledgements"})),
        renameId = Table.RenameColumns(removeCols,{{"id", "gift_id"}}),
        expandAcknowledgements = Table.ExpandTableColumn(renameId, "acknowledgements",
            {
                "status",
                "date",
                "letter"
            },
            {
                "status",
                "date",
                "letter"
            }),
        transformDate = ConvertToDateCol(expandAcknowledgements, "date")
    in
        transformDate;

GiftFundraisersLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id", "fundraisers"})),
        renameId = Table.RenameColumns(removeCols,{{"id", "gift_id"}}),
        expandFundraisers = Table.ExpandTableColumn(renameId, "fundraisers",
            {
                "constituent_id",
                "amount"
            },
            {
                "fundraiser_constituent_id",
                "amount"
            }),
        expandAmount = ExpandValueType(expandFundraisers, "amount"),
        finalFilter = Table.SelectRows(expandAmount, each [fundraiser_constituent_id] <> null)
    in
        finalFilter;

GiftPaymentsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id", "payments"})),
        renameId = Table.RenameColumns(removeCols,{{"id", "gift_id"}}),
        expandPayments = Table.ExpandTableColumn(renameId, "payments",
            {
                "payment_method",
                "reference",
                "reference_date",
                "check_number",
                "check_date",
                "account_token",
                "checkout_transaction_id",
                "bbps_configuration_id",
                "bbps_transaction_id"
            },
            {
                "payment_method",
                "reference",
                "reference_date",
                "check_number",
                "check_date",
                "account_token",
                "checkout_transaction_id",
                "bbps_configuration_id",
                "bbps_transaction_id"
            }),
        expandRefDate = ExpandFuzzyDateType(expandPayments, "reference_date"),
        expandChequeDate = ExpandFuzzyDateType(expandRefDate, "check_date"),
        finalFilter = Table.SelectRows(expandChequeDate, each [payment_method] <> null)
    in
        finalFilter;

GiftReceiptsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id", "receipts"})),
        renameId = Table.RenameColumns(removeCols,{{"id", "gift_id"}}),
        expandReceipts = Table.ExpandTableColumn(renameId, "receipts",
            {
                "status",
                "date",
                "amount",
                "number"
            },
            {
                "status",
                "date",
                "amount",
                "number"
            }),
        expandAmount = ExpandValueType(expandReceipts, "amount"),
        transformDate = ConvertToDateCol(expandAmount, "date")
    in
        transformDate;

GiftSoftCreditsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id", "soft_credits"})),
        renameId = Table.RenameColumns(removeCols,{{"id", "gift_id"}}),
        expandSoftCredits = Table.ExpandTableColumn(renameId, "soft_credits",
            {
                "id",
                "constituent_id",
                //"gift_id",    Value is always same as parent gift ID
                "amount"
            },
            {
                "gift_softcredit_id",
                "softcredit_constituent_id",
                //"softcredit_gift_id",
                "amount"
            }),
        expandAmount = ExpandValueType(expandSoftCredits, "amount"),
        finalFilter = Table.SelectRows(expandAmount, each [softcredit_constituent_id] <> null)
    in
        finalFilter;

OpportunityFundraisersLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id", "fundraisers"})),
        renameId = Table.RenameColumns(removeCols,{{"id", "opportunity_id"}}),
        expandFundraisers = Table.ExpandTableColumn(renameId, "fundraisers",
            {
                "constituent_id",
                "credit_amount"
            },
            {
                "fundraiser_constituent_id",
                "credit_amount"
            }),
        expandAmount = ExpandValueType(expandFundraisers, "credit_amount"),
        finalFilter = Table.SelectRows(expandAmount, each [fundraiser_constituent_id] <> null)
    in
        finalFilter;

OpportunityLinkedGiftsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"id", "linked_gifts"})),
        renameId = Table.RenameColumns(removeCols,{{"id", "opportunity_id"}}),
        expandLinkedGifts = Table.ExpandListColumn(renameId, "linked_gifts"),
        renameGiftId = Table.RenameColumns(expandLinkedGifts, {{"linked_gifts", "gift_id"}}),
        finalFilter = Table.SelectRows(renameGiftId, each [gift_id] <> null)
    in
        finalFilter;

AccountCustomFieldsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"account_id", "custom_fields"})),
        expandCustomFields = GLCustomFieldsLayout(removeCols, "custom_fields")
    in
        expandCustomFields;

AccountDefaultTransactionCodesLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"account_id", "default_transaction_codes"})),
        expandTransactionCodes = TransactionCodesLayout(removeCols, "default_transaction_codes")
    in
        expandTransactionCodes;

ProjectContactsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"project_id", "contacts"})),
        expandContacts = Table.ExpandTableColumn(removeCols, "contacts",
            {
                "contact_id",
                "description",
                "country",
                "city",
                "county",
                "state",
                "address_line",
                "postal",
                "title",
                "first_name",
                "middle_name",
                "last_name",
                "suffix",
                "position",
                "address_contact_methods"
            },
            {
                "contact_id",
                "description",
                "country",
                "city",
                "county",
                "state",
                "address_line",
                "postal",
                "title",
                "first_name",
                "middle_name",
                "last_name",
                "suffix",
                "position",
                "address_contact_methods"
            }),
        finalFilter = Table.SelectRows(expandContacts, each [contact_id] <> null)
    in
        finalFilter;

ProjectCustomFieldsLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"project_id", "custom_fields"})),
        expandCustomFields = GLCustomFieldsLayout(removeCols, "custom_fields")
    in
        expandCustomFields;

shared TransactionDistributionCodesLayout.Contents = Value.ReplaceType(TransactionDistributionCodesLayout, TransactionDistributionCodesLayoutDocs);

TransactionDistributionCodesLayoutDocs = type function (
    sourceTable as (type table meta [
        Documentation.FieldCaption = "Transaction Distribution table name",
        Documentation.FieldDescription = "The table containing the transaction distributions."
    ]))
    as table meta [
        Documentation.Name = "Transaction distribution transaction code values",
        Documentation.LongDescription = "Generates a separate table containing the transaction code values from the specified transaction distribution table"
    ];

TransactionDistributionCodesLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"distribution_id", "transaction_code_values"})),
        expandTransactionCodes = TransactionCodesLayout(removeCols, "transaction_code_values")
    in
        expandTransactionCodes;

TransactionCodeListLayout = (sourceTable as table) as table =>
    let
        addKey = AddPrimaryKeyToTable(sourceTable, "transaction_code_id")
    in
        addKey;

BudgetScenarioListLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, {"id"}),
        renameIdCol = Table.RenameColumns(removeCols, {{"value", "scenario_id"}}),
        addKey = AddPrimaryKeyToTable(renameIdCol, "scenario_id")
    in
        addKey;

BudgetDetailLayout = (sourceTable as table) as table =>
    let
        removeCols = Table.RemoveColumns(sourceTable, {"scenario_id"}),
        removeStatsCols = RemoveUserStatsColumns(removeCols),
        addKey = AddPrimaryKeyToTable(removeStatsCols, "budget_scenario_id")
    in
        addKey;

BudgetDetailLinesListLayout = (sourceTable as table) as table =>
    let
        addUniqueId = Table.AddColumn(sourceTable, "budget_scenario_line_id", each Number.ToText([budget_scenario_id]) & "_" & Number.ToText([budget_line_id])),
        addKey = AddPrimaryKeyToTable(addUniqueId, "budget_scenario_line_id")
    in
        addKey;

shared BudgetDetailLinesListPeriodsLayout.Contents = Value.ReplaceType(BudgetDetailLinesListPeriodsLayout, BudgetDetailLinesListPeriodsLayoutDocs);

BudgetDetailLinesListPeriodsLayoutDocs = type function (
    sourceTable as (type table meta [
        Documentation.FieldCaption = "Budget Detail Lines List table name",
        Documentation.FieldDescription = "The table containing the list of budget detail lines."
    ]))
    as table meta [
        Documentation.Name = "Budget detail lines list periods",
        Documentation.LongDescription = "Generates a separate table containing the period distributions from the specified budget detail lines table"
    ];

BudgetDetailLinesListPeriodsLayout = (sourceTable as table) as table =>
    let
        //removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"budget_scenario_line_id", "budget_scenario_id", "budget_line_id", "periods"})),
        removeCols = Table.RemoveColumns(sourceTable, List.RemoveItems(Table.ColumnNames(sourceTable), {"budget_scenario_line_id", "periods"})),
        expandPeriods = Table.ExpandTableColumn(removeCols, "periods",
            {
                "amount",
                "sequence",
                "year_id"
            },
            {
                "amount",
                "sequence",
                "year_id"
            })
    in
        expandPeriods;

// ------ End Layout Functions -----


// ------ Begin Internal Helper Functions -----

AddMultipleQueryStringValues = (parameterName as text, parameterValue as any) as text =>
    let
        valueList = CleanUserInputList(parameterValue),
        result =
            if not List.IsEmpty(valueList) then
                let
                    fullParam = "&" & parameterName & "=",
                    queryString = fullParam & Text.Combine(valueList, fullParam)
                in
                    queryString
            else
                ""
    in
        result;

CleanUserInputList = (inputList as any) as list =>
    let
        splitList = if inputList <> null then Text.Split(inputList, ",") else {},
        trimList = List.Transform(splitList, each let inVal = Text.Trim(_), outVal = if Text.Length(inVal) = 0 then null else inVal in outVal),
        result = List.Distinct(List.RemoveNulls(trimList))
    in
        result;

// =======================================================================================
// RENXT Query feature
// Folded in from the BlackbaudRENXTQuery connector, using the "function within Navigator"
// model: the Query folder in the main Navigator (see GetRENXTNavTableRows above) has
// direct query-by-ID / ad-hoc leaves, plus a browsable tree of saved queries (by
// category/type/format).
//
// The whole feature is parameterised by (product, module), threaded through every function
// below, rather than fixed globals: RE always uses module "None" (see GetRENXTNavTableRows),
// while FE requires one of the modules in FEModules below (see GetFENXTNavTableRows /
// GetFEQueryModuleNavTable) - there is one full copy of the browse/query tree per FE module.
//
// language, formattingMode and sqlGenerationMode are optional dropdown parameters, appended
// last on every query function so existing positional calls keep working; their defaults
// ("en-US" / "UI" / "Query") live in GetQueryResultsTable. sqlGenerationMode is only offered on
// run-by-ID paths - an ad hoc definition carries its own sql_generation_mode inside the JSON.
// outputFormat is intentionally NOT exposed and stays fixed to "Csv".
//
// language is sent as the Accept-Language header on the job-start call, and controls how the
// API formats dates and numbers in the results (en-GB gives 15/08/2014, en-CA 2014-08-15,
// de-DE 15.08.2014 and 10.000,00). It also controls how filter dates inside an ad hoc
// definition are read: definitions read through the API with en-US use M/d/yyyy (hence the
// default), but JSON copied from Query in the web view uses the browser's date format, so a UK
// user running such a definition needs en-GB or day and month are swapped.
// formattingMode "None" returns birth dates encrypted, so it is not the default.
// =======================================================================================

// FE modules, per the SKY API's Module enum (RE requests must use "None" instead - see
// GetRENXTNavTableRows). Keyed by the exact API enum value; display names are resx-localized.
FEModules = {"GeneralLedger", "AccountsPayable", "AccountsReceivable", "FixedAssets", "CashReceipts"};

// Human-readable module names ("General Ledger") shown in the Module folder names and, via
// FEModuleParameterType, the "Query by ID"/"Ad hoc query" parameter dropdown - the SKY API itself
// only accepts the no-space codes above, so GetFEModuleCodeFromDisplayName translates back.
FEModuleDisplayNames = List.Transform(FEModules, each Extension.LoadString(_));

GetFEModuleCodeFromDisplayName = (displayName as text) as text =>
    let
        index = List.PositionOf(FEModuleDisplayNames, displayName)
    in
        if index = -1 then
            error Error.Record("InvalidModule", "Unrecognized Module value: " & displayName, [Module = displayName])
        else
            FEModules{index};

// 60 polls x 5s = 5 minutes before a job that never reaches a terminal status is given up on.
POLL_MAX_RETRIES = 60;
POLL_DELAY_SECONDS = 5;

// SKY API requires the subscription key on every request; POST query jobs additionally require a JSON content type
QueryRequestHeaders = DefaultRequestHeaders & [ #"Content-Type" = "application/json" ];

// helper used by the query list endpoint to strip null query-string parameters
Record.RemoveNullFields = Extension.LoadFunction("Record.RemoveNullFields.pqm");

// --------------------------------------------------------------------------------
// Direct query functions (Query folder leaves: "Query by ID" / "Ad hoc query")
// --------------------------------------------------------------------------------
// product/module are bound per Query folder (see GetRENXTNavTableRows/GetFENXTNavTableRows) -
// not user-supplied, hence this is a factory returning the actual invocable function value.
GetQueryByIdFunction = (product as text, module as text) =>
    let
        impl = (
            queryId as number,
            optional timeZoneOffsetInMinutes as nullable number,
            optional useStaticQuery as nullable logical,
            optional displayCodeTableLongDescription as nullable logical,
            optional askFields as nullable text,
            optional previewData as nullable logical,
            optional language as nullable text,
            optional formattingMode as nullable text,
            optional sqlGenerationMode as nullable text
        ) as table =>
            GetQueryResultsTable(product, module, queryId, timeZoneOffsetInMinutes, useStaticQuery, displayCodeTableLongDescription, askFields, previewData, language, formattingMode, sqlGenerationMode),

        docs = type function (
            queryId as QueryIdParameterType,
            optional timeZoneOffsetInMinutes as TimeZoneOffsetInMinutesParameterType,
            optional useStaticQuery as UseStaticQueryParameterType,
            optional displayCodeTableLongDescription as DisplayCodeTableLongDescriptionParameterType,
            optional askFields as AskFieldsParameterType,
            optional previewData as PreviewDataParameterType,
            optional language as LanguageParameterType,
            optional formattingMode as FormattingModeParameterType,
            optional sqlGenerationMode as SqlGenerationModeParameterType
        ) as table meta [
            Documentation.Name = "GetQueryResults",
            Documentation.LongDescription = Extension.LoadString("QueryByIdFunction.Documentation.LongDescription"),
            Documentation.Examples = {
                [
                    Description = Extension.LoadString("QueryByIdFunction.Example.Description"),
                    Code = "= GetQueryResults(918, -240, false, false, null, true)",
                    Result = Extension.LoadString("QueryByIdFunction.Example.Result")
                ]
            }
        ]
    in
        Value.ReplaceType(impl, docs);

// askFields is not applicable to ad hoc execution, so it is passed as null to GetQueryResultsTable.
// product/module are bound per Query folder - see GetQueryByIdFunction above.
GetAdHocQueryFunction = (product as text, module as text) =>
    let
        impl = (
            queryDefinition as text,
            optional timeZoneOffsetInMinutes as nullable number,
            optional useStaticQuery as nullable logical,
            optional displayCodeTableLongDescription as nullable logical,
            optional previewData as nullable logical,
            optional language as nullable text,
            optional formattingMode as nullable text
        ) as table =>
            GetQueryResultsTable(product, module, queryDefinition, timeZoneOffsetInMinutes, useStaticQuery, displayCodeTableLongDescription, null, previewData, language, formattingMode, null),

        docs = type function (
            queryDefinition as QueryDefinitionParameterType,
            optional timeZoneOffsetInMinutes as TimeZoneOffsetInMinutesParameterType,
            optional useStaticQuery as UseStaticQueryParameterType,
            optional displayCodeTableLongDescription as DisplayCodeTableLongDescriptionParameterType,
            optional previewData as PreviewDataParameterType,
            optional language as AdHocLanguageParameterType,
            optional formattingMode as FormattingModeParameterType
        ) as table meta [
            Documentation.Name = "GetQueryResults",
            Documentation.LongDescription = Extension.LoadString("AdHocQueryFunction.Documentation.LongDescription"),
            Documentation.Examples = {
                [
                    Description = Extension.LoadString("AdHocQueryFunction.Example.Description"),
                    Code = "= GetQueryResults(queryJson, -240, false, false, true)",
                    Result = Extension.LoadString("AdHocQueryFunction.Example.Result")
                ]
            }
        ]
    in
        Value.ReplaceType(impl, docs);

// FE counterparts of the two functions above, sitting at the top of the "Financial Edge NXT
// Query" folder rather than inside a specific module folder (see GetFEQueryModuleNavTable) - so,
// unlike GetQueryByIdFunction/GetAdHocQueryFunction, module is not bound in advance via the
// factory; it's a required parameter of the returned function itself instead.
GetFEQueryByIdFunction = (product as text) =>
    let
        impl = (
            queryId as number,
            module as text,
            optional timeZoneOffsetInMinutes as nullable number,
            optional useStaticQuery as nullable logical,
            optional displayCodeTableLongDescription as nullable logical,
            optional askFields as nullable text,
            optional previewData as nullable logical,
            optional language as nullable text,
            optional formattingMode as nullable text,
            optional sqlGenerationMode as nullable text
        ) as table =>
            GetQueryResultsTable(product, GetFEModuleCodeFromDisplayName(module), queryId, timeZoneOffsetInMinutes, useStaticQuery, displayCodeTableLongDescription, askFields, previewData, language, formattingMode, sqlGenerationMode),

        docs = type function (
            queryId as QueryIdParameterType,
            module as FEModuleParameterType,
            optional timeZoneOffsetInMinutes as TimeZoneOffsetInMinutesParameterType,
            optional useStaticQuery as UseStaticQueryParameterType,
            optional displayCodeTableLongDescription as DisplayCodeTableLongDescriptionParameterType,
            optional askFields as AskFieldsParameterType,
            optional previewData as PreviewDataParameterType,
            optional language as LanguageParameterType,
            optional formattingMode as FormattingModeParameterType,
            optional sqlGenerationMode as SqlGenerationModeParameterType
        ) as table meta [
            Documentation.Name = "GetQueryResults",
            Documentation.LongDescription = Extension.LoadString("QueryByIdFunction.Documentation.LongDescription"),
            Documentation.Examples = {
                [
                    Description = Extension.LoadString("QueryByIdFunction.Example.Description"),
                    Code = "= GetQueryResults(918, ""General Ledger"", -240, false, false, null, true)",
                    Result = Extension.LoadString("QueryByIdFunction.Example.Result")
                ]
            }
        ]
    in
        Value.ReplaceType(impl, docs);

GetFEAdHocQueryFunction = (product as text) =>
    let
        impl = (
            queryDefinition as text,
            module as text,
            optional timeZoneOffsetInMinutes as nullable number,
            optional useStaticQuery as nullable logical,
            optional displayCodeTableLongDescription as nullable logical,
            optional previewData as nullable logical,
            optional language as nullable text,
            optional formattingMode as nullable text
        ) as table =>
            GetQueryResultsTable(product, GetFEModuleCodeFromDisplayName(module), queryDefinition, timeZoneOffsetInMinutes, useStaticQuery, displayCodeTableLongDescription, null, previewData, language, formattingMode, null),

        docs = type function (
            queryDefinition as QueryDefinitionParameterType,
            module as FEModuleParameterType,
            optional timeZoneOffsetInMinutes as TimeZoneOffsetInMinutesParameterType,
            optional useStaticQuery as UseStaticQueryParameterType,
            optional displayCodeTableLongDescription as DisplayCodeTableLongDescriptionParameterType,
            optional previewData as PreviewDataParameterType,
            optional language as AdHocLanguageParameterType,
            optional formattingMode as FormattingModeParameterType
        ) as table meta [
            Documentation.Name = "GetQueryResults",
            Documentation.LongDescription = Extension.LoadString("AdHocQueryFunction.Documentation.LongDescription"),
            Documentation.Examples = {
                [
                    Description = Extension.LoadString("AdHocQueryFunction.Example.Description"),
                    Code = "= GetQueryResults(queryJson, ""General Ledger"", -240, false, false, true)",
                    Result = Extension.LoadString("AdHocQueryFunction.Example.Result")
                ]
            }
        ]
    in
        Value.ReplaceType(impl, docs);

// --------------------------------------------------------------------------------
// Parameter types with UI metadata
// --------------------------------------------------------------------------------
QueryIdParameterType = type number meta [
    Documentation.FieldCaption = Extension.LoadString("QueryIdParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("QueryIdParameterType.FieldDescription"),
    Documentation.SampleValues = {"506, 918"}
];

// Only used by the FE "Query by ID"/"Ad hoc query" functions (see GetFEQueryByIdFunction /
// GetFEAdHocQueryFunction) - RE always uses module "None" internally, with no user-facing prompt.
// The dropdown shows human-readable names ("General Ledger"); GetFEModuleCodeFromDisplayName
// translates the selected value back to the API's no-space code before it's ever used.
FEModuleParameterType = type text meta [
    Documentation.FieldCaption = Extension.LoadString("FEModuleParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("FEModuleParameterType.FieldDescription"),
    Documentation.AllowedValues = FEModuleDisplayNames
];

QueryDefinitionParameterType = type text meta [
    Documentation.FieldCaption = Extension.LoadString("QueryDefinitionParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("QueryDefinitionParameterType.FieldDescription"),
    Documentation.SampleValues = { Extension.LoadString("QueryDefinitionParameterType.SampleValues") },
    Formatting.IsMultiLine = true,
    Formatting.IsCode = true
];

TimeZoneOffsetInMinutesParameterType = type nullable number meta [
    Documentation.FieldCaption = Extension.LoadString("TimeZoneOffsetInMinutesParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("TimeZoneOffsetInMinutesParameterType.FieldDescription"),
    Documentation.SampleValues = {"-240"}
];

UseStaticQueryParameterType = type nullable logical meta [
    Documentation.FieldCaption = Extension.LoadString("UseStaticQueryParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("UseStaticQueryParameterType.FieldDescription"),
    Documentation.AllowedValues = {false, true}
];

DisplayCodeTableLongDescriptionParameterType = type nullable logical meta [
    Documentation.FieldCaption = Extension.LoadString("DisplayCodeTableLongDescriptionParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("DisplayCodeTableLongDescriptionParameterType.FieldDescription"),
    Documentation.AllowedValues = {false, true}
];

AskFieldsParameterType = type nullable text meta [
    Documentation.FieldCaption = Extension.LoadString("AskFieldsParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("AskFieldsParameterType.FieldDescription"),
    Documentation.SampleValues = { Extension.LoadString("AskFieldsParameterType.SampleValues") },
    Formatting.IsMultiLine = true,
    Formatting.IsCode = true
];

// Used only by the browse-tree curried functions below, where ask fields are required
// (the query itself declares them as mandatory), unlike the optional AskFieldsParameterType above.
RequiredAskFieldsParameterType = type text meta [
    Documentation.FieldCaption = Extension.LoadString("AskFieldsParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("AskFieldsParameterType.FieldDescription"),
    Documentation.SampleValues = { Extension.LoadString("AskFieldsParameterType.SampleValues") },
    Formatting.IsMultiLine = true,
    Formatting.IsCode = true
];

PreviewDataParameterType = type nullable logical meta [
    Documentation.FieldCaption = Extension.LoadString("PreviewDataParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("PreviewDataParameterType.FieldDescription"),
    Documentation.AllowedValues = {false, true}
];

// Sent as the Accept-Language header (see the comment at the top of this feature section).
// Limited to the locales tested against the Query API; the first value is the default.
QueryLanguages = {"en-US", "en-GB", "en-CA", "en-AU", "en-NZ", "fr-CA", "de-DE"};

LanguageParameterType = type nullable text meta [
    Documentation.FieldCaption = Extension.LoadString("LanguageParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("LanguageParameterType.FieldDescription"),
    Documentation.AllowedValues = QueryLanguages
];

// Same values as LanguageParameterType, with a description that also warns how the language
// changes the reading of filter dates inside the ad hoc definition.
AdHocLanguageParameterType = type nullable text meta [
    Documentation.FieldCaption = Extension.LoadString("LanguageParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("AdHocLanguageParameterType.FieldDescription"),
    Documentation.AllowedValues = QueryLanguages
];

FormattingModeParameterType = type nullable text meta [
    Documentation.FieldCaption = Extension.LoadString("FormattingModeParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("FormattingModeParameterType.FieldDescription"),
    Documentation.AllowedValues = {"UI", "Export", "None"}
];

SqlGenerationModeParameterType = type nullable text meta [
    Documentation.FieldCaption = Extension.LoadString("SqlGenerationModeParameterType.FieldCaption"),
    Documentation.FieldDescription = Extension.LoadString("SqlGenerationModeParameterType.FieldDescription"),
    Documentation.AllowedValues = {"Query", "Export", "Report"}
];

// --------------------------------------------------------------------------------
// Query navigation tables (Query folder: browse saved queries, or run directly by ID/ad hoc)
// --------------------------------------------------------------------------------
// The "browse" rows shared by every Query folder variant: All queries/My queries/Favorites/Merged
// queries/Categories/Types/Format. Used directly by RE (via GetQueryNavTable below) and, on its
// own (without the direct-execution rows), by each FE module folder - see GetFEQueryModuleNavTable.
GetQueryBrowseRows = (product as text, module as text) as list =>
    {
        {"allQueries", GetQueryListNavTable(product, module, null, null, null, false, false, false), "Folder", "Folder", false},
        {"myQueries", GetQueryListNavTable(product, module, null, null, null, true, false, false), "Folder", "Folder", false},
        {"favorites", GetQueryListNavTable(product, module, null, null, null, false, true, false), "Folder", "Folder", false},
        {"mergedQueries", GetQueryListNavTable(product, module, null, null, null, false, false, true), "Folder", "Folder", false},
        {"categories", GetQueryCategoryNavTable(product, module), "Folder", "Folder", false},
        {"types", GetQueryTypeNavTable(product, module), "Folder", "Folder", false},
        {"format", GetQueryFormatNavTable(product, module), "Folder", "Folder", false},
        {"resultLayout", GetQueryResultLayoutNavTable(product, module), "Folder", "Folder", false}
    };

// Turns a list of {Key, Data, ItemKind, ItemName, IsLeaf} rows into a Navigator table, looking up
// each row's localized display name from its Key (matching resources.resx entries).
BuildQueryNavTable = (rows as list) as table =>
    let
        rowsWithName = List.Transform(rows, each
            List.InsertRange(_, 0, { Extension.LoadString(_{0}) })
        ),

        navTable = #table(
            QueryNavigationTableType,
            rowsWithName
        ),

        result = Table.ToNavigationTable(navTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        result;

// ItemName = null on Function rows opts them out of Preview.DelayColumn so the Navigator renders
// the inline parameter-entry form (see Table.ToNavigationTable.pqm).
GetQueryNavTable = (product as text, module as text) as table =>
    BuildQueryNavTable(
        GetQueryBrowseRows(product, module) & {
            {"queryById", GetQueryByIdFunction(product, module), "Function", null, true},
            {"adHocQuery", GetAdHocQueryFunction(product, module), "Function", null, true}
        }
    );

// FE per-module folders (see GetFEQueryModuleNavTable): browsing only, no direct-execution rows -
// "Query by ID"/"Ad hoc query" live once at the top FE level instead, with module as a required
// parameter, rather than once per module.
GetQueryBrowseNavTable = (product as text, module as text) as table =>
    BuildQueryNavTable(GetQueryBrowseRows(product, module));

GetQueryListNavTable = (
    product as text,
    module as text,
    categoryId as nullable number,
    typeId as nullable number,
    format as nullable text,
    myQueriesOnly as logical,
    favoritesOnly as logical,
    mergedQueriesOnly as logical,
    optional resultLayout as nullable text
) as table =>
    let
        // define a curried function with `id` and `name` bound per row
        curriedFunction = (queryId as number, name as text) =>
            let
                curried = (
                    optional timeZoneOffsetInMinutes as nullable number,
                    optional useStaticQuery as nullable logical,
                    optional displayCodeTableLongDescription as nullable logical,
                    optional previewData as nullable logical,
                    optional language as nullable text,
                    optional formattingMode as nullable text,
                    optional sqlGenerationMode as nullable text
                ) =>
                    GetQueryResultsTable(product, module, queryId, timeZoneOffsetInMinutes, useStaticQuery, displayCodeTableLongDescription, null, previewData, language, formattingMode, sqlGenerationMode),

                curriedDocs = type function (
                    optional timeZoneOffsetInMinutes as TimeZoneOffsetInMinutesParameterType,
                    optional useStaticQuery as UseStaticQueryParameterType,
                    optional displayCodeTableLongDescription as DisplayCodeTableLongDescriptionParameterType,
                    optional previewData as PreviewDataParameterType,
                    optional language as LanguageParameterType,
                    optional formattingMode as FormattingModeParameterType,
                    optional sqlGenerationMode as SqlGenerationModeParameterType
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
                                "= #""#{0}"".Contents(-240, false, false, true)",
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

        // define a curried function with required ask fields, `id` and `name` bound per row.
        // askFields comes first here (not last, unlike the direct GetQueryByIdFunction above)
        // because M requires optional parameters to trail required ones, and askFields is
        // genuinely required for queries where it applies.
        curriedFunctionWithAskFields = (queryId as number, name as text) =>
            let
                curried = (
                    askFields as text,
                    optional timeZoneOffsetInMinutes as nullable number,
                    optional useStaticQuery as nullable logical,
                    optional displayCodeTableLongDescription as nullable logical,
                    optional previewData as nullable logical,
                    optional language as nullable text,
                    optional formattingMode as nullable text,
                    optional sqlGenerationMode as nullable text
                ) =>
                    GetQueryResultsTable(product, module, queryId, timeZoneOffsetInMinutes, useStaticQuery, displayCodeTableLongDescription, askFields, previewData, language, formattingMode, sqlGenerationMode),

                curriedDocs = type function (
                    askFields as RequiredAskFieldsParameterType,
                    optional timeZoneOffsetInMinutes as TimeZoneOffsetInMinutesParameterType,
                    optional useStaticQuery as UseStaticQueryParameterType,
                    optional displayCodeTableLongDescription as DisplayCodeTableLongDescriptionParameterType,
                    optional previewData as PreviewDataParameterType,
                    optional language as LanguageParameterType,
                    optional formattingMode as FormattingModeParameterType,
                    optional sqlGenerationMode as SqlGenerationModeParameterType
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
                                "= #""#{0}"".Contents(askFieldsJson, -240, false, false, true)",
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
        queries = GetQueryListTable(product, module, categoryId, typeId, format, myQueriesOnly, favoritesOnly, mergedQueriesOnly, resultLayout),

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
            // null opts this row out of Preview.DelayColumn so the Navigator renders the
            // inline parameter-entry form (see Table.ToNavigationTable.pqm).
            ItemName = null,
            IsLeaf = true
        ]),

        // Convert to a list of lists, which is needed for the #table operator
        rows = List.Transform(navTableList, each {_[Name], _[Key], _[Data], _[ItemKind], _[ItemName], _[IsLeaf]}),

        // Convert the list of records into a proper table (which may be empty)
        navTable = #table(
            QueryNavigationTableType,
            rows
        ),

        result = Table.ToNavigationTable(navTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        result;

GetQueryCategoryNavTable = (product as text, module as text) as table =>
    let
        categories = GetQueryCategoryTable(product, module),

        navTableList = Table.TransformRows(categories, each [
            Key = [id],
            Name = [name],
            Data = GetQueryListNavTable(product, module, [id], null, null, false, false, false),
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ]),

        navTable = Table.FromRecords(navTableList),

        result = Table.ToNavigationTable(navTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        result;

GetQueryTypeNavTable = (product as text, module as text) as table =>
    let
        types = GetQueryTypeTable(product, module),

        navTableList = Table.TransformRows(types, each [
            Key = [id],
            Name = [name],
            Data = GetQueryListNavTable(product, module, null, [id], null, false, false, false),
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ]),

        navTable = Table.FromRecords(navTableList),

        result = Table.ToNavigationTable(navTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        result;

GetQueryFormatNavTable = (product as text, module as text) as table =>
    let
        formats = {"dynamic", "static"},

        navTableList = List.Transform(formats, each [
            Key = _,
            Name = Extension.LoadString(_),
            Data = GetQueryListNavTable(product, module, null, null, _, false, false, false),
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ]),

        navTable = Table.FromRecords(navTableList),

        result = Table.ToNavigationTable(navTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        result;

GetQueryResultLayoutNavTable = (product as text, module as text) as table =>
    let
        resultLayouts = {"MultiRow", "SingleRow"},

        navTableList = List.Transform(resultLayouts, each [
            Key = _,
            Name = Extension.LoadString(_),
            Data = GetQueryListNavTable(product, module, null, null, null, false, false, false, _),
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ]),

        navTable = Table.FromRecords(navTableList),

        result = Table.ToNavigationTable(navTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        result;

// Top-level folder for the "Financial Edge NXT Query" branch (see GetFENXTNavTableRows): one
// browse-only sub-folder per FE module, sitting alongside "Query by ID"/"Ad hoc query" - those two
// don't need a module chosen in advance (they run a specific, already-known query), so they take
// module as a required parameter instead of being duplicated once per module folder.
GetFEQueryModuleNavTable = () as table =>
    let
        moduleRows = List.Transform(FEModules, each {_, GetQueryBrowseNavTable("FE", _), "Folder", "Folder", false}),
        functionRows = {
            {"queryById", GetFEQueryByIdFunction("FE"), "Function", null, true},
            {"adHocQuery", GetFEAdHocQueryFunction("FE"), "Function", null, true}
        }
    in
        BuildQueryNavTable(moduleRows & functionRows);

// --------------------------------------------------------------------------------
// Query SKY API functions
// --------------------------------------------------------------------------------

// https://developer.sky.blackbaud.com/api#api=query&operation=GetQueryCategories
GetQueryCategoryTable = (product as text, module as text) as table =>
    let
        response = Web.ContentsCustomRetry(
            BaseUrl,
            [
                RelativePath = "/query/categories",
                Query = [
                    product = product,
                    module = module
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
GetQueryTypeTable = (product as text, module as text) as table =>
    let
        response = Web.ContentsCustomRetry(
            BaseUrl,
            [
                RelativePath = "/query/querytypes",
                Query = [
                    product = product,
                    module = module
                ],
                Headers = DefaultRequestHeaders
            ]
        ),
        bodyJson = Json.Document(response),

        rawTable = Table.FromRecords(bodyJson[query_types], null, MissingField.UseNull),
        result = Table.ChangeType(rawTable, QueryTypeTableType)
    in
        result;

// v2 - not v1's GET /query/queries, which will only ever return MultiRow queries (per Blackbaud's
// single-row result layout preview doc) and so can never show SingleRow/Export-style saved
// queries. v2 matches v1's request/response shape otherwise, with one exception: it has no
// `offset` parameter at all - paging is continuation_token-based instead (see GetQueryListTable).
// https://developer.sky.blackbaud.com/api#api=query&operation=GetQueryListV2
GetQueryListPage = (
    product as text,
    module as text,
    categoryId as nullable number,
    typeId as nullable number,
    format as nullable text,
    myQueriesOnly as logical,
    favoritesOnly as logical,
    mergedQueriesOnly as logical,
    resultLayout as nullable text,
    continuationToken as nullable text
) as table =>
    let
        pageSize = 200,

        response = Web.ContentsCustomRetry(
            BaseUrl,
            [
                RelativePath = "/query/v2/queries",
                Query = Record.RemoveNullFields([
                    product = product,
                    module = module,
                    category = TextOrNull(categoryId),
                    query_type_id = TextOrNull(typeId),
                    query_format = format,
                    my_queries_only = TrueOrNull(myQueriesOnly),
                    my_fav_queries_only = TrueOrNull(favoritesOnly),
                    merged_queries_only = TrueOrNull(mergedQueriesOnly),
                    result_layout = resultLayout,
                    limit = Text.From(pageSize),
                    continuation_token = continuationToken
                ]),
                Headers = DefaultRequestHeaders
            ]
        ),
        bodyJson = Json.Document(response),
        queries = try bodyJson[queries] otherwise {},
        nextContinuationToken = try bodyJson[continuation_token] otherwise null,

        data = Table.FromRecords(queries, null, MissingField.UseNull)
    in
        data meta [ContinuationToken = nextContinuationToken];

GetQueryListTable = (
    product as text,
    module as text,
    categoryId as nullable number,
    typeId as nullable number,
    format as nullable text,
    myQueriesOnly as logical,
    favoritesOnly as logical,
    mergedQueriesOnly as logical,
    optional resultLayout as nullable text
) as table =>
    let
        allResults = Table.GenerateByPage((previous) =>
            let
                // On the first call, previous is null, so there is no continuation token yet but
                // we still need to fetch page 1. On every later call, a null ContinuationToken
                // means the previous page said there was nothing more - stop.
                continuationToken =
                    if (previous = null) then
                        null
                    else
                        Value.Metadata(previous)[ContinuationToken]?,

                isDone = previous <> null and continuationToken = null,

                page =
                    if (isDone) then
                        null
                    else
                        GetQueryListPage(
                            product,
                            module,
                            categoryId,
                            typeId,
                            format,
                            myQueriesOnly,
                            favoritesOnly,
                            mergedQueriesOnly,
                            resultLayout,
                            continuationToken
                        )
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
GetQueryStatus = (product as text, module as text, jobId as text, retry as number, includeReadUrlMode as text) as record =>
    let
        response = Web.ContentsCustomRetry(
            BaseUrl,
            [
                RelativePath = "/query/jobs/" & Text.Trim(jobId),
                Query = [
                    product = product,
                    module = module,
                    include_read_url = includeReadUrlMode,
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
    product as text,
    module as text,
    queryId as number,
    language as text,
    formattingMode as text,
    sqlGenerationMode as text,
    outputFormat as text,
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
                    product = product,
                    module = module,
                    _ts = GetTimestamp()
                ],
                Headers = QueryRequestHeaders & [ #"Accept-Language" = language ],
                Content = Text.ToBinary(
                    Text.FromBinary(
                        Json.FromValue([
                            id = queryId,
                            ux_mode = "Synchronous",
                            output_format = outputFormat,
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
    product as text,
    module as text,
    query as text,
    language as text,
    formattingMode as text,
    sqlGenerationMode as text,
    outputFormat as text,
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
                    product = product,
                    module = module,
                    _ts = GetTimestamp()
                ],
                Headers = QueryRequestHeaders & [ #"Accept-Language" = language ],
                Content = Text.ToBinary(
                    Text.FromBinary(
                        Json.FromValue([
                            query = Json.Document(query),
                            ux_mode = "Synchronous",
                            output_format = outputFormat,
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

OutputFormatToTable = (resultBinary as binary, outputFormat as text) as table =>
    let
        _outputFormat = Text.Proper(Text.Lower(Text.Trim(outputFormat))),
        result =
            if _outputFormat = "Json" then
                Table.FromRecords(Json.Document(resultBinary))
            else if _outputFormat = "Csv" then
                Table.PromoteHeaders(
                    Csv.Document(resultBinary, [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
                    [PromoteAllScalars = true]
                )
            else if _outputFormat = "Jsonl" then
                let
                    text = Text.FromBinary(resultBinary),
                    lines = List.Select(Text.Split(text, "#(lf)"), each Text.Trim(_) <> ""),
                    records = List.Transform(lines, each Json.Document(Text.Trim(_)))
                in
                    Table.FromRecords(records)
            else if _outputFormat = "Xlsx" then
                let
                    workbook = Excel.Workbook(resultBinary, null, true),
                    tableOrSheetRows = Table.SelectRows(workbook, each [Kind] = "Table" or [Kind] = "Sheet")
                in
                    if Table.RowCount(tableOrSheetRows) = 0 then
                        error Error.Record("QueryResultsError", "Xlsx output did not contain a readable sheet or table.", [])
                    else
                        tableOrSheetRows{0}[Data]
            else
                error Error.Record("QueryResultsError", "Unsupported output format. Allowed values are Json, Csv, Jsonl, Xlsx.", [OutputFormat = outputFormat])
    in
        result;

GetQueryResultsTable = (
    product as text,
    module as text,
    queryIdOrDefinition as any,
    timeZoneOffsetInMinutes as nullable number,
    useStaticQuery as nullable logical,
    displayCodeTableLongDescription as nullable logical,
    askFields as nullable text,
    optional previewData as nullable logical,
    optional language as nullable text,
    optional formattingMode as nullable text,
    optional sqlGenerationMode as nullable text
) as table =>
    let
        // language/formattingMode/sqlGenerationMode default here; outputFormat is intentionally
        // fixed - see the comment at the top of this feature section.
        _language = if language = null or Text.Trim(language) = "" then "en-US" else Text.Trim(language),
        _formattingMode = if formattingMode = null or Text.Trim(formattingMode) = "" then "UI" else Text.Trim(formattingMode),
        _sqlGenerationMode = if sqlGenerationMode = null or Text.Trim(sqlGenerationMode) = "" then "Query" else Text.Trim(sqlGenerationMode),
        _outputFormat = "Csv",
        _timeZoneOffsetInMinutes = if timeZoneOffsetInMinutes = null then GetTimeZoneOffetMinutes() else timeZoneOffsetInMinutes,
        _useStaticQuery = if useStaticQuery = null then false else useStaticQuery,
        _displayCodeTableLongDescription = if displayCodeTableLongDescription = null then false else displayCodeTableLongDescription,
        _askFields = askFields,
        _previewData = if previewData = null then false else previewData,
        _includeReadUrlMode = if _previewData then "OnceRunning" else "OnceCompleted",

        // An ad hoc definition is raw JSON text supplied by the user, so parse-check it here -
        // before the try below, which would otherwise rewrite a malformed payload as a generic
        // job-start failure. Two common causes, reported separately:
        // - Truncation: the Navigator's parameter box is single-line whatever Formatting.IsMultiLine
        //   says, so pasting formatted JSON keeps only its first line - typically just "{".
        // - JSON copied out of Power Query M code, where a literal " is escaped as "": valid in M
        //   source, but not valid JSON once it reaches here.
        _queryIdOrDefinition =
            if Type.Is(Value.Type(queryIdOrDefinition), Number.Type) then
                queryIdOrDefinition
            else
                let
                    parseAttempt = try Json.Document(queryIdOrDefinition),
                    trimmed = Text.Trim(queryIdOrDefinition),
                    // a definition is a JSON object, so anything not ending in "}" was cut short.
                    // Only evaluated when the parse failed, so parseAttempt[Error] is present.
                    looksTruncated = not Text.EndsWith(trimmed, "}")
                        or Text.Contains(Record.FieldOrDefault(parseAttempt[Error], "Message", "") ?? "", "end of the buffer")
                in
                    if parseAttempt[HasError] then
                        error Error.Record(
                            "QueryDefinitionError",
                            if looksTruncated then
                                Text.Format(Extension.LoadString("adHocQueryJsonTruncated"), {Text.Length(trimmed)})
                            else
                                Extension.LoadString("adHocQueryJsonInvalid"),
                            [ReceivedLength = Text.Length(trimmed), OriginalError = parseAttempt[Error]]
                        )
                    else
                        queryIdOrDefinition,

        // start a query execution job
        startAttempt =
            Diagnostics.Trace(
                TraceLevel.Information,
                "Starting " & product & " query request. Mode = " & Text.From(_queryIdOrDefinition is number),
                try
                    if Type.Is(Value.Type(_queryIdOrDefinition), Number.Type) then
                        StartQueryJob(product, module, _queryIdOrDefinition, _language, _formattingMode, _sqlGenerationMode, _outputFormat, _timeZoneOffsetInMinutes, _useStaticQuery, _displayCodeTableLongDescription, _askFields)
                    else
                        StartAdHocQueryJob(product, module, _queryIdOrDefinition, _language, _formattingMode, _sqlGenerationMode, _outputFormat, _timeZoneOffsetInMinutes, _useStaticQuery, _displayCodeTableLongDescription)
            ),

        startJson =
            if startAttempt[HasError] then
                let
                    // This wrapper catches every job-start failure - a rejected payload, auth, rate
                    // limiting - so include the underlying message rather than only burying it in
                    // OriginalError, where it takes a drill-down into the error record to find.
                    underlyingMessage = Record.FieldOrDefault(startAttempt[Error], "Message", "")
                in
                    error Error.Record(
                        "QueryStartError",
                        if underlyingMessage <> "" then
                            Text.Format(Extension.LoadString("queryStartFailedWithReason"), {underlyingMessage})
                        else
                            Extension.LoadString("queryStartFailedNoJobId"),
                        [
                            JobId = null,
                            OriginalError = startAttempt[Error]
                        ]
                    )
            else
                startAttempt[Value],

        // A successful start response without an id would otherwise surface as a bare
        // "field 'id' not found" error.
        startedJobId = Record.FieldOrDefault(startJson, "id", null),
        jobId =
            if startedJobId = null then
                error Error.Record(
                    "QueryStartError",
                    Extension.LoadString("queryStartFailedNoJobId"),
                    [JobId = null, Response = startJson]
                )
            else
                Diagnostics.Trace(TraceLevel.Information, "Started query execution job. Job ID = " & Text.From(startedJobId), startedJobId),

        // define a recursive function to poll for the job status
        pollJob = (retry as number, maxRetries as number, pollSeconds as number) =>
            let
                timestamp = DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss"),

                statusJson = Diagnostics.Trace(TraceLevel.Information, timestamp & " - Polling job status. Attempt = " & Text.From(retry), GetQueryStatus(product, module, jobId, retry, _includeReadUrlMode)),
                status = Diagnostics.Trace(TraceLevel.Information, timestamp & " - Polling attempt " & Text.From(retry) & ": Last status = " & statusJson[status], statusJson[status]),
                readUri =
                    if Record.HasFields(statusJson, {"read_url"}) and statusJson[read_url] <> null then
                        statusJson[read_url]
                    else if Record.HasFields(statusJson, {"sas_uri"}) and statusJson[sas_uri] <> null then
                        statusJson[sas_uri]
                    else
                        null
            in
                if status = "Completed" then
                    statusJson
                else if _previewData and readUri <> null then
                    statusJson & [sas_uri = readUri]
                else if status = "Cancelled" then
                    error Error.Record("QueryJobError", Text.Format(Extension.LoadString("queryJobCanceledWithJobId"), {jobId}), [JobId = jobId])
                else if status = "Failed" then
                    error Error.Record("QueryJobError", Text.Format(Extension.LoadString("queryJobFailedWithJobId"), {jobId}), [JobId = jobId])
                else if retry >= maxRetries then
                    // Give up rather than polling a job that is never going to reach a terminal
                    // status. This check has to live here, in the branch that actually runs: as a
                    // separate let binding it was never referenced, and M does not evaluate
                    // bindings the `in` expression doesn't reach - so the ceiling never applied.
                    error Error.Record("QueryJobError", Text.Format(Extension.LoadString("maxRetriesExceededWithJobId"), {jobId}), [JobId = jobId])
                else
                    // otherwise, poll again after delaying
                    Function.InvokeAfter(() =>
                        @pollJob(retry + 1, maxRetries, pollSeconds),
                        #duration(0, 0, 0, pollSeconds)
                    ),

        // poll the query job status
        jobResultJson = pollJob(0, POLL_MAX_RETRIES, POLL_DELAY_SECONDS),

        // fetch the query results from the SAS URI returned when the job completes
        sasUri =
            if Record.HasFields(jobResultJson, {"sas_uri"}) and jobResultJson[sas_uri] <> null then
                jobResultJson[sas_uri]
            else
                error Error.Record("QueryResultsError", "Query job did not return a readable results URI.", [JobId = jobId]),
        resultBinary = Web.Contents(sasUri),
        result = OutputFormatToTable(resultBinary, _outputFormat),
        finalResult = Diagnostics.Trace(TraceLevel.Information, "Fetched query results. Row count = " & Text.From(Table.RowCount(result)), result meta [JobId = jobId])
    in
        finalResult;

// --------------------------------------------------------------------------------
// Query misc functions
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
// Query table type definitions
// --------------------------------------------------------------------------------

// https://learn.microsoft.com/en-us/power-query/handling-navigation-tables
// ItemName is nullable: Function rows set it to null to opt out of Preview.DelayColumn
// (see Table.ToNavigationTable.pqm), while Folder rows keep text to stay lazy.
QueryNavigationTableType = type table [
    Name = text,
    Key = any,
    Data = function,
    ItemKind = text,
    ItemName = nullable text,
    IsLeaf = logical
];

// https://developer.sky.blackbaud.com/api#api=query&operation=GetQueryCategories
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

// ------ End Internal Helper Functions -----