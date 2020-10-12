# powerbi-connector

This repo contains the code needed to create a Power Query and Power BI custom connector for SKY API, as well as the instructions to build and enable it.  Many thanks to [Grant Quick](https://github.com/GrantQuick) for the initial creation of this custom connector.

## Getting started

Follow the [SKY Developer Getting Started guide](https://developer.blackbaud.com/skyapi/docs/getting-started) to make sure you have the following:

- a SKY Developer account
- a SKY Developer subscription, and
- a registered application.

For the **Create an application** step, you need to add `https://oauth.powerbi.com/views/oauthredirect.html` as a redirect URI. To add a redirect URI, after you create the application, open it from the My applications page. In the **Redirect URI** tile, select **Edit.**

For Power BI to access data from your instance of Raiser's Edge NXT or Financial Edge NXT, your registered application must be [connected to your Blackbaud environment](https://developer.blackbaud.com/skyapi/docs/applications/createapp#connect-your-app).

## Installation

### Step 1 - Create

#### Option 1 - Using Visual Studio

1. Clone or download this repo locally.
2. Install the [Power Query SDK](https://marketplace.visualstudio.com/items?itemName=Dakahn.PowerQuerySDK).
3. Open the `Blackbaud.sln` file.
4. Update the `client_id.txt` and `client_secret.txt` files with values from the [application](https://developer.blackbaud.com/apps/) you registered in the Getting Started section.
5. Update the `subscription_key.txt` file with the value from [SKY Developer Subscriptions](https://developer.blackbaud.com/subscriptions/).
6. Build the solution and use the included extension to place the `Blackbaud.mez` file to the `[My Documents]\Microsoft Power BI Desktop\Custom Connectors` directory.

#### Option 2 - Manual

1. Clone or download this repo locally.
2. Navigate to the cloned repo or unzip the downloaded file.
3. Open the `Blackbaud` directory.
4. Update the `client_id.txt` and `client_secret.txt` files with values from the [application](https://developer.blackbaud.com/apps/) you registered in the Getting Started section.
5. Update the `subscription_key.txt` file with the value from [SKY Developer Subscriptions](https://developer.blackbaud.com/subscriptions/).
6. Zip the contents of the `Blackbaud` directory in order to create a `Blackbaud.zip` file.
7. Rename `Blackbaud.zip` to `Blackbaud.mez`.
8. Ensure the `[Documents]\Power BI Desktop\Custom Connectors` directory exists.
9. Copy the `Blackbaud.mez` file to the `[Documents]\Power BI Desktop\Custom Connectors` directory.

### Step 2 - Enable

1. In Power BI Desktop (under **File, Options and settings, Custom data connectors**), enable the **Custom data connectors** preview feature.
2. To enable use of uncertified custom data connectors, as of the July 2018 release, Power BI additionally alerts users to change their securitys ettings. To do this, go to **File, Options and settings, Security** and under **Data Extensions**, enable **(Not Recommended) Allow any extension to load without validation or warning**.
3. Restart Power BI Desktop
4. In Power BI Desktop, select **Get Data, Other, Blackbaud**
5. The first time you use the connector, you need to authorize the app to work with your data.  To authorize, log in with your Blackbaud account.

## Scheduled refresh

The connector supports scheduled refresh through the Power BI service via a Power BI On-Premises Data Gateway (Personal mode). In order to take advantage of this, the following steps need to be performed.

1. Install the Power BI On-Premises Data Gateway in Personal mode.
2. [Enable Custom Connector support in the Gateway](https://docs.microsoft.com/en-us/power-query/samples/trippin/9-testconnection/readme#enabling-custom-connectors-in-the-personal-gateway).
3. Publish a workbook that uses your connector to PowerBI.com.
4. [Configure scheduled refresh](https://docs.microsoft.com/en-us/power-query/samples/trippin/9-testconnection/readme#testing-scheduled-refresh) and follow the instructions from **After publishing, go to PowerBI.com and find the dataset...**.

## Help / More information

For any questions and feedback related to this custom connector, use the [Blackbaud Community - Microsoft Connectors category](https://community.blackbaud.com/forums/viewcategory/586).

## Known issues

Power BI throws an error when attempting to use the Membership List functionality if the corresponding environment does not have the Membership Module enabled.
