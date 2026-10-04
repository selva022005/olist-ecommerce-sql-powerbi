-- Query 1:

SELECT COUNT(DISTINCT o.order_id) AS total_orders,
       ROUND(SUM(oi.price), 2) AS total_revenue,
       ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';

-- Query 2:

SELECT DATE_FORMAT(o.purchase_ts, '%Y-%m') AS month,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price), 2) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.purchase_ts, '%Y-%m')
ORDER BY month;


-- Query 3:

SELECT order_status, COUNT(*) AS orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- Query 4

SELECT t.product_category_name_english AS category,
       ROUND(SUM(oi.price), 2) AS revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN category_translation t ON p.product_category_name = t.product_category_name
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY t.product_category_name_english
ORDER BY revenue DESC
LIMIT 10;

-- Query 5:

SELECT c.customer_state,
       ROUND(SUM(oi.price), 2) AS revenue,
       COUNT(DISTINCT o.order_id) AS orders
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC;


-- Query 6:

SELECT payment_type, 
       COUNT(*) AS num_payments,
       ROUND(SUM(payment_value), 2) AS total_value
FROM payments
GROUP BY payment_type
ORDER BY total_value DESC;

-- Query 7:

CREATE INDEX idx_oi_seller_id ON order_items(seller_id(32));

SELECT s.seller_id,
       ROUND(SUM(oi.price), 2) AS revenue,
       COUNT(DISTINCT oi.order_id) AS orders
FROM order_items oi
JOIN sellers s ON oi.seller_id = s.seller_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id
ORDER BY revenue DESC
LIMIT 10;


-- Query 8:

SELECT ROUND(AVG(DATEDIFF(delivered_customer_ts, purchase_ts)), 1) AS avg_delivery_days
FROM orders
WHERE order_status = 'delivered' AND delivered_customer_ts IS NOT NULL;


-- Query 9:

SELECT 
  ROUND(100 * SUM(CASE WHEN delivered_customer_ts > estimated_delivery_ts THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_late
FROM orders
WHERE order_status = 'delivered' AND delivered_customer_ts IS NOT NULL;


-- Query 10:

CREATE INDEX idx_reviews_order_id ON reviews(order_id(32));

SELECT t.product_category_name_english AS category,
       ROUND(AVG(r.review_score), 2) AS avg_review_score,
       COUNT(*) AS num_reviews
FROM reviews r
JOIN orders o ON r.order_id = o.order_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN category_translation t ON p.product_category_name = t.product_category_name
GROUP BY t.product_category_name_english
ORDER BY avg_review_score DESC
LIMIT 10;


-- Query 11:

WITH monthly_revenue AS (
  SELECT DATE_FORMAT(o.purchase_ts, '%Y-%m') AS month,
         ROUND(SUM(oi.price), 2) AS revenue
  FROM orders o
  JOIN order_items oi ON o.order_id = oi.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY DATE_FORMAT(o.purchase_ts, '%Y-%m')
)
SELECT month,
       revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
       ROUND(
         (revenue - LAG(revenue) OVER (ORDER BY month)) / LAG(revenue) OVER (ORDER BY month) * 100
       , 1) AS pct_growth
FROM monthly_revenue
ORDER BY month;


-- Query 12:

WITH customer_orders AS (
  SELECT c.customer_unique_id,
         COUNT(DISTINCT o.order_id) AS order_count
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id
)
SELECT 
  COUNT(*) AS total_customers,
  SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
  ROUND(100 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_repeat
FROM customer_orders;



-- Query 13:

WITH state_category_revenue AS (
  SELECT c.customer_state,
         t.product_category_name_english AS category,
         ROUND(SUM(oi.price), 2) AS revenue
  FROM order_items oi
  JOIN orders o ON oi.order_id = o.order_id
  JOIN customers c ON o.customer_id = c.customer_id
  JOIN products p ON oi.product_id = p.product_id
  JOIN category_translation t ON p.product_category_name = t.product_category_name
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_state, t.product_category_name_english
)
SELECT customer_state, category, revenue, rnk
FROM (
  SELECT *,
         RANK() OVER (PARTITION BY customer_state ORDER BY revenue DESC) AS rnk
  FROM state_category_revenue
) ranked
WHERE rnk = 1
ORDER BY revenue DESC;