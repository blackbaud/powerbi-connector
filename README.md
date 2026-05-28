# powerbi-connector

This repo contains Power Query and Power BI custom connectors for Blackbaud SKY API. Two connectors are available — **Blackbaud** and **Blackbaud RENXT Query** — and you can install one or both. Many thanks to [Grant Quick](https://github.com/GrantQuick) for the initial creation of this custom connector.

## Watch a demo

Learn how to create your own custom connectors to your Blackbaud data.

**Demo**: [Implementing the Blackbaud Custom Connector in Power BI](https://www.youtube.com/watch?v=BUaP0mlDy9s) by Sentinel Consulting

This walkthrough demonstrates how to set up the Blackbaud connector. Note the .zip file you download will also include a folder for the Blackbaud RENXT Query connector. Each folder contains all of the source code for one connector. You can walk through the demonstrated steps for each folder's content if you want to install both custom connectors.

## Getting started

Follow the [SKY Developer Getting Started guide](https://developer.blackbaud.com/skyapi/docs/getting-started) to make sure you have the following:

- a SKY Developer account
- a SKY Developer subscription, and
- a registered application.

### Redirect URI

For the **Create an application** step, you need to add `https://oauth.powerbi.com/views/oauthredirect.html` as a redirect URI. To add a redirect URI, after you create the application, open it from the My applications page. In the **Redirect URI** tile, select **Edit**.

### Scopes

After creating the application in the SKY Developer Portal, open the application record page. From the Settings tab, in the **Scopes** tile, edit the application's scope and select **Limited data access**. Then, select the **Read** scope:

- **Blackbaud connector**: Financial Edge NXT and Raiser's Edge NXT
- **Blackbaud RENXT Query connector**: Raiser's Edge NXT

Then, navigate to the Marketplace. If you've already connected your application to your Blackbaud environment, accept the changes. You can approve scope changes in the Marketplace from the Manage tab. In the Scope updates tile, for the Power BI Connector app, select **Review scopes**. Then, select **Approve**.

## Installation

### Step 1 – Create

The repo contains two connector folders: `Blackbaud` and `RENXTQuery`. Follow these steps for each connector you want to install.

1. Clone or download this repo locally.
2. Open the connector folder (`Blackbaud` or `RENXTQuery`).
3. Update the credentials files with values from [the application](https://developer.blackbaud.com/apps/) you registered in the Getting Started section, and the subscription key from [SKY Developer Subscriptions](https://developer.blackbaud.com/subscriptions/).
   - **Blackbaud**: `client_id.txt`, `client_secret.txt`, `subscription_key.txt`
   - **Blackbaud RENXT Query**: `keys_client_id.txt`, `keys_client_secret.txt`, `keys_subscription_key.txt`
4. Zip the contents of the connector folder to create a `.zip` file (`Blackbaud.zip` or `RENXTQuery.zip`).
5. Rename the `.zip` file to `.mez` (`Blackbaud.mez` or `RENXTQuery.mez`).
6. Verify that the `[Documents]\Power BI Desktop\Custom Connectors` directory exists.
7. Copy the `.mez` file to the `[Documents]\Power BI Desktop\Custom Connectors` directory.

### Step 2 – Enable in Power BI Desktop

1. Go to **File**, **Options and settings**, **Security** and under **Data Extensions**, enable **(Not Recommended) Allow any extension to load without validation or warning**.
2. Restart Power BI Desktop.
3. In Power BI Desktop, select **Get Data**, **Other**, then select your connector (**Blackbaud** or **Blackbaud RENXT Query**).
4. The first time you use the connector, you need to authorize the app to work with your data. Log in with your Blackbaud account.

## Scheduled refresh on Power BI service

The connectors support scheduled refresh through the Power BI service via a Power BI On-Premises Data Gateway (Standard mode). In order to take advantage of this, the following steps need to be performed by an IT administrator at your organization.

### Step 1 – Set up the data gateway

1. Install the Power BI On-Premises Data Gateway in Standard mode. To learn how, see the [On-premises data gateway - Power BI documentation](https://learn.microsoft.com/en-us/power-bi/connect-data/service-gateway-onprem) from Microsoft Learn.
2. Select **Sign in**.
3. Select **Register a new gateway on this computer.**
4. Give the new gateway a name.
5. Provide and confirm a recovery key. **Note:** This key <ins>cannot be restored or changed if lost</ins>. Save it carefully!

### Step 2 – Set up the service account

Under the Service Settings, the Gateway Service Account is defaulted to running as `NT SERVICE\PBIEgwService`. There are two options to ensure the Service Account can access the Power BI Custom Connectors:

1. Add `NT SERVICE\PBIEgwService` to the folder permissions where the Custom Connector (.mez file) is saved, as detailed in the following step.
2. Change the user listed as the service account to a local user (this will require restarting the gateway).

### Step 3 – Connect the custom connector

For Power BI Service to connect to the custom connector, the `.mez` file must be saved locally on the machine hosting the data gateway. The file path is typically `…\Documents\Power BI Desktop\Custom Connectors`. If you chose to use the `NT SERVICE\PBIEgwService` account in the last step, this path might look like: `C:\Windows\ServiceProfiles\PBIEgwService\Documents\Power BI Desktop\Custom Connectors`. It is critical that the gateway's service account has access to the folder path for custom connectors. If you are using the default gateway service account `NT SERVICE\PBIEgwService`, verify that the machine hosting the gateway lists `PBIEgwService` under **Security > Group or user names**.

After you map the custom connectors folder path in the data gateway setup, you should see your connector(s) (**Blackbaud** and/or **Blackbaud RENXT Query**) appear in the custom connector list on the **Connectors** screen of the gateway setup.

### Step 4 – Set up the gateway in Power BI Service

1. From the Power BI Service home page, navigate to **Settings**, **Manage Connections and Gateways**.
2. Select the **On-premises data gateways** tab.
3. Select your new gateway and select the ellipses (…) to the right of the name. Then, select **Settings**.
   - Ensure the options within the Power BI field are selected. This will allow other users in your tenant to access the gateway:
     - Allow user's cloud data sources to refresh through this gateway cluster.
     - Allow user's custom data connectors to refresh through this gateway cluster.
   - Select **Save**.

**Optional**: Also from the ellipses, select **Manage users** to add report developers who will need to publish reports and connect their datasets to this gateway.

### Step 5 – Upload a dataset and connect to the gateway

1. Publish a workbook that uses your connector to https://app.powerbi.com/.
2. Open https://app.powerbi.com and navigate to the Workspace where you published the report. You will find a Report and a Dataset were published. From the ellipses (…) next to the dataset, select **Settings**.
3. From the Datasets tab, expand the **Gateway connection** field.
4. Select the ▼ icon directly under **Actions**.
5. Select **Manually add to gateway**. This will open an interface to add a new data source.
6. Provide a data source name to represent the connector, such as "Blackbaud" or "Blackbaud RENXT Query."
7. Set the authentication type to "OAuth2".
8. Set the privacy level to "Organizational".
9. Navigate back to the dataset settings and you can now map the connector to the data connector you set up in the previous step. Select **Apply**.

### Step 6 – Schedule refresh

Configure a scheduled refresh using the gateway. To learn how, see the [Configure scheduled refresh - Power BI documentation](https://learn.microsoft.com/en-us/power-bi/connect-data/refresh-scheduled-refresh) from Microsoft Learn.

**Note:** You only see an enterprise gateway available if your account is listed in the Users tab of the data source configured for a given gateway. Your administrator may need to add you.

## Help / More information

For any questions and feedback related to these connectors, use the [Blackbaud Community - Microsoft Power Platform category](https://community.blackbaud.com/forums/viewcategory/586).
