# powerbi-connector

This repo contains Power Query and Power BI custom connectors for Blackbaud SKY API. Two connectors are available depending on your use case.

## Which connector should I use?

| | [Blackbaud](Blackbaud/README.md) | [RENXT Query](RENXTQuery/README.md) |
|---|---|---|
| **Best for** | Broad access to SKY API data across Raiser's Edge NXT and Financial Edge NXT | Efficiently pulling large Raiser's Edge NXT datasets via saved queries |
| **Products** | Raiser's Edge NXT, Financial Edge NXT | Raiser's Edge NXT |
| **Performance** | Standard | More efficient, supports larger datasets |

If you need Financial Edge NXT data or broad access across Blackbaud products, use the **Blackbaud** connector. If you work in Raiser's Edge NXT and want more efficient access to larger datasets, use the **RENXT Query** connector.

## Connectors

### [Blackbaud](Blackbaud/README.md)
The original SKY API connector. Connects to SKY API endpoints for both Raiser's Edge NXT and Financial Edge NXT. See the [Blackbaud connector README](Blackbaud/README.md) for setup instructions.

### [RENXT Query](RENXTQuery/README.md)
A connector built on the [SKY API Query API](https://developer.sky.blackbaud.com/api#api=query). More efficient than the Blackbaud connector and supports larger datasets. See the [RENXT Query connector README](RENXTQuery/README.md) for setup instructions.

## Help / More information

For any questions and feedback related to these connectors, use the [Blackbaud Community - Microsoft Power Platform category](https://community.blackbaud.com/forums/viewcategory/586).
