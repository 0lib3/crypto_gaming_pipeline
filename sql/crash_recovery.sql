WITH monthly_changes AS (
    SELECT
        token_name,
        month_start,
        avg_close,
        total_volume,
        month_price_change_pct,
        -- Flag months where price dropped more than 30%
        CASE WHEN month_price_change_pct < -30 THEN 1 ELSE 0 END AS is_crash_month
    FROM monthly_token_summary
),
crashes AS (
    -- Identify the worst crash month per token
    SELECT
        token_name,
        month_start AS crash_month,
        month_price_change_pct AS crash_pct,
        avg_close AS price_at_crash,
        total_volume AS volume_at_crash,
        RANK() OVER (
            PARTITION BY token_name 
            ORDER BY month_price_change_pct ASC
        ) AS crash_rank
    FROM monthly_changes
    WHERE is_crash_month = 1
),
worst_crash AS (
    SELECT * FROM crashes WHERE crash_rank = 1
),
recovery AS (
    -- Look at the 3 months after each crash
    SELECT
        w.token_name,
        w.crash_month,
        w.crash_pct,
        w.price_at_crash,
        w.volume_at_crash,
        m.month_start AS recovery_month,
        m.avg_close AS recovery_price,
        m.total_volume AS recovery_volume,
        EXTRACT(MONTH FROM AGE(m.month_start::DATE, w.crash_month::DATE)) +
        EXTRACT(YEAR FROM AGE(m.month_start::DATE, w.crash_month::DATE)) * 12 
            AS months_after_crash,
        -- How much did price recover?
        ROUND(
            ((m.avg_close - w.price_at_crash) / NULLIF(w.price_at_crash, 0) * 100)::NUMERIC
        , 2) AS price_recovery_pct,
        -- Did volume recover?
        ROUND(
            (m.total_volume::NUMERIC / NULLIF(w.volume_at_crash, 0) * 100)
        , 2) AS volume_recovery_pct
    FROM worst_crash w
    JOIN monthly_token_summary m
        ON w.token_name = m.token_name
        AND m.month_start > w.crash_month
        AND m.month_start <= w.crash_month + INTERVAL '3 months'
)
SELECT
    token_name,
    crash_month,
    ROUND(crash_pct::NUMERIC, 2)            AS crash_pct,
    months_after_crash,
    ROUND(price_recovery_pct::NUMERIC, 2)   AS price_recovery_pct,
    ROUND(volume_recovery_pct::NUMERIC, 2)  AS volume_recovery_pct,
    CASE
        WHEN price_recovery_pct > 0 
         AND volume_recovery_pct > 80  THEN 'Strong Recovery'
        WHEN price_recovery_pct > 0 
         AND volume_recovery_pct <= 80 THEN 'Price Recovery Only'
        WHEN price_recovery_pct <= 0 
         AND volume_recovery_pct > 80  THEN 'Volume Recovery Only'
        ELSE 'No Recovery'
    END AS recovery_status
FROM recovery
ORDER BY token_name, months_after_crash;