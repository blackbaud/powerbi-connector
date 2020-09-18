# powerbi-connector

This repo contains the code needed for a custom connector for Power Query and Power BI as well as the instructions to build and enable it.  Many thanks to [Grant Quick](https://github.com/GrantQuick) for the initial creation of this custom connector.

## Getting Started

Follow the [SKY Developer Getting Started Guide](https://developer.blackbaud.com/skyapi/docs/getting-started) to make sure you have the following:

- SKY Developer Account
- SKY Developer Subscription
- Registered Application

When you get to the create application step, please be sure to add `https://oauth.powerbi.com/views/oauthredirect.html` as a "Redirect URI." 

## Installation

### Step 1 - Create

#### Option 1 - Using Visual Studio

1. Clone or download this repo locally.
2. Open the `Blackbaud.sln` file.
3. Update the `client_id.txt` and `client_secret.txt` files with values from the [application](https://developer.blackbaud.com/apps/) you registered in the Getting Started section.
4. Update the `subscription_key.txt` file with the value from [SKY Developer Subscriptions](https://developer.blackbaud.com/subscriptions/).
5. Build the solution and use the included extension to place the `Blackbaud.mez` file to the `[My Documents]\Microsoft Power BI Desktop\Custom Connectors` directory.

#### Option 2 - Manual

1. Clone or download this repo locally.
2. Open the `Blackbaud` directory.
3. Update the `client_id.txt` and `client_secret.txt` files with values from the [application](https://developer.blackbaud.com/apps/) you registered in the Getting Started section.
4. Update the `subscription_key.txt` file with the value from [SKY Developer Subscriptions](https://developer.blackbaud.com/subscriptions/).
5. Zip the contents of the `Blackbaud` directory in order to create a `Blackbaud.zip` file.
6. Rename `Blackbaud.zip` to `Blackbaud.mez`.
7. Ensure the `[My Documents]\Microsoft Power BI Desktop\Custom Connectors` directory exists.
8. Copy the `Blackbaud.mez` file to the `[My Documents]\Microsoft Power BI Desktop\Custom Connectors` directory.

### Step 2 - Enable

1. Enable the **Custom data connectors** preview feature in Power BI Desktop (under *File | Options and settings | Custom data connectors*).
2. As of the July 2018 release, Power BI will additionally alert users to change their security settings in order to enable uncertified custom data connectors to be used. To do this, go to *File | Options and settings | Security*, and under **Data Extensions**, enable **(Not Recommended) Allow any extension to load without validation or warning**.
3. Restart Power BI Desktop
4. In Power BI Desktop, click **Get Data > Other > Blackbaud**
5. The first time you use the connector you will need to log in using your Blackbaud account and authorise the app to work with your data.

## Scheduled Refresh

The connector supports scheduled refresh through the Power BI service via a Power BI On-Premises Data Gateway (Personal mode). In order to take advantage of this, the following steps need to be performed:

1. Install the Power BI On-Premises Data Gateway in Personal mode
2. [Enable Custom Connector support in the Gateway](https://docs.microsoft.com/en-us/power-query/samples/trippin/9-testconnection/readme#enabling-custom-connectors-in-the-personal-gateway)
3. Publish a workbook that uses your connector to PowerBI.com
4. [Configure scheduled refresh](https://docs.microsoft.com/en-us/power-query/samples/trippin/9-testconnection/readme#testing-scheduled-refresh) and follow the instructions from *After publishing, go to PowerBI.com and find the dataset...*

## Help / More Information

Please be sure to utilize the [Blackbaud Community - Microsoft Connectors category](https://community.blackbaud.com/forums/viewcategory/586) for any questions and feedback related to this custom connector.

## Known Issues

- PowerBI will throw an error when attempting to use the Membership List functionality if the corresponding environment does not have the Membership Module enabled.