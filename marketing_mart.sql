WITH
--t1. installs
installs AS (
  SELECT
    campaign_id,
    campaign_name,
    COUNT(*) AS installs
  FROM non_org_installs_report
  WHERE campaign_id IS NOT NULL
  --relationship 1:1, 1 campaign_id -> 1 campaign_name 
  GROUP BY campaign_id, campaign_name 
),

--t2. spend
spend AS (
  SELECT
    campaign_id,
    campaign AS campaign_name,
    SUM(cost_usd) AS spend
  FROM cost_table
  WHERE campaign_id IS NOT NULL
  GROUP BY campaign_id, campaign_name
),

--t3. revenue (in-app adds)
revenue_t3 AS (
  SELECT
    campaign_id,
    campaign_name,
    SUM(event_revenue_usd) AS revenue_t3
  FROM ad_revenue_raw
  WHERE campaign_id IS NOT NULL
  GROUP BY campaign_id, campaign_name
),

--t4. revenue (in-app purchases)
revenue_t4 AS (
  SELECT
    campaign_id,
    campaign_name,
    SUM(event_revenue_usd) AS revenue_t4
  FROM in_app_events_report
  WHERE campaign_id IS NOT NULL
  GROUP BY campaign_id, campaign_name
),

--join
combined AS (
  SELECT
    COALESCE(i.campaign_id, s.campaign_id, r3.campaign_id, r4.campaign_id)
      AS campaign_id,

    COALESCE(
      i.campaign_name,
      s.campaign_name,
      r3.campaign_name,
      r4.campaign_name
    ) AS campaign_name,

    i.installs,
    s.spend,
    r3.revenue_t3,
    r4.revenue_t4

  FROM installs i
  FULL OUTER JOIN spend s
    ON i.campaign_id = s.campaign_id
  FULL OUTER JOIN revenue_t3 r3
    ON COALESCE(i.campaign_id, s.campaign_id) = r3.campaign_id
  FULL OUTER JOIN revenue_t4 r4
    ON COALESCE(i.campaign_id, s.campaign_id, r3.campaign_id) = r4.campaign_id
),

--metrics
metrics AS (
  SELECT
    campaign_id,
    campaign_name,
    installs,
    spend,
    revenue_t3,
    revenue_t4,

    --revenue missing -> 0
    COALESCE(revenue_t3, 0) + COALESCE(revenue_t4, 0) AS total_revenue,

    --profit
    CASE
      WHEN spend IS NULL THEN NULL
      ELSE
        COALESCE(revenue_t3, 0) + COALESCE(revenue_t4, 0) - spend
    END AS profit,

    --roas
    CASE
      WHEN spend IS NULL OR spend = 0 THEN NULL
      ELSE
        (COALESCE(revenue_t3, 0) + COALESCE(revenue_t4, 0)) / spend
    END AS roas
  FROM combined
)

SELECT
  campaign_id,
  campaign_name,
  installs,
  spend,
  revenue_t3,
  revenue_t4,
  total_revenue,
  profit,
  roas,

  --profit status (profitable/unprofitable)
  CASE
    WHEN spend IS NULL OR spend = 0 THEN 'not enough data to calculate'
    WHEN profit > 0 THEN 'profitable'
    ELSE 'unprofitable'
  END AS profit_status,

  --roas benchmark
  CASE
    WHEN roas IS NULL THEN 'not enough data to calculate'
    WHEN roas < 3 THEN 'below the minimum acceptable level'
    WHEN roas = 3 THEN 'minimum acceptable level'
    WHEN roas > 3 AND roas < 8 THEN 'good result'
    ELSE 'excellent result'
  END AS roas_benchmark

FROM metrics
ORDER BY profit DESC;
