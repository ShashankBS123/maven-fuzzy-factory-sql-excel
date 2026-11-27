-- Project 2: Maven Fuzzy Factory e-commerce analysis
-- Purpose: Create raw landing tables for the source CSV files.
-- Raw columns stay TEXT so imports preserve the supplied values.
-- No primary-key constraints are added here; we validate source keys separately.

CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE IF NOT EXISTS raw.products (
    product_id TEXT,
    created_at TEXT,
    product_name TEXT
);

CREATE TABLE IF NOT EXISTS raw.orders (
    order_id TEXT,
    created_at TEXT,
    website_session_id TEXT,
    user_id TEXT,
    primary_product_id TEXT,
    items_purchased TEXT,
    price_usd TEXT,
    cogs_usd TEXT
);

CREATE TABLE IF NOT EXISTS raw.order_items (
    order_item_id TEXT,
    created_at TEXT,
    order_id TEXT,
    product_id TEXT,
    is_primary_item TEXT,
    price_usd TEXT,
    cogs_usd TEXT
);

CREATE TABLE IF NOT EXISTS raw.order_item_refunds (
    order_item_refund_id TEXT,
    created_at TEXT,
    order_item_id TEXT,
    order_id TEXT,
    refund_amount_usd TEXT
);

CREATE TABLE IF NOT EXISTS raw.website_sessions (
    website_session_id TEXT,
    created_at TEXT,
    user_id TEXT,
    is_repeat_session TEXT,
    utm_source TEXT,
    utm_campaign TEXT,
    utm_content TEXT,
    device_type TEXT,
    http_referer TEXT
);

CREATE TABLE IF NOT EXISTS raw.website_pageviews (
    website_pageview_id TEXT,
    created_at TEXT,
    website_session_id TEXT,
    pageview_url TEXT
);
