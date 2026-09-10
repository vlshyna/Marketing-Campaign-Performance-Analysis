# Marketing Campaign Performance Analysis 
</br>

**Project Overview**

</br>
This project focuses on building a marketing analytics dataset that combines advertising spend, user acquisition, advertising revenue, and in-app revenue at the campaign level.
The goal is to create a unified marketing performance view that can be used to evaluate campaign profitability and identify campaigns that generate strong or weak returns.
</br>
</br>

**The project includes:**

- SQL-based data transformation and aggregation
- Data quality assessment
- Multi-source data integration
- Marketing KPI calculation
- Campaign profitability classification
- ROAS benchmarking
- Tableau dashboard development

The final output is a campaign-level marketing mart designed for further analysis and visualization.
</br>

## Business Problem 

Marketing data is often distributed across multiple sources: User acquisition / install data, Advertising cost data, Advertising revenue data, In-app purchase and subscription data. When these datasets are stored separately, it is difficult to answer basic business questions such as: 
- Which campaigns are profitable?
- Which campaigns are spending more than they generate?
- What is the return on advertising spend? 

This project addresses these questions by combining the available sources into a single campaign-level dataset.

</br>

## Data Sources

The original data consisted of four separate tables covering **June–July 2026.** For this portfolio project, the source-specific table names are represented using neutral names.

|Source	| Description |
| :--- | :--- |
|installs	| Application installs attributed to advertising campaigns |
| ad_spend	| Advertising costs by campaign |
|ad_revenue	| Revenue generated from in-app advertising |
|in_app_revenue	| Revenue from subscriptions, purchases, and related in-app events |

The data sources do not have a completely consistent campaign population, and some records contain missing campaign identifiers. These characteristics were taken into account during the data integration process. 

The four source tables are connected using: `campaign_id`

</br>

## Data Preparation 
1. **Installs.** The install dataset is aggregated by `campaign_id`. This produces the total number of attributed installs for each campaign

```sql
SELECT campaign_id, campaign_name, COUNT(*) AS installs
FROM installs
WHERE campaign_id IS NOT NULL
GROUP BY campaign_id, campaign_name;
```

2. **Advertising Spend.** Advertising costs are aggregated by `campaign_id`

```sql
SELECT campaign_id, campaign_name, SUM(cost_usd) AS spend
FROM ad_spend
WHERE campaign_id IS NOT NULL
GROUP BY campaign_id, campaign_name;
```

3. **Advertising Revenue.** Revenue generated through in-app advertising is aggregated by `campaign_id`

```sql
SELECT campaign_id, campaign_name, SUM(event_revenue_usd) AS ad_revenue
FROM ad_revenue
WHERE campaign_id IS NOT NULL
GROUP BY campaign_id, campaign_name;
```

4. **In-App Revenue.** Revenue from purchases, subscriptions, and related events is aggregated by `campaign_id`

```sql
SELECT campaign_id, campaign_name, SUM(event_revenue_usd) AS in_app_revenue
FROM in_app_revenue
WHERE campaign_id IS NOT NULL
GROUP BY campaign_id, campaign_name;
```

</br>

## Data Integration 

The aggregated datasets are combined using a `FULL OUTER JOIN` because the campaign populations are not identical across all sources. 

For example, a campaign may: 
- have advertising spend but no recorded revenue;
- generate revenue but have no corresponding install record;
- appear only in one of the available sources.

Using an `INNER JOIN` would remove such campaigns from the final dataset. A `FULL OUTER JOIN` preserves all campaigns available in any source and makes missing data visible instead of silently excluding it. 

The campaign identifier is consolidated using `COALESCE()`. The same approach is used for the campaign name.

```sql
COALESCE(
        installs.campaign_id,
        ad_spend.campaign_id,
        ad_revenue.campaign_id,
        in_app_revenue.campaign_id)
AS campaign_id
```

</br>

## Marketing Metrics

- Total Revenue = Ad Revenue + In-App Revenue
- Profit = Total Revenue - Spend
- ROAS = Total Revenue / Spend

