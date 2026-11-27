-- Project 2: Maven Fuzzy Factory e-commerce analysis
-- Purpose: Create a typed staging view for product data.
-- The raw table keeps the original text values unchanged.
-- This view converts product_id and created_at for SQL analysis.

CREATE SCHEMA IF NOT EXISTS staging;

CREATE OR REPLACE VIEW staging.products AS
SELECT
    product_id::INTEGER AS product_id,
    created_at::TIMESTAMP AS created_at,
    product_name
FROM raw.products;

SELECT * 
FROM staging.products;

-- Convert raw order fields to analysis-ready types.
CREATE OR REPLACE VIEW staging.orders AS
SELECT
    order_id::INTEGER AS order_id,
    created_at::TIMESTAMP AS created_at,
    website_session_id::INTEGER AS website_session_id,
    user_id::INTEGER AS user_id,
    primary_product_id::INTEGER AS primary_product_id,
    items_purchased::INTEGER AS items_purchased,
    price_usd::NUMERIC(12, 2) AS price_usd,
    cogs_usd::NUMERIC(12, 2) AS cogs_usd
FROM raw.orders;

SELECT COUNT(*) AS staged_orders
FROM staging.orders;

SELECT *
FROM staging.orders LIMIT 5;

-- Convert raw order-item fields to analysis-ready types.
CREATE OR REPLACE VIEW staging.order_items AS
SELECT 
	order_item_id::INTEGER AS order_item_id,
	created_at::TIMESTAMP AS created_at,
	order_id::INTEGER AS order_id,
	product_id::INTEGER AS product_id,
	is_primary_item::SMALLINT AS is_primary,
	price_usd::NUMERIC(12,2) AS price_usd,
	cogs_usd::NUMERIC(12,2) AS cogs_usd
FROM raw.order_items;

SELECT COUNT(*) AS staged_order_items
FROM staging.order_items;

SELECT *
FROM staging.order_items
LIMIT 5;

-- Convert raw refund fields to analysis-ready types.
CREATE OR REPLACE VIEW staging.order_item_refunds AS
SELECT
    order_item_refund_id::INTEGER AS order_item_refund_id,
    created_at::TIMESTAMP AS created_at,
    order_item_id::INTEGER AS order_item_id,
    order_id::INTEGER AS order_id,
    refund_amount_usd::NUMERIC(12, 2) AS refund_amount_usd
FROM raw.order_item_refunds;

SELECT COUNT(*) AS staged_refunds
FROM staging.order_item_refunds;

SELECT * 
FROM staging.order_item_refunds LIMIT 5;

-- Convert raw session fields; parse the source's day-month-year timestamp.
CREATE OR REPLACE VIEW staging.website_sessions AS
SELECT
    website_session_id::INTEGER AS website_session_id,
    TO_TIMESTAMP(created_at, 'DD-MM-YYYY HH24:MI')::TIMESTAMP AS created_at,
    user_id::INTEGER AS user_id,
    is_repeat_session::SMALLINT AS is_repeat_session,
    utm_source,
    utm_campaign,
    utm_content,
    device_type,
    http_referer
FROM raw.website_sessions;

SELECT COUNT(*) AS staged_sessions
FROM staging.website_sessions;

SELECT * 
FROM staging.website_sessions LIMIT 5;

-- Convert raw pageview fields to useful data types.
CREATE OR REPLACE VIEW staging.website_pageviews AS
SELECT
    website_pageview_id::INTEGER AS website_pageview_id,
    created_at::TIMESTAMP AS created_at,
    website_session_id::INTEGER AS website_session_id,
    pageview_url
FROM raw.website_pageviews;

-- Confirm that all raw pageviews appear in the staging view.
SELECT COUNT(*) AS staged_pageviews
FROM staging.website_pageviews;

-- Inspect a few rows and check that the fields look right.
SELECT *
FROM staging.website_pageviews
LIMIT 5;

-- Check that every staging view has the expected number of rows.
SELECT 'products' AS table_name, COUNT(*) AS row_count
FROM staging.products

UNION ALL
SELECT 'orders', COUNT(*)
FROM staging.orders

