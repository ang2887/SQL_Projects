/*
Question #1:
return users who have booked and completed at least 10 flights, ordered by user_id.

Expected column names: `user_id`
*/

-- q1 solution:

-- Query to find users, who booked and completed 10 and more flights
SELECT user_id
FROM
-- Subquery to aggregate users by the amount of booked and completed flights
(SELECT s.user_id AS user_id,
       COUNT(s.trip_id) AS num_flights
FROM sessions s
/*Filtering conditions to ensure that the flight was booked, not hotel,
 and booking was not cancelled*/ 
WHERE s.cancellation IS FALSE
      AND s.flight_booked IS TRUE
GROUP BY s.user_id ) AS sub
/*filters results from subquery sub to only include users who have booked 
and completed at least 10 flights */

WHERE  num_flights >= 10
ORDER BY user_id
; 
/*Note: - query using subquery, for separating the aggregation and 
final filtering steps was chosen for potential improved improving performance 
for larger datasets by reducing the amount of data that needs to be processed 
in the final step.
- for potentially leveraging indexes more effectively a single query with
combining the GROUP BY and HAVING clauses.
- no need to include trip_id is not null as filtering condition 
as there no NULLs in trip id where flight_booked is true
*/

     


/*

Question #2: 
Write a solution to report the trip_id of sessions where:

1. session resulted in a booked flight
2. booking occurred in May, 2022
3. booking has the maximum flight discount on that respective day.

If in one day there are multiple such transactions, return all of them.

Expected column names: `trip_id`

*/

-- q2 solution:

/* CTE ranked_discount to return the trip_id of sessions filtered 
on specified conditions and then ranks them within respective day*/

WITH ranked_discount AS(
SELECT  s.trip_id AS trip_id,       
/* Window function DENSE_RANK() ranks trips by the flight discount for
  each unique day where the highest discount gets rank 1.
 If there are multiple trips on the same day with the maximum discount, 
  all of them will be returned. */
  
        DENSE_RANK()OVER(PARTITION BY s.session_start::DATE 
                         ORDER BY s.flight_discount_amount DESC) AS rank
FROM sessions s
-- Filtering trip_id for booked discounted flights happened in May 2022    
WHERE s.flight_booked IS TRUE     
      AND EXTRACT(YEAR FROM  s.session_start) = 2022
      AND EXTRACT(MONTH FROM s.session_start) = 5
      AND s.flight_discount_amount IS NOT NULL
)
/*Main query where the result of CTE ranked_discount is used to filter for
 trip_id of sessions with the top-ranked discounts*/ 
SELECT trip_id
FROM ranked_discount
WHERE rank = 1
;

/* Note: query with the subquery to first filter the sessions based 
on the specified conditions and then ranks them within each day also can be used.
Then outer query will use subquery to filter for the top-ranked sessions (where rank = 1).
CTEs can make complex queries more understandable by breaking them down into logical parts. 
Regarding performance, it's best to test both queries to determine 
which one performs better depending on the database system and the specific execution plan.*/


/*
Question #3: 
Write a solution that will, for each user_id of users with greater than 10 flights, 
find out the largest window of days between 
the departure time of a flight and the departure time 
of the next departing flight taken by the user.

Expected column names: `user_id`, `biggest_window`

*/

-- q3 solution:


/* Query to find the largest window of days between the departure time of a flight 
and the departure time of the next departing flight taken by the user with 
more than 10 flights*/
WITH more_10_flights_users AS(
	/*CTE to aggregate users by the amount of flights taken */
    SELECT s.user_id AS user_id,
         COUNT(trip_id) AS num_flights
	FROM flights f
	    JOIN sessions s USING(trip_id)
	GROUP BY s.user_id
  -- Conditional filtering in HAVING clause for users with greater than 10 flights
	HAVING COUNT(trip_id) > 10
),
/* CTE day_difference to find the difference in days between the actual departure time 
   and the following by chronological order departure time for users from 
   more_10_flights_users CTE */
	day_difference AS(
	SELECT  s.user_id AS user_id,  
  /*  Window function LEAD() returns rows with departure time for the following flight.
    Then LEAD() is used n equation where the actual departure time 
    is subtructed from the result of the Window function LEAD() which is difference
    in days for two subsequent flights.*/  
        	LEAD(f.departure_time::date)OVER(PARTITION BY s.user_id 
                 ORDER BY  f.departure_time::DATE) - f.departure_time::DATE AS day_difference
	FROM flights f
	    JOIN sessions s USING(trip_id)
  /* Condition in WHERE clause uses EXISTS operator to filter for users  with
    at least 10 flights.*/
	WHERE  EXISTS( SELECT 1 FROM more_10_flights_users
               	 WHERE s.user_id = more_10_flights_users.user_id )
)
/*Main query returns users only with the largest gap in days between two
subsequent flights*/
SELECT user_id, day_difference
/* Subquery sub ranks all windows of days between the departure time of a flight 
and the departure time of the next departing flight taken by the user*/
FROM(
			SELECT  user_id,
       				day_difference,
/* Window function DENSE_RANK() assigns ranks to the difference in days between
  two subsequent flights for each user sorted by the largest window coming first.*/
       				DENSE_RANK()OVER(PARTITION BY user_id ORDER BY day_difference DESC) AS rank 
            FROM day_difference
            WHERE day_difference IS NOT NULL) AS sub
/* Filtering for the largest gap between two subsequent flights, where rank = 1
indicates the largest window between them.*/
WHERE rank = 1
;


/*
Question #4: 
Find the user_id’s of people whose origin airport is Boston (BOS) 
and whose first and last flight were to the same destination. 
Only include people who have flown out of Boston at least twice.

Expected column names: user_id
*/

-- q4 solution:

/* Query to identify user_id's of individuals who flew from Boston(BOS) 
to the same destination for their first and last flights, with at least 
two flights departing from Boston.*/
WITH filtered_users AS(
  SELECT u.user_id AS user_id,        
         COUNT(distinct f.trip_id) AS num_flights
  FROM users u
/* Multiple join conditions ensure that flights are counted for users with flights originating 
from 'BOS' and not cancelled, where the trip_id exists in both flights and sessions tables, 
indicating that the trip_id is exclusively for flights, not hotels. */
  	JOIN flights f ON u.home_airport = f.origin_airport AND u.home_airport  = 'BOS'
  	JOIN sessions s ON u.user_id = s.user_id AND s.trip_id = f.trip_id  
 
  GROUP BY  u.user_id   
  HAVING COUNT(distinct f.trip_id) >= 2
)
-- Main query selects users where the first and last flight destinations are the same.
SELECT  distinct user_id 
FROM(
  		SELECT fu.user_id AS user_id,
/* Window functions FIRST_VALUE() and LAST_VALUE() return the first 
and last flight destinations for each user_id in chronological order of flights taken.*/
         		 FIRST_VALUE(f.destination_airport)OVER(PARTITION BY fu.user_id 
                     ORDER BY f.departure_time) AS first_flight, 
         		 LAST_VALUE(f.destination_airport)OVER(PARTITION BY fu.user_id 
                     ORDER BY f.departure_time
                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_flight  
  		FROM filtered_users fu 
  			JOIN sessions s USING(user_id)
  			JOIN flights f ON s.trip_id = f.trip_id) AS sub  
WHERE first_flight =  last_flight 
;
 