[ROAS measures how much revenue is generated for every unit of advertising spend.](https://guildofmarketing.ua/marketyngovi-kpi-metryky-efektyvnosti-reklamy/)

</br>

## Campaign Classification

**Profit Status.** Campaigns are classified into three groups:

|Status	| Definition |
| :--- | :--- |
| Profitable	| Profit > 0 |
| Unprofitable	| Profit ≤ 0 |
| Not enough data to calculate	| Spend is missing or equal to zero |

A campaign without recorded advertising spend is not automatically considered profitable. Without a reliable cost value, revenue cannot be meaningfully compared with acquisition cost.

</br>

**ROAS Benchmark.** ROAS is grouped into the [following benchmark categories:](https://guildofmarketing.ua/marketyngovi-kpi-metryky-efektyvnosti-reklamy/)

|ROAS	| Classification |
| :--- | :--- |
| < 3	| Below the minimum acceptable level |
| = 3	| Minimum acceptable level |
| > 3 and < 8	| Good result |
| ≥ 8	| Excellent result |

These thresholds are analytical benchmarks used for dashboard segmentation rather than universal industry standards.

</br>

## Data Quality Assessment

Before building the marketing mart, the source data was checked for missing campaign identifiers and differences in campaign coverage between datasets. The following observations were identified:

| Source	| Total Rows	| Rows with Missing `campaign_id` |
| :--- | :--- | :--- | 
| installs	| 777,724	| 448,708 |
| ad_spend	| 5,253,424	| 0 |
| ad_revenue	| 5,955,170	| 351,694 |
| in_app_revenue	| 24,963	| 2,713 |

The largest data quality issue is the install dataset, where a substantial proportion of records does not contain a campaign identifier. Records without campaign_id cannot be reliably attributed to a specific advertising campaign. Therefore, they are excluded from the campaign-level marketing mart. This does not necessarily mean that the underlying install data is incorrect. It means that the available fields are insufficient to attribute those records to a particular campaign.

</br>

## Campaign Coverage

The number of unique campaigns differs between the source datasets.

| Source	| Distinct Campaigns |
| :--- | :--- |
| installs	| 54 |
| ad_spend	| 48 |
| ad_revenue	| 137 | 
| in_app_revenue	| 91 | 

The overlap between datasets is also incomplete. This confirms that the four sources represent different subsets of the overall campaign population. As a result, the final dataset intentionally preserves campaigns that exist in only one or several sources.

</br>

## Assumptions

Several assumptions were required because the source data did not include a complete data dictionary or detailed description of the relationships between the tables.

1. **`campaign_id` is the primary linking key.**

`campaign_id` was selected as the common identifier because it is the most reliable field available across the datasets. Other potential identifiers were considered, but no alternative key provided a consistent relationship across all sources.

2. **Missing revenue is treated as zero.**

If a campaign has no record in either revenue source, the corresponding revenue value is treated as zero. This assumes that the absence of a revenue record represents no recorded revenue from that source.

3. **Missing spend is not treated as zero.** A missing advertising cost is kept as `NULL`.

This distinction is important: `Spend = 0` and `Spend = NULL` do not necessarily mean the same thing. A zero value can indicate that no spend was recorded, while a missing value may indicate incomplete data or the absence of a corresponding cost record. Therefore, campaigns with missing or zero spend are excluded from profitability and ROAS calculations.

4. **Campaign-level aggregation.**

All four datasets are aggregated to campaign level before being joined. This prevents multiple source-level records from creating unintended row multiplication during the join.

</br>

## Final Marketing Mart

The resulting dataset contains:

| Field |	Description |
| :--- | :--- |
| campaign_id	| Campaign identifier |
| campaign_name	| Campaign name |
| installs	| Number of attributed installs |
| spend	| Total advertising spend |
| ad_revenue	| Revenue from in-app advertising |
| in_app_revenue	| Revenue from in-app purchases/subscriptions |
| total_revenue	| Combined revenue |
| profit	| Revenue minus advertising spend |
| roas	| Return on advertising spend |
| profit_status	| Profitability classification |
| roas_benchmark	| ROAS performance category |

</br>

## [SQL Query]()

</br>

## Dashboard

A Tableau dashboard was created on top of the final marketing mart. The dashboard is designed to answer three main questions:

- Which campaigns are profitable?
- Which campaigns are unprofitable?
- Which campaigns cannot be reliably evaluated because of missing cost data?


