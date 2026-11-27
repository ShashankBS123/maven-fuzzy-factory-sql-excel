-- Create a schema for analysis queries and views.
CREATE SCHEMA IF NOT EXISTS analysis;

-- 1. Product performance: sales, estimated cost, and estimated profit.
SELECT
    p.product_id,
    p.product_name,
    COUNT(*) AS order_item_lines,
    SUM(oi.price_usd) AS total_sales_usd,
    SUM(oi.cogs_usd) AS total_cost_usd,
    SUM(oi.price_usd - oi.cogs_usd) AS estimated_profit_usd,
    ROUND(
        100.0 * SUM(oi.price_usd - oi.cogs_usd)
        / NULLIF(SUM(oi.price_usd), 0),
        2
    ) AS estimated_margin_percent
FROM staging.order_items oi
JOIN staging.products p
    ON p.product_id = oi.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_sales_usd DESC;

-- 2. Monthly sales and estimated profit, before refunds.
SELECT
    DATE_TRUNC('month', created_at)::DATE AS sales_month,
    COUNT(*) AS order_item_lines,
    SUM(price_usd) AS sales_usd,
    SUM(price_usd - cogs_usd) AS estimated_profit_usd
FROM staging.order_items
GROUP BY DATE_TRUNC('month', created_at)::DATE
ORDER BY sales_month;

-- 3. Monthly order count and average sales per order, before refunds.
SELECT
    DATE_TRUNC('month', created_at)::DATE AS sales_month,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) AS order_item_lines,
    SUM(price_usd) AS sales_usd,
    ROUND(
        SUM(price_usd) / NULLIF(COUNT(DISTINCT order_id), 0),
        2
    ) AS average_sales_per_order_usd
FROM staging.order_items
GROUP BY DATE_TRUNC('month', created_at)::DATE
ORDER BY sales_month;


-- 4. Product refunds and sales after refunds.
-- Sum refunds per order item before joining, to avoid duplicating sales.
WITH refunds_by_item AS (
    SELECT
        order_item_id,
        SUM(refund_amount_usd) AS refund_amount_usd
    FROM staging.order_item_refunds
    GROUP BY order_item_id
)

-- Product sales compared with refunds, before other costs.
SELECT
    p.product_id,
    p.product_name,
    COUNT(*) AS order_item_lines,
    COUNT(*) FILTER (
        WHERE COALESCE(r.refund_amount_usd, 0) > 0
    ) AS refunded_item_lines,
    SUM(oi.price_usd) AS gross_sales_usd,
    SUM(COALESCE(r.refund_amount_usd, 0)) AS refunds_usd,
    SUM(oi.price_usd) - SUM(COALESCE(r.refund_amount_usd, 0))
        AS sales_after_refunds_usd,
    ROUND(
        100.0 * SUM(COALESCE(r.refund_amount_usd, 0))
        / NULLIF(SUM(oi.price_usd), 0),
        2
    ) AS refund_rate_percent
FROM staging.order_items oi
JOIN staging.products p
    ON p.product_id = oi.product_id
LEFT JOIN refunds_by_item r
    ON r.order_item_id = oi.order_item_id
GROUP BY p.product_id, p.product_name
ORDER BY gross_sales_usd DESC;

-- 5. Session-to-order conversion by traffic source, campaign, and device.
-- Treat actual NULLs, blank strings, and the text 'NULL' as Unattributed.
SELECT
    CASE
        WHEN s.utm_source IS NULL
          OR BTRIM(s.utm_source) = ''
          OR UPPER(BTRIM(s.utm_source)) = 'NULL'
        THEN 'Unattributed'
        ELSE BTRIM(s.utm_source)
    END AS traffic_source,

    CASE
        WHEN s.utm_campaign IS NULL
          OR BTRIM(s.utm_campaign) = ''
          OR UPPER(BTRIM(s.utm_campaign)) = 'NULL'
        THEN 'Unattributed'
        ELSE BTRIM(s.utm_campaign)
    END AS campaign,

    s.device_type,
    COUNT(DISTINCT s.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(
        100.0 * COUNT(DISTINCT o.order_id)
        / NULLIF(COUNT(DISTINCT s.website_session_id), 0),
        2
    ) AS conversion_rate_percent
FROM staging.website_sessions s
LEFT JOIN staging.orders o
    ON o.website_session_id = s.website_session_id
GROUP BY
    CASE
        WHEN s.utm_source IS NULL
          OR BTRIM(s.utm_source) = ''
          OR UPPER(BTRIM(s.utm_source)) = 'NULL'
        THEN 'Unattributed'
        ELSE BTRIM(s.utm_source)
    END,
    CASE
        WHEN s.utm_campaign IS NULL
          OR BTRIM(s.utm_campaign) = ''
          OR UPPER(BTRIM(s.utm_campaign)) = 'NULL'
        THEN 'Unattributed'
        ELSE BTRIM(s.utm_campaign)
    END,
    s.device_type
ORDER BY sessions DESC;

-- 6. Prepare one row per order-item line for export to Excel.
-- Product names are kept in a separate view for XLOOKUP practice.
CREATE OR REPLACE VIEW analysis.order_item_detail AS
WITH refunds_by_item AS (
    SELECT
        order_item_id,
        SUM(refund_amount_usd) AS refund_amount_usd
    FROM staging.order_item_refunds
    GROUP BY order_item_id
)
SELECT
    oi.order_item_id,
    oi.order_id,
    o.created_at::DATE AS order_date,
    o.website_session_id,
    oi.product_id,
    oi.price_usd AS item_price_usd,
    oi.cogs_usd AS item_cogs_usd,
    COALESCE(r.refund_amount_usd, 0) AS refund_amount_usd,
    oi.price_usd - oi.cogs_usd AS estimated_profit_usd,
    oi.price_usd - COALESCE(r.refund_amount_usd, 0)
        AS sales_after_refund_usd
FROM staging.order_items oi
JOIN staging.orders o
    ON o.order_id = oi.order_id
LEFT JOIN refunds_by_item r
    ON r.order_item_id = oi.order_item_id;
-- Validate the export view and inspect a sample.
SELECT COUNT(*) AS detail_rows
FROM analysis.order_item_detail;

SELECT *
FROM analysis.order_item_detail
ORDER BY order_item_id
LIMIT 10;


-- Product lookup table for Excel XLOOKUP practice.
CREATE OR REPLACE VIEW analysis.product_lookup AS
SELECT
    product_id,
    product_name
FROM staging.products;

SELECT
    COUNT(*) AS product_rows,
    COUNT(DISTINCT product_id) AS distinct_product_ids
FROM analysis.product_lookup;

SELECT *
FROM analysis.product_lookup
ORDER BY product_id;
