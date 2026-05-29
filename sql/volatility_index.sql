WITH token_stats AS (
    SELECT
        token_name,
        ROUND(AVG(avg_volatility_pct)::NUMERIC, 4)  AS avg_monthly_volatility,
        ROUND(MAX(max_volatility_pct)::NUMERIC, 4)  AS worst_day_volatility,
        ROUND(STDDEV(avg_close)::NUMERIC, 8)        AS price_std_dev,
        COUNT(*)                                     AS months_of_data
    FROM monthly_token_summary
    GROUP BY token_name
),
ranked AS (
    SELECT
        token_name,
        avg_monthly_volatility,
        worst_day_volatility,
        price_std_dev,
        months_of_data,
        NTILE(4) OVER (ORDER BY avg_monthly_volatility DESC) AS volatility_quartile
    FROM token_stats
    WHERE months_of_data >= 3
    AND avg_monthly_volatility IS NOT NULL  -- exclude bad data
    AND avg_monthly_volatility < 100000     -- exclude extreme outliers
)
SELECT
    token_name,
    avg_monthly_volatility,
    worst_day_volatility,
    price_std_dev,
    months_of_data,
    CASE volatility_quartile
        WHEN 1 THEN 'High Risk'
        WHEN 2 THEN 'Medium-High Risk'
        WHEN 3 THEN 'Medium-Low Risk'
        WHEN 4 THEN 'Low Risk'
    END AS risk_category
FROM ranked
ORDER BY avg_monthly_volatility DESC;