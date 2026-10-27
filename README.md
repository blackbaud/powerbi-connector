# powerbi-connector

This repo contains the code needed to create a Power Query and Power BI custom connector for SKY API, as well as the instructions to build and enable it.  Many thanks to [Grant Quick](https://github.com/GrantQuick) for the initial creation of this custom connector.

## Watch a demo

Learn how to create your own custom Power BI Connector for your Blackbaud data.

**Demo**: [Implementing the Blackbaud Custom Connector in Power BI](https://www.youtube.com/watch?v=BUaP0mlDy9s) by Sentinel Consulting

## Getting started

Follow the [SKY Developer Getting Started guide](https://developer.blackbaud.com/skyapi/docs/getting-started) to make sure you have the following:

- a SKY Developer account
- a SKY Developer subscription, and
- a registered application.

### Redirect URI
For the **Create an application** step, you need to add `https://oauth.powerbi.com/views/oauthredirect.html` as a redirect URI. To add a redirect URI, after you create the application, open it from the My applications page. In the **Redirect URI** tile, select **Edit.**

### Scopes
After creating the Power BI application in the SKY Developer Portal, open the application record page. From the Settings tab, in the **Scopes** tile, edit the application's scope and select **Limited data access**. Then, select the **Read** scope for Financial Edge NXT and Raiser’s Edge NXT. 

Then, navigate to the Marketplace. If you've already connected your application to your Blackbaud environment, accept the changes. You can approve scope changes in the Marketplace from the Manage tab. In the Scope updates tile, for the Power BI Connector app, select **Review scopes**. Then, select **Approve**.

## Installation

### Step 1 - Create

#### Option 1 - Manual (for those unfamiliar with Visual Studio)

1. Clone or download this repo locally. 
2. Open the Blackbaud directory. 
3. Update the `client_id.txt` and `client_secret.txt` files with values from [the application](https://developer.blackbaud.com/apps/) you registered in the Getting Started section. 
4. Update the `subscription_key.txt` file with the value from [SKY Developer Subscriptions](https://developer.blackbaud.com/subscriptions/). 
5. Zip the contents of the Blackbaud directory in order to create a `Blackbaud.zip` file. 
6. Rename `Blackbaud.zip` to `Blackbaud.mez`. 
7. Verify that the `[Documents]\Power BI Desktop\Custom Connectors` directory exists. 
8. Copy the `Blackbaud.mez` file to the `[Documents]\Power BI Desktop\Custom Connectors` directory. 

#### Option 2 - Using Visual Studio

1. Clone or download this repo locally.
2. Install the [Power Query SDK](https://marketplace.visualstudio.com/items?itemName=Dakahn.PowerQuerySDK).
3. Open the `Blackbaud.sln` file.
4. Update the `client_id.txt` and `client_secret.txt` files with values from the [application](https://developer.blackbaud.com/apps/) you registered in the Getting Started section.
5. Update the `subscription_key.txt` file with the value from [SKY Developer Subscriptions](https://developer.blackbaud.com/subscriptions/).
6. Build the solution and use the included extension to place the `Blackbaud.mez` file to the `[My Documents]\Microsoft Power BI Desktop\Custom Connectors` directory.

### Step 2 - Enable in Power BI Desktop

1. To enable use of uncertified custom data connectors, as of the July 2018 release, Power BI additionally alerts users to change their security settings. To do this, go to **File**, **Options and settings**, **Security** and under **Data Extensions**, enable **(Not Recommended) Allow any extension to load without validation or warning**. 
2. Restart Power BI Desktop

## Using the custom connector

In Power BI Desktop, select **Get Data**, **Other**, then search for and select **Blackbaud**.

### Authorization

The first time you use the connector, you need to authorize the app to work with your data. To authorize, log in with your Blackbaud account.

### Get Data entries: tables vs. functions

Broadly, the connector's Navigator entries fall into two categories:

- **Fixed tables** — entries like **Constituent (all)**, **Gift**, and **Event** that load directly with no extra input required. These also preview quickly in Power Query's Navigator and query editor, so they're generally the most performant option whenever the data you need is already covered by one.
- **Function-based entries** — entries like **Constituent (filtered)** and **Event participants (by event ID)** that require you to supply one or more parameters (for example, a constituent code, or an event ID) before they'll return data. The Query folders described below are also function-based: **Query by ID** and **Ad hoc query** each need at least a query ID or query definition to run.

### A note on working with function-based entries

Power Query re-evaluates every step of a query from scratch whenever you add or change a step while building a report — this is standard Power Query behavior for any data source, not something specific to this connector. It's barely noticeable for fixed tables, but for function-based entries — and especially the Query feature below, which starts a job on the Query API and polls until it completes — every edit you make while shaping your report re-runs that whole call again, which can make report-building noticeably slow.

### Using the Query feature

In addition to the object-based tables under Constituents, Gifts, etc., the Navigator includes two Query folders — **Query - Raiser's Edge NXT** and **Query - Financial Edge NXT** — which run queries from Query in Raiser's Edge NXT and Financial Edge NXT (web view) respectively, directly from Power BI.

#### Browsing saved queries

Each Query folder lets you browse your existing saved queries the same way you already organize them in Raiser's Edge NXT / Financial Edge NXT: **All queries**, **My queries**, **Favorites**, **Merged queries**, **Categories**, **Types**, **Format** (Dynamic/Static), and **Result Layout** (Multi-row/Single-row). Selecting a saved query runs it and loads the results as a table.

For Financial Edge NXT, queries are also organized by **Module** (General Ledger, Accounts Payable, Accounts Receivable, Fixed Assets, Cash Receipts) — open the module folder that matches where the query is filed to browse it.

#### Running a query directly

Each Query folder also has two functions for running a query without browsing to it first:

- **Query by ID** — runs a saved query by its numeric ID (entered in the **Query ID** box).
- **Ad hoc query** — runs a query definition you supply as JSON yourself (in the **Adhoc Query JSON** box), without it needing to be saved first.

**Paste the definition as a single line.** The **Adhoc Query JSON** box keeps only the first line of whatever you paste, so formatted JSON — such as the JSON you can copy from a query in the web view — gets cut off after its opening `{`, and the connector reports that the JSON looks incomplete. Minify the JSON first (any "JSON minify" tool will do) so the whole definition is on one line.

**Set Locale to match where the JSON came from.** JSON copied from Query in the web view writes filter dates in your browser's date format — a UK browser gives `01/07/2017` for 1 July 2017. Ad hoc query reads those dates using its **Locale** parameter, which defaults to `en-US`, so a UK definition run with the default would treat that date as 7 January. Set **Locale** to match your browser language (for example `en-GB`) when running JSON copied from the web view.

**A note on quoting:** if you copy an ad hoc definition out of Power Query M code, it will have doubled quotes (`""name""`) — that's M's own string escaping, not part of the JSON. When pasting into the parameter box, those need to be single quotes (`"name"`). The connector will tell you if the JSON can't be parsed.

For Financial Edge NXT, both of these also require a **Module** parameter, since Financial Edge has no single "all modules" option.

#### Other query parameters

- **Timezone Offset (minutes)** — the offset applied to date/time fields in the results. Defaults to your local machine's offset if left blank.
- **Use static query?** — whether to lock the query to the constituent list it matched when last run in Raiser's/Financial Edge NXT, rather than re-evaluating its filters live.
- **Display code table long descriptions?** — whether to return the long description for code table values instead of the short code.
- **Ask fields** — only applicable to queries with "Ask at runtime" filter fields; supply their values as JSON.
- **Locale** — the date and number format of the results; the data itself is unchanged. Leaving it blank (null) uses `en-US` (`8/15/2014`). Other options: `en-GB` (`15/08/2014`), `en-CA` (`2014-08-15`), `en-AU` (`15/8/2014`), `en-NZ` (`15/08/2014`), `fr-CA` (`2014-08-15`, amounts as `10 000,00 $`) and `de-DE` (`15.08.2014`, amounts as `10.000,00 $`). The currency symbol follows your environment's currency setting, not the locale. On **Ad hoc query**, the locale also controls how filter dates inside the definition are read — see *Set Locale to match where the JSON came from* above.
- **Formatting mode** — blank (null) uses `UI`. `UI` and `Export` return formatted values: amounts with currency symbols and separators, dates without a time. `None` returns raw amounts (`10000`) and dates with a time part, but **birth dates come back encrypted**.
- **SQL generation mode** (saved queries only) — blank (null) uses `Query`. `Query` returns the output fields plus a `QRECID` column; `Export` returns the output fields only; `Report` returns only `QRECID`, one row per record.

#### ⚠️ Preview data: for building reports, not for production

This is exactly the scenario the **Preview data** parameter exists for. When set to `true`, the connector returns results as soon as the query *starts* running rather than waiting for it to fully finish — so each step you add while building your report doesn't have to sit through a full run of a potentially long query job.

**This trades away completeness.** With Preview data enabled, you may get back a partial result set — a snapshot of whatever the query had processed at the moment the connector grabbed it — not the full, finished output the query would otherwise produce.

**Before publishing a report or setting up scheduled refresh, set Preview data to `false` (or simply leave it out — `false` is the default).** Leaving it `true` in production risks a report silently showing incomplete data on every refresh, with no error to indicate anything is wrong.

## Scheduled refresh on Power BI service

The connector supports scheduled refresh through the Power BI service via a Power BI On-Premises Data Gateway (Standard mode). In order to take advantage of this, the following steps need to be performed by an IT administrator at your organization.

### Step 1 – Set up the data gateway

1. Install the Power BI On-Premises Data Gateway in Standard mode. To learn how, see the [On-premises data gateway - Power BI documentation](https://learn.microsoft.com/en-us/power-bi/connect-data/service-gateway-onprem) from Microsoft Learn.
2. Select **Sign in**.
3. Select **Register a new gateway on this computer.**
4. Give the new gateway a name.
5. Provide and confirm a recovery key. **Note:** This key <ins>cannot be restored or changed if lost</ins>. Save it carefully! 

### Step 2 - Set up the service account 

Under the Service Settings, the Gateway Service Account is defaulted to running as `NT SERVICE\PBIEgwService`. There are two options to ensure the Service Account can access the Power BI Custom Connectors: 

1. Add `NT SERVICE\PBIEgwService` to the folder permissions where the Custom Connector (.mez file) is saved, as detailed in the following step.
2. Change the user listed as the service account to a local user (this will require restarting the gateway).

### Step 3 - Connect the custom connector 

For Power BI Service to connect to the custom connector, the `.mez` file must be saved locally on the machine hosting the data gateway and must be accessible by the gateway's service account. The file path is typically `…\Documents\Power BI Desktop\Custom Connectors`. It is critical that the gateway's service account has access to the folder path for custom connectors. If you are using the default gateway service account `NT SERVICE\PBIEgwService`, verify that the machine hosting the gateway lists `PBIEgwService` under **Security > Group or user names**. An accessible path for this service account might look like: `C:\Windows\ServiceProfiles\PBIEgwService\Documents\Power BI Desktop\Custom Connectors`.

After you map the custom connectors folder path in the data gateway setup, you should see Blackbaud appear in the custom connector list on the **Connectors** screen of the gateway setup.

### Step 4 – Set up the gateway in Power BI Service 

1. From the Power BI Service home page, navgiate to **Settings**, **Manage Connections and Gateways**. 
2. Select the **On-premises date gateways** tab. 
3. Select your new gateway and select the ellipses (…) to the right of the name. Then, select **Settings**. 
  a. Ensure these options within the Power BI field are selected. This will allow other users in your tenant to access the gateway:
    - Allow user’s cloud data sources to refresh through this gateway cluster.
    - Allow user’s custom data connectors to refresh through this gateway cluster.
  b. Select **Save**. 

**Optional**: Also from the ellipses, select **Manage users** to add report developers who will need to publish reports and connect their data sets to this gateway. 

### Step 5 – Upload a report and connect to the gateway 

1. Publish a Power BI report that uses your connector (from Step #3) to https://app.powerbi.com/.
2. Open https://app.powerbi.com and navigate to the Workspace where you published the report. You will find a Report and a Semantic model were published. From the ellipses (…) next to the Semantic model, select **Settings**.
3. From the Semantic models tab, expand the **Gateway and cloud connections** field.
4. Locate your data gateway and select the ▼ icon next to the Settings gear under **Actions**.
5. Select **Manually add to gateway**. This will open an interface to add a new data source.  
6. Provide a connection name. This will represent the connector and the environment you authenticate, such as "Blackbaud-SkyDevCort" or "Blackbaud-Prod." When you upload new reports that use the same connector to authenticate to the same environment, you will make sure that the Semantic model Settings refer to the same connection on the gateway.
7. Set the authentication type to "Connection" and provide your credentials.
8. Set the privacy level to "Organizational".
9. Navigate back to the Semantic model Settings and you can now map to the gateway connection you just set up.
10. Select **Apply**.

### Step 6 – Schedule refresh 

Configure a scheduled refresh using the gateway. To learn how. see the [Configure scheduled refresh - Power BI documentation](https://learn.microsoft.com/en-us/power-bi/connect-data/refresh-scheduled-refresh) from Microsoft Learn. 

**Note:** You only see a gateway available if your account has been added as a user of the gateway. Your administrator may need to add you.

## Help / More information

For any questions and feedback related to this custom connector, check out the [Blackbaud Community - SKY Developer category](https://community.blackbaud.com/categories/sky-developer-425).

## Known issues

- Power BI throws an error when attempting to use the Membership List functionality if the corresponding environment does not have the Membership Module enabled.
- Power BI throws an error when attempting to use the Event List functionality if the corresponding environment does not have the Event Module enabled.