UNION ALL
SELECT 'order_items', COUNT(*)
FROM staging.order_items

UNION ALL
SELECT 'order_item_refunds', COUNT(*)
FROM staging.order_item_refunds

UNION ALL
SELECT 'website_sessions', COUNT(*)
FROM staging.website_sessions

UNION ALL
SELECT 'website_pageviews', COUNT(*)
FROM staging.website_pageviews

ORDER BY table_name;
	
-- Check required IDs and timestamps for missing values in staging views.
SELECT 'products' AS table_name,
       COUNT(*) FILTER (WHERE product_id IS NULL) AS missing_ids,
       COUNT(*) FILTER (WHERE created_at IS NULL) AS missing_dates
FROM staging.products

UNION ALL
SELECT 'orders',
       COUNT(*) FILTER (WHERE order_id IS NULL OR website_session_id IS NULL),
       COUNT(*) FILTER (WHERE created_at IS NULL)
FROM staging.orders

UNION ALL
SELECT 'order_items',
       COUNT(*) FILTER (WHERE order_item_id IS NULL OR order_id IS NULL),
       COUNT(*) FILTER (WHERE created_at IS NULL)
FROM staging.order_items

UNION ALL
SELECT 'order_item_refunds',
       COUNT(*) FILTER (WHERE order_item_refund_id IS NULL OR order_item_id IS NULL),
       COUNT(*) FILTER (WHERE created_at IS NULL)
FROM staging.order_item_refunds

UNION ALL
SELECT 'website_sessions',
       COUNT(*) FILTER (WHERE website_session_id IS NULL),
       COUNT(*) FILTER (WHERE created_at IS NULL)
FROM staging.website_sessions

UNION ALL
SELECT 'website_pageviews',
       COUNT(*) FILTER (WHERE website_pageview_id IS NULL OR website_session_id IS NULL),
       COUNT(*) FILTER (WHERE created_at IS NULL)
FROM staging.website_pageviews

ORDER BY table_name;	

-- Confirm that each staged table's key is unique.
SELECT 'products' AS table_name,
       COUNT(*) AS rows,
       COUNT(DISTINCT product_id) AS distinct_keys
FROM staging.products

UNION ALL
SELECT 'orders', COUNT(*), COUNT(DISTINCT order_id)
FROM staging.orders

UNION ALL
SELECT 'order_items', COUNT(*), COUNT(DISTINCT order_item_id)
FROM staging.order_items

UNION ALL
SELECT 'order_item_refunds', COUNT(*), COUNT(DISTINCT order_item_refund_id)
FROM staging.order_item_refunds

UNION ALL
SELECT 'website_sessions', COUNT(*), COUNT(DISTINCT website_session_id)
FROM staging.website_sessions

UNION ALL
SELECT 'website_pageviews', COUNT(*), COUNT(DISTINCT website_pageview_id)
FROM staging.website_pageviews

ORDER BY table_name;

-- Check that staged foreign keys still match their related records.
SELECT 'orders -> sessions' AS relationship,
       COUNT(*) AS unmatched_rows
FROM staging.orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM staging.website_sessions s
    WHERE s.website_session_id = o.website_session_id
)

UNION ALL
SELECT 'order items -> orders',
       COUNT(*)
FROM staging.order_items oi
WHERE NOT EXISTS (
    SELECT 1
    FROM staging.orders o
    WHERE o.order_id = oi.order_id
)

UNION ALL
SELECT 'order items -> products',
       COUNT(*)
FROM staging.order_items oi
WHERE NOT EXISTS (
    SELECT 1
    FROM staging.products p
    WHERE p.product_id = oi.product_id
)

UNION ALL
SELECT 'refunds -> order items',
       COUNT(*)
FROM staging.order_item_refunds r
WHERE NOT EXISTS (
    SELECT 1
    FROM staging.order_items oi
    WHERE oi.order_item_id = r.order_item_id
)

UNION ALL
SELECT 'pageviews -> sessions',
       COUNT(*)
FROM staging.website_pageviews pv
WHERE NOT EXISTS (
    SELECT 1
    FROM staging.website_sessions s
    WHERE s.website_session_id = pv.website_session_id
)

ORDER BY relationship;