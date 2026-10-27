"""Generate the Blackbaud connector test-harness PBIP (TMDL semantic model + PBIR report).

Usage:
    python generate_pbip.py <output folder> <base theme json>

<base theme json> is a Fluent2-CY*.json base theme taken from any PBIP saved by your version of
Power BI Desktop (<name>.Report/StaticResources/SharedResources/BaseThemes/).

Regenerating rewrites every table file, which drops the column definitions Power BI Desktop saved
into them (Desktop re-detects them on the next refresh). For a small addition, it is usually
easier to add the new table's .tmdl file by hand and extend model.tmdl and 'Smoke Test'.

The IDs below (lists, events, saved queries) are from the US Developer Cohort sandbox.
"""
import json, os, sys, uuid

OUT = sys.argv[1]
NAME = "BlackbaudConnectorTests"
SM = os.path.join(OUT, f"{NAME}.SemanticModel")
RP = os.path.join(OUT, f"{NAME}.Report")

LIST_ID = "78850ad4-5a0c-4000-8eb7-a3994c6a07b4"   # "2 People" public constituent list (US cohort)
GIFT_LIST_ID = "77deed1d-64f2-4ba6-aa0f-daf1b1648338"  # "Small Set of Gifts" public gift list (US cohort)
EVENT_ID = "44582"                                  # Kobayashi Maru Reunion 4
RE_QUERY_ID = 202                                   # Volunteers with Birthdays in May (Name, Birth Date, Volunteer Job)
FE_QUERY_ID = 812                                   # Monthly GL Activity (General Ledger)


def adhoc(start, end):
    return json.dumps({
        "select_fields": [{"query_field_id": 597}, {"query_field_id": 752, "user_alias": "Birth Date"},
                          {"query_field_id": 8471}, {"query_field_id": 8469}],
        "filter_fields": [{"query_field_id": 8471, "compare_type": "None", "filter_values": [start, end],
                           "operator": "Between", "left_parenthesis": False, "right_parenthesis": False}],
        "sort_fields": [{"query_field_id": 597, "sort_order": "Ascending"}],
        "type_id": 18, "sql_generation_mode": "Export",
        "gift_processing_options": {"soft_credit_option": "Recipients", "soft_credit_sub_option": "SplitEvenly",
                                    "matching_gift_credit_option": "MatchingGiftCompany",
                                    "use_gross_amount_for_covenants": False},
        "advanced_processing_options": {"use_alternate_sql_code_table_fields": False,
                                        "use_alternate_sql_multiple_attributes": False},
        "suppress_duplicates": True,
        "constituent_filters": {"include_inactive": True, "include_deceased": True, "include_no_valid_addresses": True},
        "result_layout": "MultiRow"})


def m_text(s):
    return '"' + s.replace('"', '""') + '"'


# (group, table name, folder key, navigation steps after the folder)
def leaf(key):
    return f'Folder{{[Key="{key}"]}}[Data]'


Q = []  # (group, name, folderKey, dataExpr)
con = "Constituents"
for name, key, call in [
    ("CON - Constituent (all)", "Constituent (all)", ""),
    ("CON - Constituent (all, no expansions)", "Constituent (all, no expansions)", ""),
    ("CON - Filtered - Fundraiser Active", "Constituent (filtered)", '(null, null, "Active")'),
    ("CON - Filtered - Inactive and deceased", "Constituent (filtered)", "(null, null, null, true, true)"),
    ("CON - Filtered - Major Donor", "Constituent (filtered)", '("Major Donor")'),
    ("CON - By list", "Constituent (by list)", f'("{LIST_ID}")'),
    ("CON - Actions", "Constituent action", ""),
    ("CON - Action fundraisers", "Constituent action fundraisers", ""),
    ("CON - Addresses", "Constituent addresses", ""),
    ("CON - Codes", "Constituent codes", ""),
    ("CON - Custom fields", "Constituent custom fields", ""),
    ("CON - Emails", "Constituent emails", ""),
    ("CON - Phones", "Constituent phones", ""),
    ("CON - Notes", "Constituent notes", ""),
    ("CON - Relationships", "Constituent relationships", ""),
    ("CON - Consents", "Constituent consents", ""),
    ("CON - Education", "Constituent education", ""),
    ("CON - Membership", "Constituent membership", ""),
    ("CON - Online presence", "Constituent online presence", ""),
    ("CON - Code types", "Constituent code types", ""),
    ("CON - Custom field categories", "Constituent custom field categories", ""),
]:
    Q.append(("Constituents", name, con, leaf(key) + call))
