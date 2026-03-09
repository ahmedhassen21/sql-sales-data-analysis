/*
===========================================================
Customer Report View
===========================================================
Purpose:
    - Consolidates key customer metrics and behavior

Highlights:
    1. Gathers essential fields such as name, age, and transaction details
    2. Segments customers into categories (VIP, Regular, New) and age groups
    3. Aggregates customer-level metrics:
        - Total orders
        - Total sales
        - Total quantity purchased
        - Total distinct products
        - Customer lifespan (in months)
    4. Calculates valuable KPIs:
        - Recency (months since last order)
        - Average order value
        - Average monthly spend
===========================================================
*/

CREATE OR ALTER VIEW Gold.report_customers AS 

WITH base_query AS (
    /*-------------------------------------------------------------
    1) Base Query: Retrieves core columns from sales and customer tables
    -------------------------------------------------------------*/
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age
    FROM Gold.fact_sales f
    LEFT JOIN Gold.dim_customers c
        ON c.customer_key = f.customer_key
    WHERE f.order_date IS NOT NULL
),

customer_aggregation AS (
    /*-------------------------------------------------------------
    2) Customer Aggregations: Summarizes key metrics at the customer level
    -------------------------------------------------------------*/
    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_spending,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order,
        MIN(order_date) AS first_order,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS customer_lifespan_months
    FROM base_query
    GROUP BY
        customer_key,
        customer_number,
        customer_name,
        age
)

SELECT
    customer_key,
    customer_number,
    customer_name,
    age,

    /* Age Segmentation */
    CASE
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'
    END AS age_segmentation,

    /* Customer Segment based on lifespan and spending */
    CASE
        WHEN customer_lifespan_months >= 12 AND total_spending > 5000 THEN 'VIP'
        WHEN customer_lifespan_months >= 12 AND total_spending <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,

    last_order,
    DATEDIFF(MONTH, last_order, GETDATE()) AS recency,
    total_orders,
    total_spending,
    total_quantity,
    total_products,

    /* Compute Average Order Value */
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_spending / total_orders
    END AS avg_order_value,

    /* Compute Average Monthly Spend */
    CASE  
        WHEN customer_lifespan_months = 0 THEN total_spending
        ELSE total_spending / customer_lifespan_months
    END AS avg_monthly_spend

FROM customer_aggregation;
