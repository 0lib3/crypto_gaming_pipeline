WITH token_peak AS (
    -- Find each token's peak volume month
    SELECT
        token_name,
        month_start,
        total_volume,
        RANK() OVER (
            PARTITION BY token_name 
            ORDER BY total_volume DESC
        ) AS volume_rank
    FROM monthly_token_summary
),
peak_volumes AS (
    -- Keep only the peak month per token
    SELECT token_name, month_start AS peak_month, total_volume AS peak_volume
    FROM token_peak
    WHERE volume_rank = 1
),
retention AS (
    -- Compare every month's volume to that token's peak
    SELECT
        m.token_name,
        m.month_start,
        m.total_volume,
        p.peak_month,
        p.peak_volume,
        ROUND((m.total_volume::NUMERIC / NULLIF(p.peak_volume, 0) * 100), 2) AS volume_retention_pct,
        -- How many months since peak?
        EXTRACT(MONTH FROM AGE(m.month_start::DATE, p.peak_month::DATE)) +
        EXTRACT(YEAR FROM AGE(m.month_start::DATE, p.peak_month::DATE)) * 12 AS months_since_peak
    FROM monthly_token_summary m
    JOIN peak_volumes p ON m.token_name = p.token_name
)
SELECT
    token_name,
    month_start,
    total_volume,
    peak_month,
    peak_volume,
    volume_retention_pct,
    months_since_peak
FROM retention
ORDER BY token_name, month_start;