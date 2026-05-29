DROP TABLE IF EXISTS monthly_token_summary;

CREATE TABLE monthly_token_summary AS
WITH monthly_base AS (
    SELECT
        token_name,
        DATE_TRUNC('month', date)                    AS month_start,
        ROUND(AVG(close)::NUMERIC, 8)                AS avg_close,
        ROUND(MIN(low)::NUMERIC, 8)                  AS month_low,
        ROUND(MAX(high)::NUMERIC, 8)                 AS month_high,
        SUM(volume)                                  AS total_volume,
        ROUND(AVG(volume)::NUMERIC, 0)               AS avg_daily_volume,
        ROUND(AVG(daily_volatility_pct)::NUMERIC, 4) AS avg_volatility_pct,
        ROUND(MAX(daily_volatility_pct)::NUMERIC, 4) AS max_volatility_pct,
        COUNT(*)                                     AS trading_days
    FROM daily_token_prices
    GROUP BY token_name, DATE_TRUNC('month', date)
),
-- Get first and last close separately
month_endpoints AS (
    SELECT DISTINCT
        token_name,
        DATE_TRUNC('month', date) AS month_start,
        FIRST_VALUE(close) OVER (
            PARTITION BY token_name, DATE_TRUNC('month', date)
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS month_open_close,
        LAST_VALUE(close) OVER (
            PARTITION BY token_name, DATE_TRUNC('month', date)
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS month_close_close
    FROM daily_token_prices
)
SELECT
    b.*,
    e.month_open_close,
    e.month_close_close,
    ROUND(
        ((e.month_close_close - e.month_open_close) 
        / NULLIF(e.month_open_close, 0) * 100)::NUMERIC
    , 4) AS month_price_change_pct
FROM monthly_base b
JOIN month_endpoints e
    ON b.token_name = e.token_name
    AND b.month_start = e.month_start
ORDER BY token_name, month_start;