Q.append(("Constituents", "CON - Public list (2 People)", con,
          f'Folder{{[Key="Constituents_PublicLists"]}}[Data]{{[Key="{LIST_ID}"]}}[Data]'))
Q.append(("Constituents", "CON - My Private Lists (folder)", con,
          'Table.RemoveColumns(Folder{[Key="Constituents_MyPrivateLists"]}[Data], {"Data"})'))

for name, key in [("GFT - Gift", "Gift"), ("GFT - Gift splits", "Gift splits"),
                  ("GFT - Gift soft credits", "Gift soft credits"), ("GFT - Gift payments", "Gift payments"),
                  ("GFT - Gift custom fields", "Gift custom fields"), ("GFT - Gift batch", "Gift batch"),
                  ("GFT - Gift fundraisers", "Gift fundraisers"), ("GFT - Gift receipts", "Gift receipts")]:
    Q.append(("Gifts", name, "Gifts", leaf(key)))
Q.append(("Gifts", "GFT - Public list (Small Set of Gifts)", "Gifts",
          f'Folder{{[Key="Gifts_PublicLists"]}}[Data]{{[Key="{GIFT_LIST_ID}"]}}[Data]'))
Q.append(("Gifts", "GFT - My Private Lists (folder)", "Gifts",
          'Table.RemoveColumns(Folder{[Key="Gifts_MyPrivateLists"]}[Data], {"Data"})'))

for name, key in [("FND - Appeal", "Appeal"), ("FND - Campaign", "Campaign"), ("FND - Fund", "Fund"),
                  ("FND - Appeal packages", "Appeal packages")]:
    Q.append(("Fundraising", name, "Fundraising", leaf(key)))

for name, key in [("OPP - Opportunity", "Opportunity"), ("OPP - Opportunity fundraisers", "Opportunity fundraisers"),
                  ("OPP - Opportunity linked gifts", "Opportunity linked gifts")]:
    Q.append(("Opportunities", name, "Opportunities", leaf(key)))

Q.append(("Events", "EVT - Event", "Events", leaf("Event")))
Q.append(("Events", "EVT - Participants by event ID", "Events", leaf("Event participants (by event ID)") + f'("{EVENT_ID}")'))
Q.append(("Lists", "LST - Constituent lists", "Lists", leaf("Constituent Lists")))

# RE Query. Query by ID args: queryId, tz, static, longDesc, askFields, preview, language, formattingMode, sqlGenerationMode
byid = leaf("queryById")
Q += [
    ("RE Query", "QRY - By ID - defaults", "RaisersEdgeNXTQuery", f"{byid}({RE_QUERY_ID})"),
    ("RE Query", "QRY - By ID - en-GB", "RaisersEdgeNXTQuery", f'{byid}({RE_QUERY_ID}, null, null, null, null, null, "en-GB")'),
    ("RE Query", "QRY - By ID - en-CA None", "RaisersEdgeNXTQuery", f'{byid}({RE_QUERY_ID}, null, null, null, null, null, "en-CA", "None")'),
    ("RE Query", "QRY - By ID - SQL Export", "RaisersEdgeNXTQuery", f'{byid}({RE_QUERY_ID}, null, null, null, null, null, null, null, "Export")'),
    # Ad hoc args: definition, tz, static, longDesc, preview, language, formattingMode
    ("RE Query", "QRY - Ad hoc - defaults", "RaisersEdgeNXTQuery", f'{leaf("adHocQuery")}({m_text(adhoc("1/1/2024", "1/31/2024"))})'),
    ("RE Query", "QRY - Ad hoc - en-GB", "RaisersEdgeNXTQuery", f'{leaf("adHocQuery")}({m_text(adhoc("01/01/2024", "31/01/2024"))}, null, null, null, null, "en-GB")'),
    ("RE Query", "QRY - Browse - All queries 202", "RaisersEdgeNXTQuery", f'Folder{{[Key="allQueries"]}}[Data]{{[Key={RE_QUERY_ID}]}}[Data]()'),
]

for name, key in [("GL - Account", "Account"), ("GL - Project", "Project"),
                  ("GL - Transaction code list", "Transaction code list"), ("GL - Budget scenario list", "Budget scenario list")]:
    Q.append(("General Ledger", name, "General Ledger", leaf(key)))
