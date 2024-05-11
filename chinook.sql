/*
Question #1:
Write a solution to find the employee_id of managers with at least 2 direct reports.


Expected column names: employee_id

*/

-- q1 solution:

-- Query to retrieve manager employee IDs with at least 2 direct reports.
SELECT e.reports_to AS employee_id
FROM employee e
GROUP BY e.reports_to
HAVING  COUNT(e.reports_to) >= 2
ORDER BY employee_id

/*Note: This is a shortest solution, and possibly the most efficient
as the reports_to column is indexed*/


/*

Question #2: 
Calculate total revenue for MPEG-4 video files purchased in 2024.

Expected column names: total_revenue

*/

-- q2 solution:

-- Query to find the total revenue from MPEG-4 video file purchases in 2024.
SELECT SUM(il.unit_price*il.quantity) AS total_revenue
FROM media_type m 

-- Join operations to connect all relevant tables and select columns of interest.
	JOIN track t USING(media_type_id)
	JOIN invoice_line il USING(track_id)
	JOIN invoice i USING(invoice_id)

/* Filtering criteria: 
   - Video type media files identified using the LIKE keyword and the media_type.name column.
   - Purchases made in 2024, determined by extracting the year from the invoice_date column.*/
WHERE   m.media_type_id IN (SELECT media_type_id 
                            FROM media_type 
                            WHERE name LIKE'%video%')
        AND EXTRACT(YEAR FROM i.invoice_date) = 2024 
-- Grouping total revenue by media_type_id to aggregate the revenue for video type media files.

GROUP BY m.media_type_id 
;


/*
Question #3: 
For composers appearing in classical playlists, count the number of distinct playlists they appear on and 
create a comma separated list of the corresponding (distinct) playlist names.

Expected column names: composer, distinct_playlists, list_of_playlists

*/

-- q3 solution:


/*Query to count the number of distinct playlists and return a list
of classical playlists for composers*/
SELECT  t.composer AS composer,
-- Counting unique playlists per each composer, filtered for classical playlists
        COUNT(DISTINCT p.playlist_id) AS distinct_playlists,
/*Concatenating a list of classical playlist names using the STRING_AGG function, 
filtered for classical playlists. */
        STRING_AGG(p.name, ',') AS list_of_playlists

FROM track t
-- Join operations to connect all relevant tables and select columns of interest.
		JOIN playlist_track pt USING(track_id)        
		JOIN playlist p USING(playlist_id)
/*Filtering out playlists without a composer, filtering for only 
classical playlists*/
WHERE t.composer IS NOT NULL
      AND p.name ILIKE '%classical%' 
GROUP BY composer
ORDER BY composer
;


/*
Question #4: 
Find customers whose yearly total spending is strictly increasing*.


*read the hints!


Expected column names: customer_id
*/

-- q4 solution:



-- Query to identify customers whose annual spending demonstrates a consistent upward trend
-- CTE to group customers by their annual total spending excluding the year 2025.
WITH customer_year_spenging AS(
SELECT  i.customer_id AS customer_id,
        EXTRACT(YEAR FROM i.invoice_date) AS year,
        SUM(total) AS total_spending
FROM invoice i

WHERE  EXTRACT(YEAR FROM i.invoice_date) < 2025
GROUP BY customer_id, year
),
/*CTE to rank customers in two ways: 1. by the chronological year(year_rank)
and  2.by increasing spending order(spending_rank)*/
rank AS (
    SELECT customer_id,
           year,
           total_spending,
           RANK()OVER(PARTITION BY customer_id ORDER BY customer_id, YEAR) AS year_rank,
           RANK()OVER(PARTITION BY customer_id ORDER BY total_spending) AS spending_rank 
    FROM customer_year_spenging
  
),
/* CTE to concatenate ranks of each customer for each year to create a pattern 
for further comparison */
concatenated_ranks AS (
    SELECT customer_id,
           STRING_AGG(year_rank::TEXT, '') AS concat_year_rank,
           STRING_AGG(spending_rank::TEXT,'') AS concat_spending_rank
           
    FROM rank
    GROUP BY customer_id
) 
/* Main query filters customers where strictly increasing patterns coincide 
with their actual spending pattern. */
SELECT customer_id

FROM concatenated_ranks

WHERE concat_year_rank = concat_spending_rank

ORDER BY customer_id
;

/* Note: Depending on the specific database system's optimisation, the use of a query 
performing a single aggregation and the INTERSECT operator for filtering before 
aggregation might be preferable. */


