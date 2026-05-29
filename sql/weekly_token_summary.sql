CREATE TABLE weekly_token_summary AS
SELECT
    token_name,
    DATE_TRUNC('week', date) AS week_start,
    -- Price
    ROUND(AVG(close)::NUMERIC, 8)           AS avg_close,
    ROUND(MIN(low)::NUMERIC, 8)             AS week_low,
    ROUND(MAX(high)::NUMERIC, 8)            AS week_high,
    -- Volume
    SUM(volume)                             AS total_volume,
    ROUND(AVG(volume)::NUMERIC, 0)          AS avg_daily_volume,
    -- Volatility
    ROUND(AVG(daily_volatility_pct)::NUMERIC, 4) AS avg_volatility_pct,
    -- Week over week price change
    ROUND(
        ((MAX(close) - MIN(open)) / NULLIF(MIN(open), 0) * 100)::NUMERIC
    , 4)                                    AS week_price_change_pct,
    -- Row count
    COUNT(*)                                AS trading_days
FROM daily_token_prices
GROUP BY token_name, DATE_TRUNC('week', date)
ORDER BY token_name, week_start;