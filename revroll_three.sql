/*
Question #1:

Identify installers who have participated in at least one installer competition by name.

Expected column names: name
*/

-- q1 solution:


SELECT name
FROM installers 
/* EXISTS clause checks whether similar installer_id exists in install_derby table 
and returns the related to this id installers.name*/
WHERE EXISTS (
    SELECT 1
    FROM install_derby id
/*Filtering on both installer_one_id and installer_two_id columns
as they contain not the same set of installers ids*/
    WHERE installers.installer_id = id.installer_one_id
          OR installers.installer_id = id.installer_two_id
)
ORDER BY name
;

/* Note: query with EXISTS clause was choosen for it's performance
benefits in comparison to UNION query, and for it's simplicity
in comparison with UNION subquery in EXISTS clause.*/



/*
Question #2: 
Write a solution to find the third transaction of every customer, where the spending on the preceding two transactions is lower than the spending on the third transaction. 
Only consider transactions that include an installation, and return the result table by customer_id in ascending order.

Expected column names: customer_id, third_transaction_spend, third_transaction_date
*/

-- q2 solution:

WITH customer_spend_date_info AS(  
SELECT customer_id AS customer_id,
/* Including install_id is crucial to ensure the connection to transactions being  
 directly linked to installations as task requires in addition to INNER JOINs.*/  
       install_id AS install_id,
       install_date AS transaction_date, 
/* Window function ROW_NUMBER() assigns row number to every transaction within 
   each unique customer_id group sorted by date in asc order.  
   This will help to identify the third transaction for each customer_id.*/
       ROW_NUMBER()OVER(PARTITION BY customer_id ORDER BY install_date) AS row_number,
       SUM(quantity*price) AS third_transaction_spend,
/* Window function LAG() used twice to produce columns with preceding transactions 
   and pre-preceding transactions respectively in regard of the third transaction 
   for each customer_id.*/    
       LAG(SUM(quantity*price), 1) OVER 
              (PARTITION BY customer_id ORDER BY install_date ) AS second_transaction_spend,
       LAG(SUM(quantity*price), 2) over 
               (PARTITION BY customer_id ORDER BY install_date) AS first_transaction_spend
     
FROM installs i
	INNER JOIN orders o USING(order_id)
	INNER JOIN parts p USING(part_id)
GROUP BY customer_id, install_id, transaction_date
) 
SELECT customer_id,
       third_transaction_spend,
       transaction_date AS third_transaction_date
FROM customer_spend_date_info
/* Filtering conditions in the WHERE clause let focusing on the highests transactions 
   in rows #3 only which presents the third transaction for each customer_id.*/
WHERE row_number = 3 
      AND third_transaction_spend > second_transaction_spend 
      AND third_transaction_spend > first_transaction_spend
ORDER BY customer_id
;




/*
Question #3: 
Write a solution to report the **most expensive** part in each order. 
Only include installed orders. In case of a tie, report all parts with the maximum price. 
Order by order_id and limit the output to 5 rows.

Expected column names: `order_id`, `part_id`

*/

-- q3 solution:


WITH parts_ranked AS(
SELECT i.order_id AS order_id,
       p.part_id AS part_id,
/* Window function DENSE_RANK() chosen to return parts arranged by starting from max price 
   coming first within each unique order_id group because it assigns the same rank 
   to rows with the same values.So that, rank 1 assigned to the most expensive part/parts*/
       DENSE_RANK()OVER(PARTITION BY order_id ORDER BY price DESC) AS parts_rank
FROM installs i
/* INNER JOIN to join installs table with orders and parts tables ensures that 
  only orders and parts being installed are dealt with as per task requirement*/ 
	JOIN orders o USING(order_id)
	JOIN parts p USING(part_id)
)
SELECT order_id,
       part_id
FROM parts_ranked
-- Filtering condition to filter out all parts except most expensive(assigned to parts_rank=1).
WHERE parts_rank = 1
ORDER BY order_id
LIMIT 5
;
/* Note: Currently, the query returns all parts with the maximum value.
   Extra criteria might be added to handle ties, or using a different ranking function 
   that leaves gaps in the ranking sequence, if necessary.*/

/*
Question #4: 
Write a query to find the installers who have completed installations for at least four consecutive days. 
Include the `installer_id`, start date of the consecutive installations period and the end date of the consecutive installations period. 

Return the result table ordered by `installer_id` in ascending order.

E**xpected column names: `installer_id`, `consecutive_start`, `consecutive_end`**
*/

-- q4 solution:

/*Question #4: 
Write a query to find the installers who have completed installations 
for at least four consecutive days. 
Include the installer_id, start date of the consecutive installations period 
and the end date of the consecutive installations period. 
Return the result table ordered by installer_id in ascending order.
Expected column names: installer_id, consecutive_start, consecutive_end*/


WITH installer_date_info AS(
SELECT installer_id as installer_id, 
       install_date AS install_date,
/* Window function LEAD() with offset of 3 is used to look ahead three rows 
   from the current row, effectively identifying the fourth installation date 
   for each installer with dates arranged in calendar order*/ 
       LEAD(install_date, 3)
       OVER(PARTITION BY installer_id ORDER BY install_date) AS install_date_4,
/* Equasion to find how many days passed between the first and fourth installations.
   It helps in determining if there are exactly three days between the first and fourth 
   installations, which is the condition for identifying consecutive installations.*/
       LEAD(install_date, 3)
       OVER(PARTITION BY installer_id ORDER BY install_date) - install_date AS days_difference
FROM installs
/* Grouping by installer_id and install_date is necessary to to ensure the unique 
  combination of installer_id and install_date */
GROUP BY installer_id, install_date
)
SELECT installer_id,
       install_date AS consecutive_start,
       install_date_4 AS consecutive_end
FROM installer_date_info
/* Filtering condition in WHERE clause to ensure that there passed exactly three days
   and not more between 4 instalaltions is crucial for filtering out 
   installations that are not part of a consecutive period of at least four days.*/  
WHERE days_difference = 3
ORDER BY installer_id 
;





