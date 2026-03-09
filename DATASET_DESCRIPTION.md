# Dataset Description

This project analyzes a sales dataset using SQL.

## Tables

### fact_sales

Contains transaction-level sales data.

Columns include:

* order_number
* order_date
* product_key
* customer_key
* sales_amount
* quantity
* price

### dim_customers

Contains customer information.

Columns include:

* customer_key
* first_name
* last_name
* gender
* birthdate
* country

### dim_products

Contains product details.

Columns include:

* product_key
* product_name
* category
* subcategory
* product_cost
