# Algorithmic Backtester and Quantitative Analysis Engine

## Overview
This quantitative backtesting engine evaluates algorithmic trading strategies against historical market data. 

Initially, the model relied on the front-end visualization layer for calculating compounded portfolio growth. However, iterating row-by-row logic over a 2.7M+ row dataset created severe rendering bottlenecks. To optimize compute efficiency, the mathematical engine was completely remade. Heavy aggregations and logarithmic compounding formulas were migrated directly into the database backend, allowing the BI interface to function strictly as a high-speed, interactive visualization layer achieving millisecond render times.

### Dashboard Demonstration
<img width="2304" height="1294" alt="Recording2026-08-262035561-ezgif com-optimize" src="https://github.com/user-attachments/assets/410475aa-8b94-4f51-8800-579e46c0c373" />

## Strategy Logic & Performance Metrics
The engine evaluates a continuous state-based model using moving average crossovers:
* **Trigger:** 50-Day & 200-Day Simple Moving Average (SMA) crossover.
* **Buy Rule:** 50-Day SMA crosses above the 200-Day SMA (*Golden Cross*).
* **Sell Rule:** 50-Day SMA crosses below the 200-Day SMA (*Death Cross*).
* **Timing:** A T+1 execution offset is applied to all signals to prevent using future data (*Look Ahead Bias*).
* **Comparison:** The algorithmic strategy is measured against a standard Buy & Hold strategy. Both of these strategies start with a $10,000 capital using split-adjusted returns.

## Benchmarking & Risk Analysis
* **Portfolio Baseline:** Compares algorithmic compounding against a $10,000 passive Buy & Hold baseline.
* **Drawdown Profiling:** Measures peak-to-trough equity declines to quantify capital preservation during severe market corrections.

## Technology Stack
* **Database Backend (PostgreSQL):** Handles the data pipeline, window functions, CTEs, and logarithmic compounding.
* **Visualization Layer (Power BI):** Serves as the interactive UI, providing responsive ticker/date filtering, performance visualization, and bookmark-driven overlay panels.

## Data Source
* [Historical market dataset](https://www.kaggle.com/datasets/jacksaleeby/s-and-p500-historical-data)
* Contains 2.7M+ daily records including Open, High, Low, Close, Adjusted Close, and Volume.

## Repository Contents & Downloads
Due to GitHub's file size limits, the fully cached `.pbix` file containing all 2.7 million rows of data is hosted in GitHub Releases. 

* **[Download Full Interactive Dashboard (.pbix)](https://github.com/tejadajustin/Algorithmic-Backtester-and-Quantitative-Analysis-Engine/releases/tag/v1.0.0)**
* `sp500_backtester_engine.sql`: The backend SQL script containing the data pipeline, SMA generation, and compounding logic.
