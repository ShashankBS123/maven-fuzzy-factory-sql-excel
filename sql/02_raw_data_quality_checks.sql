-- Project 2: Maven Fuzzy Factory e-commerce analysis
-- Purpose: Check raw import row counts, identifier quality, and key relationships.
-- Run these checks after importing the CSV files into the raw schema.

-- 1. Row counts: compare these with the source CSV data-row counts.
SELECT 'products' AS table_name, COUNT(*) AS row_count FROM raw.products
UNION ALL
SELECT 'orders', COUNT(*) FROM raw.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM raw.order_items
UNION ALL
SELECT 'order_item_refunds', COUNT(*) FROM raw.order_item_refunds
UNION ALL
SELECT 'website_sessions', COUNT(*) FROM raw.website_sessions
UNION ALL
SELECT 'website_pageviews', COUNT(*) FROM raw.website_pageviews
ORDER BY table_name;

-- 2. Identifier checks: distinct_ids should equal total_rows; missing_ids should be zero.
SELECT 'products' AS table_name,
       COUNT(*) AS total_rows,
       COUNT(DISTINCT product_id) AS distinct_ids,
       COUNT(*) FILTER (WHERE product_id IS NULL OR BTRIM(product_id) = '') AS missing_ids
FROM raw.products
UNION ALL
SELECT 'orders', COUNT(*), COUNT(DISTINCT order_id),
       COUNT(*) FILTER (WHERE order_id IS NULL OR BTRIM(order_id) = '')
FROM raw.orders
UNION ALL
SELECT 'order_items', COUNT(*), COUNT(DISTINCT order_item_id),
       COUNT(*) FILTER (WHERE order_item_id IS NULL OR BTRIM(order_item_id) = '')
FROM raw.order_items
UNION ALL
SELECT 'order_item_refunds', COUNT(*), COUNT(DISTINCT order_item_refund_id),
       COUNT(*) FILTER (WHERE order_item_refund_id IS NULL OR BTRIM(order_item_refund_id) = '')
FROM raw.order_item_refunds
UNION ALL
SELECT 'website_sessions', COUNT(*), COUNT(DISTINCT website_session_id),
       COUNT(*) FILTER (WHERE website_session_id IS NULL OR BTRIM(website_session_id) = '')
FROM raw.website_sessions
UNION ALL
SELECT 'website_pageviews', COUNT(*), COUNT(DISTINCT website_pageview_id),
       COUNT(*) FILTER (WHERE website_pageview_id IS NULL OR BTRIM(website_pageview_id) = '')
FROM raw.website_pageviews
ORDER BY table_name;

-- 3. Relationship checks: unmatched_rows should be zero for each relationship.
SELECT 'orders.website_session_id -> website_sessions.website_session_id' AS relationship,
       COUNT(*) AS child_rows,
       COUNT(*) FILTER (WHERE s.website_session_id IS NOT NULL) AS matched_rows,
       COUNT(*) FILTER (WHERE s.website_session_id IS NULL) AS unmatched_rows
FROM raw.orders AS o
LEFT JOIN raw.website_sessions AS s ON o.website_session_id = s.website_session_id
UNION ALL
SELECT 'orders.primary_product_id -> products.product_id', COUNT(*),
       COUNT(*) FILTER (WHERE p.product_id IS NOT NULL),
       COUNT(*) FILTER (WHERE p.product_id IS NULL)
FROM raw.orders AS o
LEFT JOIN raw.products AS p ON o.primary_product_id = p.product_id
UNION ALL
SELECT 'order_items.order_id -> orders.order_id', COUNT(*),
       COUNT(*) FILTER (WHERE o.order_id IS NOT NULL),
       COUNT(*) FILTER (WHERE o.order_id IS NULL)
FROM raw.order_items AS oi
LEFT JOIN raw.orders AS o ON oi.order_id = o.order_id
UNION ALL
SELECT 'order_items.product_id -> products.product_id', COUNT(*),
       COUNT(*) FILTER (WHERE p.product_id IS NOT NULL),
       COUNT(*) FILTER (WHERE p.product_id IS NULL)
FROM raw.order_items AS oi
LEFT JOIN raw.products AS p ON oi.product_id = p.product_id
UNION ALL
SELECT 'order_item_refunds.order_item_id -> order_items.order_item_id', COUNT(*),
       COUNT(*) FILTER (WHERE oi.order_item_id IS NOT NULL),
       COUNT(*) FILTER (WHERE oi.order_item_id IS NULL)
FROM raw.order_item_refunds AS r
LEFT JOIN raw.order_items AS oi ON r.order_item_id = oi.order_item_id
UNION ALL
SELECT 'order_item_refunds.order_id -> orders.order_id', COUNT(*),
       COUNT(*) FILTER (WHERE o.order_id IS NOT NULL),
       COUNT(*) FILTER (WHERE o.order_id IS NULL)
FROM raw.order_item_refunds AS r
LEFT JOIN raw.orders AS o ON r.order_id = o.order_id
UNION ALL
SELECT 'website_pageviews.website_session_id -> website_sessions.website_session_id', COUNT(*),
       COUNT(*) FILTER (WHERE s.website_session_id IS NOT NULL),
       COUNT(*) FILTER (WHERE s.website_session_id IS NULL)
FROM raw.website_pageviews AS pv
LEFT JOIN raw.website_sessions AS s ON pv.website_session_id = s.website_session_id
ORDER BY relationship;

-- 4. Consistency check: order.user_id should agree with the linked session.user_id.
-- There is no separate users table in this dataset, so compare against the order's session.
SELECT COUNT(*) AS total_orders,
       COUNT(*) FILTER (WHERE o.user_id = s.user_id) AS orders_with_matching_user,
       COUNT(*) FILTER (WHERE o.user_id IS DISTINCT FROM s.user_id) AS orders_with_mismatched_user
FROM raw.orders AS o
JOIN raw.website_sessions AS s ON o.website_session_id = s.website_session_id;
