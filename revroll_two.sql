/*
Question #1:

Write a query to find the customer(s) with the most orders. 
Return only the preferred name.

Expected column names: preferred_name
*/

-- q1 solution:


/*This query ranks customers by the number of orders they have placed 
and selects the customer with the highest number of orders.*/

WITH num_orders_ranked AS(
SELECT   c.preferred_name AS preferred_name,        
         COUNT(order_id) AS num_orders,
         DENSE_RANK()OVER(ORDER BY COUNT(*)DESC) AS num_orders_ranked
FROM customers c
JOIN orders o USING(customer_id)
/*Using a composite key in the GROUP BY clause to ensure uniqueness of combination
customer_id-preferred_name-order_id  as a customer with a unique preferred_name 
can have several order_ids*/
GROUP BY c.preferred_name, c.customer_id
)
SELECT preferred_name AS preferred_name
FROM num_orders_ranked 
WHERE num_orders_ranked = 1
;
/* The choice of DENSE_RANK() window function based on its readability and adaptability
to various analysis needs, such as finding min, max, top/bottom n customers 
with the most/least orders without the need for significant changes to the query structure 
in comparison to e.g., nested subqueries.*/




/*
Question #2: 
RevRoll does not install every part that is purchased. 
Some customers prefer to install parts themselves. 
This is a valuable line of business 
RevRoll wants to encourage by finding valuable self-install customers and sending them offers.

Return the customer_id and preferred name of customers 
who have made at least $2000 of purchases in parts that RevRoll did not install. 

Expected column names: customer_id, preferred_name

*/

-- q2 solution:

SELECT c.customer_id AS customer_id, 
       c.preferred_name AS preferred_name
/*LEFT JOIN orders is crucial here to ensure that all orders
installed by RevRoll and those for self-installment are present for analysis*/
FROM  customers c
	INNER JOIN orders o USING(customer_id )
	LEFT JOIN installs i  USING(order_id)
	INNER JOIN parts p USING(part_id)
-- Filtering condition to exclude orders installed by RevRoll 
WHERE i.order_id IS  NULL
/*GROUP BY customer_id is sufficient since the combination of customer_id 
and preferred_name is unique.*/ 
GROUP BY c.customer_id 
/*Filtering the output of aggregation for finding customers
who spent at least $2000 on parts for self-intall*/
HAVING SUM(p.price*o.quantity)>= 2000
ORDER BY customer_id
;
/*Note: The same result could be achieved by using a FULL JOIN between the installs 
and orders tables but might be less efficient in some scenarios(e.g.,large databases)
due to the potential for a larger intermediate result set.*/ 


/*
Question #3: 
Report the id and preferred name of customers who bought an Oil Filter and Engine Oil 
but did not buy an Air Filter since we want to recommend these customers buy an Air Filter.
Return the result table ordered by `customer_id`.

Expected column names: customer_id, preferred_name

*/

-- q3 solution:


/*Query uses chained set operations (INTERSECT and EXCEPT)to find customer_id 
and preferred_name of customers who bought an Oil Filter and Engine Oil 
but did not buy an Air Filter.*/

-- Initial query to find customers who bought an Oil Filter.
SELECT c.customer_id AS customer_id, 
       c.preferred_name AS preferred_name
FROM customers c
		INNER JOIN orders o USING(customer_id)
		INNER JOIN parts p USING(part_id)
WHERE p.name = 'Oil Filter'  

/* First set operation INTERSECT to find common customers  
between Oil Filter and Engine Oil buyers.*/
INTERSECT

-- To find customers who bought an Engine Oil.
SELECT c.customer_id AS customer_id, 
       c.preferred_name AS preferred_name     
FROM customers c
		INNER JOIN orders o USING(customer_id)
		INNER JOIN parts p USING(part_id)
WHERE p.name =  'Engine Oil'

/*Second set operation EXCEPT to exclude customers who bought 
an Air Filter from the previous result.*/
EXCEPT

-- To find customers who bought an Air Filter.
SELECT c.customer_id AS customer_id, 
       c.preferred_name AS preferred_name      
FROM customers c
		INNER JOIN orders o USING(customer_id)
		INNER JOIN parts p USING(part_id)
WHERE p.name =  'Air Filter'
ORDER BY customer_id
;



/*
Question #4: 

Write a solution to calculate the cumulative part summary for every part that 
the RevRoll team has installed.

The cumulative part summary for an part can be calculated as follows:

- For each month that the part was installed, 
sum up the price*quantity in **that month** and the **previous two months**. 
This is the **3-month sum** for that month. 
If a part was not installed in previous months, 
the effective price*quantity for those months is 0.
- Do **not** include the 3-month sum for the **most recent month** that the part was installed.
- Do **not** include the 3-month sum for any month the part was not installed.

Return the result table ordered by `part_id` in ascending order. In case of a tie, order it by `month` in descending order. Limit the output to the first 10 rows.

Expected column names: part_id, month, part_summary
*/

