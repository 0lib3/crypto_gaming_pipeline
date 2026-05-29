CREATE TABLE daily_token_prices AS
WITH base AS (
    SELECT
        token_name,
        date,
        open,
        high,
        low,
        close,
        volume,
        currency,
        -- Daily price range as % of open (volatility signal)
        ROUND(((high - low) / NULLIF(open, 0)) * 100, 4) AS daily_volatility_pct,
        -- Day over day price change
        close - LAG(close) OVER (PARTITION BY token_name ORDER BY date) AS price_change,
        -- Day over day % change
        ROUND(
            ((close - LAG(close) OVER (PARTITION BY token_name ORDER BY date)) 
            / NULLIF(LAG(close) OVER (PARTITION BY token_name ORDER BY date), 0)) * 100
        , 4) AS price_change_pct,
        -- 7 day rolling average close
        ROUND(AVG(close) OVER (
            PARTITION BY token_name 
            ORDER BY date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 8) AS rolling_7d_avg_close,
        -- 7 day rolling volume
        SUM(volume) OVER (
            PARTITION BY token_name 
            ORDER BY date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS rolling_7d_volume
    FROM raw_token_prices
)
SELECT
    token_name,
    date,
    open,
    high,
    low,
    close,
    volume,
    currency,
    daily_volatility_pct,
    price_change,
    price_change_pct,
    rolling_7d_avg_close,
    rolling_7d_volume
FROM base
ORDER BY token_name, date;