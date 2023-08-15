{
  "metadata": {
    "language_info": {
      "codemirror_mode": "sql",
      "file_extension": "",
      "mimetype": "",
      "name": "sql",
      "version": "3.32.3"
    },
    "kernelspec": {
      "name": "SQLite",
      "display_name": "SQLite",
      "language": "sql"
    }
  },
  "nbformat_minor": 4,
  "nbformat": 4,
  "cells": [
    {
      "cell_type": "code",
      "source": "--Query 01: calculate total visit, pageview, transaction for Jan, Feb and March 2017 order by month\n\nSELECT \n  FORMAT_DATE('%Y%m',PARSE_DATE('%Y%m%d',date)) as month,\n  SUM(totals.visits) as visits,\n  SUM(totals.pageviews) as pageviews,\n  SUM(totals.transactions) as transaction\nFROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`\nWHERE _table_suffix between '0101' and '0331'\nGROUP BY month \nORDER BY month\n\n--Query 02: Bounce rate per traffic source in July 2017 (Bounce_rate = num_bounce/total_visit) order by total_visit DESC\n\nSELECT \n  trafficSource.source as source,\n  sum(totals.visits) as total_visits,\n  sum(totals.bounces) as total_no_of_bounces,\n  ROUND(100* (sum(totals.bounces) / sum(totals.visits)),8) as bounce_rate\nFROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*` \nGROUP BY source\nORDER BY total_visits DESC\n\n--Query 3: Revenue by traffic source by week, by month in June 2017\n\nSELECT \n  'Month' as time_type,\n  FORMAT_DATE('%Y%m',PARSE_DATE('%Y%m%d',date)) as time,\n  trafficSource.source as source,\n  sum(productRevenue) as revenue\nFROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,\nUNNEST(hits) hits,\nUNNEST (hits.product) product\nWHERE productRevenue IS NOT NULL\nGROUP BY time, source\nUNION ALL\nSELECT \n 'Week' as time_type,\n FORMAT_DATE('%Y%W',PARSE_DATE('%Y%m%d',date)) as time,\n trafficSource.source as source,\n  sum(productRevenue) as revenue\nFROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,\nUNNEST(hits) hits,\nUNNEST (hits.product) product\nWHERE productRevenue IS NOT NULL\nGROUP BY time, source\n\n--Query 04: Average number of pageviews by purchaser type (purchasers vs non-purchasers) in June, July 2017.\n\nWITH purchase AS (\n    SELECT\n      FORMAT_DATE('%Y%m',PARSE_DATE('%Y%m%d', date)) as month,\n      ROUND(sum(totals.pageviews)/count(distinct fullVisitorId),5) as age_pageviews_purchase\n  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,\n  UNNEST(hits) hits,\n  UNNEST (hits.product) product\n    WHERE _table_suffix between '0601' and '0731'\n    AND totals.transactions >= 1,\n    AND product.productRevenue IS NOT NULL\n    GROUP BY month ),\n  non_purchase as (\n    SELECT\n      FORMAT_DATE('%Y%m',PARSE_DATE('%Y%m%d', date)) as month,\n      ROUND(sum(totals.pageviews)/count (distinct fullVisitorId),5) as age_pageviews_non_purchase\n    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,\n    UNNEST(hits) hits,\n    UNNEST (hits.product) product\n      WHERE _table_suffix between '0601' and '0731'\n      AND totals.transactions IS NULL\n      AND product.productRevenue IS NULL\n      GROUP BY month )\n\nSELECT\n  purchase.month,\n  purchase.age_pageviews_purchase,\n  non_purchase.age_pageviews_non_purchase\nFROM purchase\nJOIN non_purchase USING(month)\n\n--Query 05: Average number of transactions per user that made a purchase in July 2017\n\nWITH avg_num_transactions AS (\n    SELECT\n        FORMAT_DATE('%Y%m',PARSE_DATE('%Y%m%d',date)) as month,\n        fullVisitorId,\n        SUM (totals.transactions) AS total_transactions_per_user,\n    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,\n    UNNEST(hits) hits,\n    UNNEST (hits.product) product\n    WHERE productRevenue IS NOT NULL\n    GROUP BY fullVisitorId, month\n)\n\nSELECT \n    month,\n    (SUM (total_transactions_per_user) / COUNT(fullVisitorId) ) AS avg_total_transactions_per_user\nFROM avg_num_transactions\nGROUP BY month\n\n--Query 06: Average amount of money spent per session. Only include purchaser data in July 2017\n\nWITH avg_amount AS (\n  SELECT \n    FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d',date)) as month,\n    fullVisitorId,\n    SUM(totals.visits) AS total_visit,\n    SUM(product.productRevenue) AS total_revenue\n  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,\n  UNNEST(hits) hits,\n  UNNEST (hits.product) product\n    WHERE productRevenue IS NOT NULL\n    AND totals.transactions IS NOT NULL\n    AND totals.visits > 0\n    AND totals.totalTransactionRevenue IS NOT NULL\n    GROUP BY month, fullVisitorId\n)\nSELECT month,\n(SUM(total_revenue) / SUM(total_visit) /1000000) as avg_revenue_by_user_per_visit\nFROM avg_amount\nGROUP BY month\n\n--Query 07: Other products purchased by customers who purchased product \"YouTube Men's Vintage Henley\" in July 2017. Output should show product name and the quantity was ordered.\n\nSELECT \n    v2ProductName AS other_purchased_products, \n    SUM(productQuantity) AS quantity\n  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,\n  UNNEST(hits) hits,\n  UNNEST (hits.product) product\n  WHERE v2ProductName != \"YouTube Men's Vintage Henley\"\n  AND productRevenue IS NOT NULL\n  AND fullVisitorID IN\n  ( \n    SELECT fullVisitorId\n    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,\n    UNNEST(hits) hits,\n    UNNEST (hits.product) product\n    WHERE v2ProductName = \"YouTube Men's Vintage Henley\"\n    AND productRevenue IS NOT NULL\n  )\n  GROUP BY other_purchased_products\n  ORDER BY quantity DESC\n\n--Query 08: Calculate cohort map from product view to addtocart to purchase in Jan, Feb and March 2017. For example, 100% product view then 40% add_to_cart and 10% purchase.\n\nWITH product_view as (\n    SELECT\n      FORMAT_DATE(\"%Y%m\",PARSE_DATE('%Y%m%d',date)) as month,\n      COUNT(product.productSKU) as num_product_view\n    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,\n    UNNEST(hits) as hits,\n    UNNEST(product) as product\n    WHERE _table_suffix between '0101' and '0331'\n  AND eCommerceAction.action_type = '2'\n    GROUP BY month\n), \n\n  addtocart as (\n    SELECT\n      FORMAT_DATE(\"%Y%m\",PARSE_DATE('%Y%m%d',date)) as month,\n      COUNT(product.productSKU) as num_add_to_cart\n    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,\n    UNNEST(hits) as hits,\n    UNNEST(product) as product\n    WHERE _table_suffix between '0101' and '0331'\n    AND eCommerceAction.action_type = '3'\n    GROUP BY month\n),\n\n  purchase as (\n    SELECT\n      FORMAT_DATE(\"%Y%m\",PARSE_DATE('%Y%m%d',date)) as month,\n      COUNT(product.productSKU) as num_purchase\n    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,\n    UNNEST(hits) as hits,\n    UNNEST(product) as product\n    WHERE _table_suffix between '0101' and '0331'\n    AND eCommerceAction.action_type = '6'\n    AND product.productRevenue IS NOT NULL\n    GROUP BY month\n)\n\nSELECT\n    product_view.month,\n    product_view.num_product_view,\n    addtocart.num_add_to_cart,\n    purchase.num_purchase,\n    ROUND((num_add_to_cart/num_product_view)*100,2) as add_to_cart_rate,\n    ROUND((num_purchase/num_product_view)*100,2) as purchase_rate\nFROM product_view\nJOIN addtocart USING(month)\nJOIN purchase USING(month)\nORDER BY month\n",
      "metadata": {},
      "execution_count": null,
      "outputs": []
    }
  ]
}