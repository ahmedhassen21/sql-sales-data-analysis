/* =========================================================
   Project: Sales Data Analysis
   Description:
   This SQL project analyzes sales performance using 
   different analytical techniques such as:

   1. Monthly Sales Trends
   2. Running Totals & Moving Averages
   3. Product Performance Analysis
   4. Category Contribution to Total Sales
   5. Product Cost Segmentation
   6. Customer Segmentation based on Spending Behavior

   Database Schema Used:
   Gold.fact_sales
   Gold.dim_products
   Gold.dim_customers

   Author: Ahmed Hassan
========================================================= */



/* =========================================================
   1. Monthly Sales Performance
   Calculate total sales, number of customers,
   and total quantity per month
========================================================= */

SELECT
    YEAR(order_date)  AS order_year,
    MONTH(order_date) AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM Gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 
    YEAR(order_date),
    MONTH(order_date)
ORDER BY 
    order_year,
    order_month;



/* =========================================================
   Alternative Method Using DATETRUNC
   This provides a cleaner monthly date representation
========================================================= */

SELECT
    DATETRUNC(MONTH, order_date) AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM Gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY order_month;



/* =========================================================
   2. Running Total & Moving Average
   Calculate cumulative sales over time
   and moving average of product prices
========================================================= */

SELECT
    order_date,
    yearly_sales,
    
    SUM(yearly_sales) 
        OVER(ORDER BY order_date) AS running_total_sales,

    AVG(avg_price)
        OVER(ORDER BY order_date) AS moving_avg_price

FROM
(
    SELECT
        DATETRUNC(YEAR, order_date) AS order_date,
        SUM(sales_amount) AS yearly_sales,
        AVG(price) AS avg_price

    FROM Gold.fact_sales
    WHERE order_date IS NOT NULL

    GROUP BY DATETRUNC(YEAR, order_date)

) AS yearly_sales_summary;



/* =========================================================
   3. Product Performance Analysis
   Compare product yearly sales against:

   - Product average sales
   - Previous year's sales
========================================================= */

WITH yearly_product_sales AS
(
    SELECT
        YEAR(S.order_date) AS order_year,
        P.product_name,
        SUM(S.sales_amount) AS current_sales

    FROM Gold.fact_sales S

    LEFT JOIN Gold.dim_products P
        ON P.product_key = S.product_key

    WHERE S.order_date IS NOT NULL

    GROUP BY
        YEAR(S.order_date),
        P.product_name
)

SELECT
    order_year,
    product_name,
    current_sales,

    AVG(current_sales)
        OVER(PARTITION BY product_name) AS avg_sales,

    current_sales - AVG(current_sales)
        OVER(PARTITION BY product_name) AS diff_from_avg,

    CASE
        WHEN current_sales - AVG(current_sales)
             OVER(PARTITION BY product_name) > 0
        THEN 'Above Average'

        WHEN current_sales - AVG(current_sales)
             OVER(PARTITION BY product_name) < 0
        THEN 'Below Average'

        ELSE 'Equal to Average'
    END AS avg_comparison,

    LAG(current_sales)
        OVER(PARTITION BY product_name ORDER BY order_year)
        AS previous_year_sales,

    current_sales - LAG(current_sales)
        OVER(PARTITION BY product_name ORDER BY order_year)
        AS yearly_difference,

    CASE
        WHEN current_sales - LAG(current_sales)
             OVER(PARTITION BY product_name ORDER BY order_year) > 0
        THEN 'Increase'

        WHEN current_sales - LAG(current_sales)
             OVER(PARTITION BY product_name ORDER BY order_year) < 0
        THEN 'Decrease'

        ELSE 'No Change'
    END AS yearly_change

FROM yearly_product_sales

ORDER BY
    product_name,
    order_year;



/* =========================================================
   4. Category Contribution to Total Sales
   Identify which product categories contribute
   the most to overall sales
========================================================= */

WITH category_sales AS
(
    SELECT
        P.category,
        SUM(S.sales_amount) AS total_sales

    FROM Gold.fact_sales S

    LEFT JOIN Gold.dim_products P
        ON S.product_key = P.product_key

    GROUP BY P.category
)

SELECT
    category,
    total_sales,

    SUM(total_sales) OVER() AS overall_sales,

    CONCAT(
        ROUND(
            CAST(total_sales AS FLOAT) /
            SUM(total_sales) OVER() * 100,
            2
        ),
        '%'
    ) AS sales_percentage

FROM category_sales

ORDER BY total_sales DESC;



/* =========================================================
   5. Product Cost Segmentation
   Segment products into different price ranges
========================================================= */

WITH product_segments AS
(
    SELECT
        product_key,
        product_name,
        product_cost,

        CASE
            WHEN product_cost < 100 THEN 'Below 100'
            WHEN product_cost BETWEEN 100 AND 500 THEN '100 - 500'
            WHEN product_cost BETWEEN 500 AND 1000 THEN '500 - 1000'
            ELSE 'Above 1000'
        END AS cost_segment

    FROM Gold.dim_products
)

SELECT
    cost_segment,
    COUNT(product_key) AS product_count

FROM product_segments

GROUP BY cost_segment;



/* =========================================================
   6. Customer Segmentation
   Segment customers based on their spending behavior

   VIP:
   - At least 12 months history
   - Spending > 5000$

   Regular:
   - At least 12 months history
   - Spending <= 5000$

   New:
   - Less than 12 months lifespan
========================================================= */

WITH customer_spending AS
(
    SELECT
        C.customer_key,

        SUM(S.sales_amount) AS total_spending,

        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,

        DATEDIFF(
            MONTH,
            MIN(order_date),
            MAX(order_date)
        ) AS customer_lifespan_months

    FROM Gold.fact_sales S

    LEFT JOIN Gold.dim_customers C
        ON S.customer_key = C.customer_key

    GROUP BY C.customer_key
)

SELECT
    customer_segment,
    COUNT(customer_key) AS total_customers

FROM
(
    SELECT
        customer_key,
        total_spending,
        customer_lifespan_months,

        CASE
            WHEN customer_lifespan_months >= 12
                 AND total_spending > 5000
            THEN 'VIP'

            WHEN customer_lifespan_months >= 12
                 AND total_spending <= 5000
            THEN 'Regular'

            ELSE 'New'
        END AS customer_segment

    FROM customer_spending

) AS segmented_customers

GROUP BY customer_segment

ORDER BY total_customers DESC;