-- q4 solution:


/*This query calculates a cumulative summary for parts over a 3-month period, 
excluding months where no parts were installed.
It uses multiple CTEs to achieve this, including generating a list of all possible 
part-month combinations, calculating the actual total for each part installed in each month, 
and then combining these with the missing installations.*/

WITH month_part_wasnt_installed AS(
/* CROSS JOIN creates 240 rows for 20 unique parts and 12 unique months(Cartesian product)
   as if every part was installed in each month*/
	SELECT  o.part_id, EXTRACT(MONTH FROM i.install_date) AS month,  0 AS part_total
	FROM installs i
		CROSS JOIN orders o 
	GROUP BY 1,2

/*EXCEPT set operation to subtract the actual installations from the generated list 
  to find parts that were not installed in each month.*/
	EXCEPT

/*Query to find which parts in which month were actually installed.*/  
	SELECT  o.part_id,  EXTRACT(MONTH FROM i.install_date) AS month,  0 AS part_total
	FROM installs i
		JOIN orders o USING(order_id)
	GROUP BY 1,2
 
),
-- Part-month combination with the total for each part happened in reality.
monthly_part_summary AS(
	SELECT o.part_id AS part_id,
       	 EXTRACT(MONTH FROM i.install_date) AS month,
         SUM(o.quantity*p.price) AS part_total
	FROM installs i
		INNER JOIN orders o USING(order_id)
		INNER JOIN parts p USING(part_id)
	GROUP BY 1,2 
),
/* CTE combines actually installed parts with corresponding months 
   and sum(o.quantity*p.price) as part_total with those parts which were not 
   installed, and therefore went missing from monthly_part_summary table.
   It is crucial to keep parts-month with 0 sum(o.quantity*p.price) for correct calculation 
   3-month summary without skipping these 0-months. Otherwise, months without 0
   (i.e., months beyond 3-months range) will be added incorrectly.*/ 
   
combined_month_part_info AS(
	SELECT * FROM month_part_wasnt_installed
	UNION ALL
	SELECT * FROM monthly_part_summary
),

--To calculate the cumulative total for each part over a 3-month period.
part_summary AS(
	SELECT part_id AS part_id,
         month AS month,
       	 part_total AS part_total,       
       	 SUM(part_total)OVER(PARTITION BY part_id ORDER BY part_id, month  
                           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW ) AS part_summary
	FROM combined_month_part_info
), 
/*To assign a row number to each part-month combination, ordered by month 
  in descending order, so the most recent month gets row number 1. 
  Filtering condition in WHERE clause to exclude the 3-month sum for any month 
  the part was not installed(part_total <>0) from the cumulative part_total output.*/

row_number AS(
	SELECT part_id AS part_id, 
       month AS month, 
       part_total AS part_total, 
       part_summary AS part_summary,
       ROW_NUMBER()OVER(PARTITION BY part_id ORDER BY part_id, month DESC) AS row_number
	FROM part_summary
	WHERE part_total <>0
) select * from row_number
-- Part_id, month, and part_summary for each part, excluding the most recent month returned.
SELECT part_id, month, part_summary 
FROM row_number
WHERE row_number > 1
ORDER BY part_id, month DESC
LIMIT 10
;
/* An alternative approach involves using the LAG() window function. However, this may 
introduce complexity, as it requires additional lines and the use of COALESCE() 
to handle nulls. This could potentially reduce query readability and efficiency.*/

     
/*Question #1: 
Identify installers who have participated in at least one installer competition by name.

Expected column names: name */

SELECT i.name AS name
FROM install_derby id 
JOIN Installers i on installer_id = id.installer_one_id
UNION
SELECT i.name 
FROM install_derby id 
JOIN Installers i on installer_id = id.installer_two_id

/*Question #2: 
Write a solution to find the third transaction of every customer, 
where the spending on the preceding two transactions is lower 
than the spending on the third transaction. 
Only consider transactions that include an installation, 
and return the result table by customer_id in ascending order.
Expected column names: customer_id, third_transaction_spend, third_transaction_date*/

SELECT c.customer_id, 
       i.install_date, 
	   SUM(o.quantity * p.price)
FROM 
JOIN orders o USING(customer_id)
JOIN installs i USING(order_id)
JOIN parts p USING(part_id)
GROUP by 1,2