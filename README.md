# powerbi-connector

This repo contains the code needed to create a Power Query and Power BI custom connector for SKY API, as well as the instructions to build and enable it.  Many thanks to [Grant Quick](https://github.com/GrantQuick) for the initial creation of this custom connector.

## Watch a demo

In this video walkthrough demo with Linton Myers, a Strategic Solutions Developer at Blackbaud, learn how to create your own custom Power BI Connector for Raiser’s Edge NXT using this repo's code.

**Demo**: [Create a Power BI Connector for Raiser’s Edge NXT](https://www.youtube.com/watch?v=wIRdN3eexCo&feature=youtu.be)

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
3. In Power BI Desktop, select **Get Data, Other, Blackbaud**
4. The first time you use the connector, you need to authorize the app to work with your data.  To authorize, log in with your Blackbaud account.

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

For Power BI Service to connect to the custom connector, the `.mez` file should be saved locally to `…\Documents\Power BI Desktop\Custom Connectors`. The Gateway Service Account must be at the head of this Documents path. 

Map the Data Gateway to the folder. You should see Blackbaud appear as an option for a custom connector. 

### Step 4 – Set up the gateway in Power BI Service 

1. From the Power BI Service home page, navgiate to **Settings**, **Manage Connections and Gateways**. 
2. Select the **On-premises date gateways** tab. 
3. Select your new gateway and select the ellipses (…) to the right of the name. Then, select **Settings**. 
  a. Ensure the options within the Power BI field are selected. This will allow other users in your tenant to access the gateway:
    - Allow user’s cloud data sources to refresh through this gateway cluster.
    - Allow user’s custom data connectors to refresh through this gateway cluster.
  b. Select **Save**. 

**Optional**: Also from the ellipses, select **Manage users** to add report developers who will need to publish reports and connect their data sets to this gateway. 

### Step 5 – Upload a data set and connect to the gateway 

1. Publish a workbook that uses your connector to https://app.powerbi.com/.
2. Open https://app.powerbi.com and navigate to the Workspace where you published the report. You will find a Report and a Data Set were published. From the ellipses (…) next to the data set, select **Settings**. 
3. From the Datasets tab, expand the **Gateway connection** field. 
4. Select the ▼ icon directly under **Actions**.
5. Select **Manually add to gateway**. This will open an interface to add a new data source.  
6. Provide a data source name to represent the Connector, such as “Blackbaud.” 
7. Set the authentication type to “OAuth2”.
8. Set the privacy level to “Organizational”.
9. Navigate back to the dataset settings and you can now map the connector to the data connector you set up in the previous step. Select **Apply**.

### Step 6 – Schedule refresh 

Configure a scheduled refresh using the gateway. To learn how. see the [Configure scheduled refresh - Power BI documentation](https://learn.microsoft.com/en-us/power-bi/connect-data/refresh-scheduled-refresh) from Microsoft Learn. 

**Note:** You only see an enterprise gateway available if your account is listed in the Users tab of the data source configured for a given gateway. Your administrator may need to add you. 

## Help / More information

For any questions and feedback related to this custom connector, use the [Blackbaud Community - Microsoft Power Platorm category](https://community.blackbaud.com/forums/viewcategory/586).

## Known issues

- Power BI throws an error when attempting to use the Membership List functionality if the corresponding environment does not have the Membership Module enabled.
- Power BI throws an error when attempting to use the Event List functionality if the corresponding environment does not have the Event Module enabled.