Q.append(("FE Query", "FEQ - By ID - General Ledger", "FinancialEdgeNXTQuery", f'{leaf("queryById")}({FE_QUERY_ID}, "General Ledger")'))

GROUPS = []
for g, *_ in Q:
    if g not in GROUPS:
        GROUPS.append(g)


def tag():
    return str(uuid.uuid4())


def q(name):
    return "'" + name.replace("'", "''") + "'"


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


# --- semantic model ---
SCHEMA = "https://developer.microsoft.com/json-schemas/fabric"
THEME_SRC = sys.argv[2]   # Fluent2-CY26SU10.json taken from a Desktop-saved blank PBIP
THEME = os.path.splitext(os.path.basename(THEME_SRC))[0]


def platform(kind):
    return json.dumps({"$schema": f"{SCHEMA}/gitIntegration/platformProperties/2.0.0/schema.json",
                       "metadata": {"type": kind, "displayName": NAME},
                       "config": {"version": "2.0", "logicalId": tag()}}, indent=2) + "\n"


write(os.path.join(SM, ".platform"), platform("SemanticModel"))
write(os.path.join(SM, "definition.pbism"), json.dumps({
    "$schema": f"{SCHEMA}/item/semanticModel/definitionProperties/1.0.0/schema.json",
    "version": "4.2", "settings": {}}, indent=2) + "\n")
# relationship autodetection off: 44 unrelated API tables make "Detecting relationships" crawl
write(os.path.join(SM, ".pbi", "editorSettings.json"), json.dumps({
    "$schema": f"{SCHEMA}/item/semanticModel/editorSettings/1.0.0/schema.json",
    "autodetectRelationships": False, "relationshipImportEnabled": False, "relationshipRefreshEnabled": False,
    "parallelQueryLoading": True, "typeDetectionEnabled": True,
    "shouldNotifyUserOfNameConflictResolution": True}, indent=2) + "\n")
write(os.path.join(SM, "definition", "database.tmdl"), "database\n\tcompatibilityLevel: 1606\n\n")

order = [n for _, n, *_ in Q] + ["Smoke Test"]
model = ["model Model", "\tculture: en-US", "\tdefaultPowerBIDataSourceVersion: powerBI_V3",
         "\tsourceQueryCulture: en-GB", "\tdataAccessOptions", "\t\tlegacyRedirects", "\t\treturnErrorValuesAsNull", "",
         f"\tannotation PBI_QueryOrder = {json.dumps(order)}", "", "\tannotation __PBI_TimeIntelligenceEnabled = 0", ""]
for i, g in enumerate(GROUPS):
    model += [f"queryGroup {q(g)}", "", f"\tannotation PBI_QueryGroupOrder = {i}", ""]
write(os.path.join(SM, "definition", "model.tmdl"), "\n".join(model) + "\n")

for group, name, folder, expr in Q:
    m = ["let",
         "    Source = Blackbaud.Contents(),",
         f'    Folder = Source{{[Key="{folder}"]}}[Data],',
         f"    Data = {expr}",
         "in",
         "    Data"]
    lines = [f"table {q(name)}", f"\tlineageTag: {tag()}", "",
             f"\tpartition {q(name)} = m", "\t\tmode: import", f"\t\tqueryGroup: {q(group)}", "\t\tsource ="]
    lines += ["\t\t\t\t" + l for l in m]
    lines += ["", "\tannotation PBI_ResultType = Table", ""]
    write(os.path.join(SM, "definition", "tables", f"{name}.tmdl"), "\n".join(lines) + "\n")

rows = ",\n".join(f'    ROW("Query", "{n}", "Rows", COUNTROWS({q(n)}))' for _, n, *_ in Q)
dax = ["VAR t =", "  UNION(", rows, "  )", "RETURN",
       '  ADDCOLUMNS(t, "Status", IF(ISBLANK([Rows]) || [Rows] = 0, "CHECK", "OK"))']
dax = "\n".join(dax).split("\n")
smoke = ["table 'Smoke Test'", f"\tlineageTag: {tag()}", ""]
for col, dt, extra in [("Query", "string", []), ("Rows", "int64", ["\t\tformatString: #,0"]), ("Status", "string", [])]:
    smoke += [f"\tcolumn {col}", f"\t\tdataType: {dt}"] + extra + ["\t\tisNameInferred", f"\t\tlineageTag: {tag()}",
              "\t\tsummarizeBy: none", f"\t\tsourceColumn: [{col}]", "", "\t\tannotation SummarizationSetBy = Automatic", ""]
