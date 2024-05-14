/*
Question #1: 
Installers receive performance based year end bonuses. Bonuses are calculated by taking 10% of the total value of parts installed by the installer.

Calculate the bonus earned by each installer rounded to a whole number. Sort the result by bonus in increasing order.

Expected column names: name, bonus
*/

-- q1 solution:

/*
CTE to calculate the value of parts installed by each installer.
 Separating the task into two queries helps to spot potential issues with numerous joins,
 enhances maintenance and readability.
 The main query calculates the bonuses based on 10% taken 
 of the total value of parts  for each installer
 */
   
WITH installer_part_value AS (

 SELECT i.name AS name,
        p.price * o.quantity AS total_parts_value
 
  FROM parts AS p        
 		INNER JOIN orders AS o ON o.part_id = p.part_id
    INNER JOIN installs AS ins ON o.order_id = ins.order_id
    INNER JOIN installers AS i ON ins.installer_id = i.installer_id
)

SELECT iv.name AS name,
       ROUND((SUM(iv.total_parts_value) * 0.1)) AS bonus

FROM installer_part_value AS iv
GROUP BY name
ORDER BY bonus ASC;

/* Other considerations:
If prioritising performance and simplicity is a key, and if the calculation of bonuses 
is not reused further, then single query option might be more suitable.*/




/*
Question #2: 
RevRoll encourages healthy competition. The company holds a “Install Derby” where installers 
face off to see who can change a part the fastest in a tournament style contest.

Derby points are awarded as follows:

- An installer receives three points if they win a match (i.e., Took less time to install the part).
- An installer receives one point if they draw a match (i.e., Took the same amount of time as their opponent).
- An installer receives no points if they lose a match (i.e., Took more time to install the part).

We need to calculate the scores of all installers after all matches. Return the result table ordered by `num_points` in decreasing order. 
In case of a tie, order the records by `installer_id` in increasing order.

Expected column names: `installer_id`, `name`, `num_points`

*/

-- q2 solution:

/*
Three subqueries within a WITH clause to calculate points for each of two installers
separately and combining them into the third query to handle cases where not every id
from installer_one_id column is present in the set of ids from installer_two_id column.
*/ 

WITH installers_one_points AS(
  -- Calculate points for installer one based on time comparison with installer two.
  SELECT id.installer_one_id AS installer_id,
         i.name AS name,
         CASE WHEN id.installer_one_time < id.installer_two_time THEN   3
              WHEN id.installer_one_time = id.installer_two_time THEN   1
              ELSE   0
         END AS points
  FROM install_derby id
  LEFT JOIN installers i ON id.installer_one_id = i.installer_id
),

installers_two_points AS(
  -- Calculate points for installer two based on time comparison with installer one.
  SELECT id.installer_two_id AS installer_id,
         i.name AS name,
         CASE WHEN id.installer_two_time < id.installer_one_time THEN   3
              WHEN id.installer_two_time = id.installer_one_time THEN   1
              ELSE   0
         END AS points
  FROM install_derby id
  LEFT JOIN installers i ON id.installer_two_id = i.installer_id
),

combined_installers_points AS(
  
  SELECT * FROM installers_one_points
  UNION ALL
  SELECT * FROM installers_two_points
)

/*
Calculate the total points for each installer, handling NULL values originating
FROM FULL JOIN with COALESCE function for installers who did not participate
in the derby, ensuring that their installer_id and name are displayed.
*/
SELECT COALESCE(ci.installer_id, i.installer_id) AS installer_id,
       COALESCE(ci.name, i.name) AS name,
       COALESCE(SUM(points), 0) AS num_points
       
FROM combined_installers_points ci
FULL JOIN installers i ON ci.installer_id = i.installer_id

GROUP BY COALESCE(ci.installer_id, i.installer_id),
         COALESCE(ci.name, i.name)
ORDER BY num_points DESC, installer_id ASC;


/*
Question #3:

Write a query to find the fastest install time with its corresponding `derby_id` for each installer. 
In case of a tie, you should find the install with the smallest `derby_id`.

Return the result table ordered by `installer_id` in ascending order.

Expected column names: `derby_id`, `installer_id`, `install_time`
*/

-- q3 solution:


/*
CTE calculates the minimum install time for each installer in two separate subqueries
and combines them with UNION ALL. 
This is necessary because not every ID from the installer_one_id column  
is present in the set of IDs from the installer_two_id column.
*/

WITH combined_installers_min_time AS(
  
    -- Subquery to calculate the minimum install time for installer_one_id for each derby_id.  
    SELECT derby_id AS derby_id,
           installer_one_id AS installer_id,
           MIN(installer_one_time) AS install_time
  
    FROM install_derby 
    GROUP BY derby_id, installer_id

    UNION ALL 

    -- Subquery to calculate the minimum install time for installer_two_id for each derby_id.
    SELECT derby_id AS derby_id,
           installer_two_id AS installer_id,
           MIN(installer_two_time) AS install_time
  
    FROM install_derby 
    GROUP BY derby_id, installer_id
), 
/*
CTE assigns a rank to each record within each installer_id group based on the install_time
and handling a tie for the installer_id by ordering derby_id ASC.
*/

rank AS(
    SELECT *,
      ROW_NUMBER() OVER(PARTITION BY ci.installer_id ORDER BY ci.install_time ASC, derby_id ASC) AS rank
  
    FROM combined_installers_min_time ci
)
/*The main query selects the records with the minimum install_time for each installer_id
based on the lowest(#1) assigned rank.*/
SELECT r.derby_id AS derby_id,
       r.installer_id AS installer_id,
       r.install_time AS install_time
       
FROM rank r
WHERE r.rank = 1
ORDER BY r.installer_id ASC; 

/*
Other considerations:
If performance and simplicity are key factors, and if the calculation of the minimum install time 
for each installer is not reused further, then the option with the separate CTEs 
for installer's min time might be the better choice.
*/




/*
Question #4: 
Write a solution to calculate the total parts spending by customers paying for installs on each Friday of every week in November 2023. 
If there are no purchases on the Friday of a particular week, the parts total should be set to `0`.

Return the result table ordered by week of month in ascending order.

Expected column names: `november_fridays`, `parts_total`
*/

-- q4 solution:

/*
To calculate total parts spending for installations on Fridays in November 2023,
using subquery as a filter in WHERE clause
*/
SELECT DISTINCT i.install_date AS november_fridays, 
       COALESCE(SUM(o.quantity * p.price), 0) AS parts_total  -- Handling NULLS if no purchases.

FROM installs AS i
LEFT JOIN orders AS o ON o.order_id = i.order_id  
LEFT JOIN parts AS p ON p.part_id = o.part_id  

WHERE i.install_date IN  
              (
                SELECT DISTINCT install_date AS november_fridays
                FROM installs
                WHERE EXTRACT(DOW FROM installs.install_date) = 5  -- Filter for Fridays.
                AND EXTRACT(MONTH FROM installs.install_date) = 11  -- Filter for November.
              )
GROUP BY i.install_date  
ORDER BY i.install_date;  


