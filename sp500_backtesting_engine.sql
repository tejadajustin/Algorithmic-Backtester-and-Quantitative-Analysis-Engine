CREATE OR REPLACE VIEW public.view_sp500_quant_signals AS

--sma, trade day indicator, daily return
WITH price_metrics AS (
    SELECT 
        sp500_historical.ticker,
        sp500_historical.trade_date,
        sp500_historical.close_price,
        sp500_historical.adj_close,
        
        (sp500_historical.adj_close - lag(sp500_historical.adj_close, 1) 
        OVER (PARTITION BY sp500_historical.ticker ORDER BY sp500_historical.trade_date)) 
        / NULLIF(lag(sp500_historical.adj_close, 1) OVER (PARTITION BY sp500_historical.ticker 
        ORDER BY sp500_historical.trade_date), 0::numeric) AS daily_return,
        
        avg(sp500_historical.adj_close) OVER (PARTITION BY sp500_historical.ticker 
        ORDER BY sp500_historical.trade_date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS sma_50,
        
        avg(sp500_historical.adj_close) OVER (PARTITION BY sp500_historical.ticker 
        ORDER BY sp500_historical.trade_date ROWS BETWEEN 199 PRECEDING AND CURRENT ROW) AS sma_200,
        
        row_number() OVER (PARTITION BY sp500_historical.ticker ORDER BY sp500_historical.trade_date) AS trade_day_num
   
	FROM sp500_historical
), 

--yesterday's sma
crossover_metrics AS (
    SELECT 
        price_metrics.ticker,
        price_metrics.trade_date,
        price_metrics.close_price,
        price_metrics.adj_close,
        price_metrics.daily_return,
        price_metrics.sma_50,
        price_metrics.sma_200,
        price_metrics.trade_day_num,
        
        lag(price_metrics.sma_50, 1) OVER (PARTITION BY price_metrics.ticker 
        ORDER BY price_metrics.trade_date) AS prev_sma_50,
        
        lag(price_metrics.sma_200, 1) OVER (PARTITION BY price_metrics.ticker 
        ORDER BY price_metrics.trade_date) AS prev_sma_200
        
    FROM price_metrics
),

--momentum crossover algorithm; when to buy and sell depending on golden cross or death cross, if neither just hold
signal_metrics AS (
    SELECT 
        ticker,
        trade_date,
        close_price,
        adj_close,
        round(daily_return, 6) AS daily_return,
        round(sma_50, 4) AS sma_50,
        round(sma_200, 4) AS sma_200,
        trade_day_num,
        
        CASE
            WHEN trade_day_num < 200 THEN 'WARMUP'::text
            WHEN prev_sma_50 <= prev_sma_200 AND sma_50 > sma_200 THEN 'BUY'::text
            WHEN prev_sma_50 >= prev_sma_200 AND sma_50 < sma_200 THEN 'SELL'::text
            ELSE 'HOLD'::text
        END AS trading_signal
        
    FROM crossover_metrics
),

--while trading signal may either be buy or sell, this assures it occurs the day after. this is because sma 50 and sma 200 is calculated using CLOSING prices, meaning if a golden or death cross occurs it must happen the next day.
strategy_returns AS (
    SELECT 
        *,
        CASE 
            WHEN LAG(sma_50, 1) OVER (PARTITION BY ticker ORDER BY trade_date) > 
                 LAG(sma_200, 1) OVER (PARTITION BY ticker ORDER BY trade_date) 
            THEN daily_return 
            ELSE 0 
        END AS strategy_daily_return
    FROM signal_metrics
),

--logarithmic engine; the maine issue for the original dax measure. this new code is more efficient to find the compounded growth for both strategies.
compounded_growth AS (
    SELECT 
        *,
        -- Buy & Hold: $10k compounded
        10000.0 * EXP(
            SUM(LN(1 + GREATEST(COALESCE(daily_return::numeric, 0), -0.9999))) 
            OVER (PARTITION BY ticker ORDER BY trade_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        ) AS buy_hold_value,
        
        -- Algorithmic Strategy: $10k compounded
        10000.0 * EXP(
            SUM(LN(1 + GREATEST(COALESCE(strategy_daily_return::numeric, 0), -0.9999))) 
            OVER (PARTITION BY ticker ORDER BY trade_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        ) AS algorithmic_strategy_value
    FROM strategy_returns
)

--determines maximum drawdown
SELECT 
    ticker,
    trade_date,
    close_price,
    adj_close,
    daily_return,
    sma_50,
    sma_200,
    trade_day_num,
    trading_signal,
    buy_hold_value,
    algorithmic_strategy_value,
    
    (buy_hold_value - MAX(buy_hold_value) OVER (PARTITION BY ticker 
    ORDER BY trade_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) 
    / NULLIF(MAX(buy_hold_value) OVER (PARTITION BY ticker 
    ORDER BY trade_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0) AS benchmark_drawdown,

    (algorithmic_strategy_value - MAX(algorithmic_strategy_value) OVER (PARTITION BY ticker 
    ORDER BY trade_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) 
    / NULLIF(MAX(algorithmic_strategy_value) OVER (PARTITION BY ticker 
    ORDER BY trade_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0) AS strategy_drawdown
    
FROM compounded_growth;