smoke += ["\tpartition 'Smoke Test' = calculated", "\t\tmode: import", "\t\tsource ="]
smoke += ["\t\t\t\t" + l for l in dax]
smoke += ["", "\tannotation PBI_Id = " + uuid.uuid4().hex, ""]
write(os.path.join(SM, "definition", "tables", "Smoke Test.tmdl"), "\n".join(smoke) + "\n")

# --- report (PBIR, matching what Desktop 2.159 writes) ---
write(os.path.join(RP, ".platform"), platform("Report"))
write(os.path.join(RP, "definition.pbir"), json.dumps({
    "$schema": f"{SCHEMA}/item/report/definitionProperties/2.0.0/schema.json",
    "version": "4.0", "datasetReference": {"byPath": {"path": f"../{NAME}.SemanticModel"}}}, indent=2) + "\n")
RD = os.path.join(RP, "definition")
write(os.path.join(RD, "version.json"), json.dumps({
    "$schema": f"{SCHEMA}/item/report/definition/versionMetadata/1.0.0/schema.json", "version": "2.0.0"}, indent=2) + "\n")
write(os.path.join(RD, "report.json"), json.dumps({
    "$schema": f"{SCHEMA}/item/report/definition/report/3.3.0/schema.json",
    "themeCollection": {"baseTheme": {"name": THEME, "reportVersionAtImport": {"visual": "2.14.0", "report": "3.4.0", "page": "2.3.1"},
                                      "type": "SharedResources"}},
    "objects": {"section": [{"properties": {"verticalAlignment": {"expr": {"Literal": {"Value": "'Top'"}}}}}]},
    "resourcePackages": [{"name": "SharedResources", "type": "SharedResources",
                          "items": [{"name": THEME, "path": f"BaseThemes/{THEME}.json", "type": "BaseTheme"}]}],
    "settings": {"useStylableVisualContainerHeader": True, "exportDataMode": "AllowSummarized",
                 "defaultDrillFilterOtherVisuals": True, "allowChangeFilterTypes": True,
                 "useEnhancedTooltips": True, "useDefaultAggregateDisplayName": True}}, indent=2) + "\n")
theme_dst = os.path.join(RP, "StaticResources", "SharedResources", "BaseThemes", f"{THEME}.json")
os.makedirs(os.path.dirname(theme_dst), exist_ok=True)
with open(THEME_SRC, "rb") as s, open(theme_dst, "wb") as d:
    d.write(s.read())

PAGE = "smoketest"
write(os.path.join(RD, "pages", "pages.json"), json.dumps({
    "$schema": f"{SCHEMA}/item/report/definition/pagesMetadata/1.1.0/schema.json",
    "pageOrder": [PAGE], "activePageName": PAGE}, indent=2) + "\n")
write(os.path.join(RD, "pages", PAGE, "page.json"), json.dumps({
    "$schema": f"{SCHEMA}/item/report/definition/page/2.1.0/schema.json",
    "name": PAGE, "displayName": "Smoke test", "displayOption": "FitToPage", "height": 1080, "width": 1920}, indent=2) + "\n")


def proj(p):
    return {"field": {"Column": {"Expression": {"SourceRef": {"Entity": "Smoke Test"}}, "Property": p}},
            "queryRef": f"Smoke Test.{p}", "nativeQueryRef": p}


write(os.path.join(RD, "pages", PAGE, "visuals", "smoketable", "visual.json"), json.dumps({
    "$schema": f"{SCHEMA}/item/report/definition/visualContainer/2.4.0/schema.json",
    "name": "smoketable",
    "position": {"x": 40, "y": 40, "z": 0, "height": 1000, "width": 1200, "tabOrder": 0},
    "visual": {"visualType": "tableEx",
               "query": {"queryState": {"Values": {"projections": [proj(p) for p in ("Query", "Rows", "Status")]}}},
               "drillFilterOtherVisuals": True}}, indent=2) + "\n")

# --- project file + gitignore ---
write(os.path.join(OUT, f"{NAME}.pbip"), json.dumps({
    "$schema": f"{SCHEMA}/pbip/pbipProperties/1.0.0/schema.json",
    "version": "1.0", "artifacts": [{"report": {"path": f"{NAME}.Report"}}],
    "settings": {"enableAutoRecovery": True}}, indent=2) + "\n")
write(os.path.join(OUT, ".gitignore"), "**/.pbi/localSettings.json\n**/.pbi/cache.abf\n")
print(f"{len(Q)} queries written to {OUT}")
