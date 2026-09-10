WITH

-- Aggregate installs by campaign
installs AS (
    SELECT
        campaign_id,
        campaign_name,
        COUNT(*) AS install_count
    FROM non_org_installs_report
    WHERE campaign_id IS NOT NULL
    GROUP BY
        campaign_id,
        campaign_name
),

-- Aggregate advertising spend by campaign
spend AS (
    SELECT
        campaign_id,
        campaign AS campaign_name,
        SUM(cost_usd) AS spend
    FROM cost_table
    WHERE campaign_id IS NOT NULL
    GROUP BY
        campaign_id,
        campaign_name
),

-- Aggregate advertising revenue by campaign
ad_revenue AS (
    SELECT
        campaign_id,
        campaign_name,
        SUM(event_revenue_usd) AS ad_revenue
    FROM ad_revenue_raw
    WHERE campaign_id IS NOT NULL
    GROUP BY
        campaign_id,
        campaign_name
),

-- Aggregate in-app revenue by campaign
iap_revenue AS (
    SELECT
        campaign_id,
        campaign_name,
        SUM(event_revenue_usd) AS iap_revenue
    FROM in_app_events_report
    WHERE campaign_id IS NOT NULL
    GROUP BY
        campaign_id,
        campaign_name
),

-- Combine all campaign data
combined AS (
    SELECT
        COALESCE(
            installs.campaign_id,
            spend.campaign_id,
            ad_revenue.campaign_id,
            iap_revenue.campaign_id
        ) AS campaign_id,

        COALESCE(
            installs.campaign_name,
            spend.campaign_name,
            ad_revenue.campaign_name,
            iap_revenue.campaign_name
        ) AS campaign_name,

        installs.install_count,
        spend.spend,
        ad_revenue.ad_revenue,
        iap_revenue.iap_revenue

    FROM installs AS installs
    FULL OUTER JOIN spend AS spend
        ON installs.campaign_id = spend.campaign_id

    FULL OUTER JOIN ad_revenue AS ad_revenue
        ON COALESCE(
            installs.campaign_id,
            spend.campaign_id
        ) = ad_revenue.campaign_id

    FULL OUTER JOIN iap_revenue AS iap_revenue
        ON COALESCE(
            installs.campaign_id,
            spend.campaign_id,
            ad_revenue.campaign_id
        ) = iap_revenue.campaign_id
),

-- Calculate campaign profitability metrics
metrics AS (
    SELECT
        campaign_id,
        campaign_name,
        install_count,
        spend,
        ad_revenue,
        iap_revenue,

        COALESCE(ad_revenue, 0)
            + COALESCE(iap_revenue, 0) AS total_revenue,

        CASE
            WHEN spend IS NULL THEN NULL
            ELSE
                COALESCE(ad_revenue, 0)
                + COALESCE(iap_revenue, 0)
                - spend
        END AS profit,

        CASE
            WHEN spend IS NULL OR spend = 0 THEN NULL
            ELSE
                (
                    COALESCE(ad_revenue, 0)
                    + COALESCE(iap_revenue, 0)
                ) / spend
        END AS roas

    FROM combined
)

SELECT
    campaign_id,
    campaign_name,
    install_count,
    spend,
    ad_revenue,
    iap_revenue,
    total_revenue,
    profit,
    roas,

    CASE
        WHEN spend IS NULL OR spend = 0
            THEN 'not enough data to calculate'
        WHEN profit > 0
            THEN 'profitable'
        ELSE 'unprofitable'
    END AS profit_status,

    CASE
        WHEN roas IS NULL
            THEN 'not enough data to calculate'
        WHEN roas < 3
            THEN 'below the minimum acceptable level'
        WHEN roas = 3
            THEN 'minimum acceptable level'
        WHEN roas > 3 AND roas < 8
            THEN 'good result'
        ELSE 'excellent result'
    END AS roas_benchmark

FROM metrics
ORDER BY profit DESC;
