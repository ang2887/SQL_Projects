/*
Question #1:
Calculate the number of flights with a departure time during the work week (Monday through Friday) and the number of flights departing during the weekend (Saturday or Sunday).

Expected column names: working_cnt, weekend_cnt
*/

-- q1 solution:


/* Query to calculate the distribution of flights between 
 workweek days (Monday to Friday) and weekend days (Saturday and Sunday).
The FILTER clause is used to count flights on weekdays and weekends separately.
EXTRACT function with ISODOW option is used to extract the day of the week as an integer,
adhering to the ISO 8601 standard (Monday is 1, Sunday is 7).*/


SELECT COUNT(*)FILTER(WHERE EXTRACT(ISODOW FROM f.departure_time) IN (1,2,3,4, 5)) AS working_cnt,
       COUNT(*)FILTER(WHERE EXTRACT(ISODOW FROM f.departure_time) IN (6, 7)) AS weekend_cnt
FROM flights f
;
/* Notes:
- For systems with representing Sunday as 0 and Saturday as 6 
  using DOW function is recommended.
- For better portability across different SQL databases, consider the use 
  of a CASE statement with SUM function. */



/*

Question #2: 
For users that have booked at least 2  trips with a hotel discount, it is possible to calculate their average hotel discount, and maximum hotel discount. write a solution to find users whose maximum hotel discount is strictly greater than the max average discount across all users.

Expected column names: user_id

*/

-- q2 solution:




/* Query to find users who have booked 2 or more trips with a hotel discount 
and whose maximum hotel discount is strictly greater 
than the max average discount across all users.*/

/*CTE to filter sessions for valid bookings with a hotel discount and 
no cancellations. Important to make sure that trip_id IS NOT NULL
as they associated with s.cancellation IS FALSE.*/ 
WITH filtered_data AS(
	SELECT s.*

	FROM sessions s 
	WHERE s.trip_id IS NOT null 
        AND s.hotel_discount IS true 
        AND s.cancellation IS false
),
/*To identify users who have booked at least 2 trips based on CTE filtered_data 
with adequately processed data.*/

	users_2_more_trips AS(
	SELECT fd.user_id AS user_id,
           COUNT(DISTINCT fd.trip_id) AS num_trips

    FROM filtered_data fd
    GROUP BY fd.user_id
    -- To filter for users with at least two trips booked.   
    HAVING COUNT(DISTINCT fd.trip_id) >= 2 
), 

-- To calculate average and maximum hotel discount per each user separately.
person_discounts AS (
	SELECT fd.user_id AS user_id, 
	       fd.hotel_discount_amount AS hotel_discount,
           ROUND(AVG(fd.hotel_discount_amount)
                 OVER(PARTITION BY fd.user_id ), 3) AS avg_person_discount,
            ROUND(MAX(fd.hotel_discount_amount) 
                 OVER(PARTITION BY fd.user_id), 3) AS max_person_discount 

    FROM filtered_data fd
 -- Filtering for only users who met filtering criteria in CTE users_2_more_trips.  
    WHERE fd.user_id IN (SELECT DISTINCT user_id FROM users_2_more_trips) 

),

-- To find the maximum average hotel discount across all users.
max_avg_person_discount AS(
	SELECT ROUND(MAX(pd.avg_person_discount), 3) AS max_avg_person_discount

	FROM person_discounts pd 
)
/*Final query  to return users whose maximum hotel discount is strictly greater 
than the max average discount across all users with subquery in WHERE clause
to set comparison criterion providing maximum of avgerage person discounts.*/
SELECT DISTINCT user_id

FROM person_discounts
WHERE max_person_discount > (SELECT max_avg_person_discount FROM max_avg_person_discount)
ORDER BY user_id 
;

/* Using ROUND function is not strictly necessary for this solution, however it might improve
readibility should this code be adapted for different tasks*/


/*
Question #3: 
when a customer passes through an airport we count this as one “service”.

for example:

suppose a group of 3 people book a flight from LAX to SFO with return flights. In this case the number of services for each airport is as follows:

3 services when the travelers depart from LAX

3 services when they arrive at SFO

3 services when they depart from SFO

3 services when they arrive home at LAX

for a total of 6 services each for LAX and SFO.

find the airport with the most services.

Expected column names: airport

*/

-- q3 solution:

/*CTE to calculate the number of services per airport, considering both 
departures and arrivals, and distinguishing between return and one-way flights.*/

/* CTE to return the number of services per airport using chained with UNION ALL
operators.*/
WITH services_per_airport_info AS (
	SELECT f.origin_airport AS airport,
/* Number of seats booked equals number of passengers deparrting from origin_airport.
Multiplication by two reflects the fact that this airport is used twice since
this is return flight.*/
       	  SUM(f.seats)*2 AS num_services    

	FROM flights f

	WHERE f.return_time IS NOT NULL
	GROUP BY f.origin_airport

	UNION ALL

	SELECT f.destination_airport AS airport,
           SUM(f.seats)*2 AS num_services 

	FROM flights f
	WHERE f.return_time IS NOT NULL
	GROUP BY f.destination_airport

	UNION ALL

	SELECT f.origin_airport AS airport,
           SUM(f.seats) AS num_services

	FROM flights f
	WHERE f.return_time IS  NULL
	GROUP BY f.origin_airport

	UNION ALL

	SELECT f.destination_airport AS airport,
           SUM(f.seats) AS num_services 

	FROM flights f
	WHERE f.return_time IS  NULL
	GROUP BY f.destination_airport
)
-- Main query to identify the airport with the highest total number of services.
SELECT airport
FROM(
/*Subquery to aggregate total services per airport and order by the total number 
of services in descending order.The top line presents the airport with
max number of services.*/
			SELECT airport AS airport,
                   SUM(num_services) AS total_num_services
			FROM services_per_airport_info
			GROUP BY airport 
			ORDER BY total_num_services DESC
			LIMIT 1) as sub
;
 /* Note: to efficiently address possible ties DENSE_RANK() window 
 function will be preferable.*/

/*
Question #4: 
using the definition of “services” provided in the previous question, we will now rank airports by total number of services. 

write a solution to report the rank of each airport as a percentage, where the rank as a percentage is computed using the following formula: 

`percent_rank = (airport_rank - 1) * 100 / (the_number_of_airports - 1)`

The percent rank should be rounded to 1 decimal place. airport rank is ascending, such that the airport with the least services is rank 1. If two airports have the same number of services, they also get the same rank.

Return by ascending order of rank

E**xpected column names: airport, percent_rank**

Expected column names: airport, percent_rank
*/

-- q4 solution:

/*CTE to calculate the number of services per airport, considering both 
departures and arrivals, and distinguishing between return and one-way flights.*/
/* CTE to return the number of services per airport using chained with UNION ALL
operators.*/
WITH services_per_airport_info AS (
	SELECT f.origin_airport AS airport,
/* Number of seats booked equals number of passengers deparrting from origin_airport.
   Multiplication by two reflects the fact that this airport is used twice since
   this is return flight.*/
       	 SUM(f.seats)*2 AS num_services       
	FROM flights f
	WHERE f.return_time IS NOT NULL
	GROUP BY f.origin_airport

	UNION ALL

	SELECT f.destination_airport AS airport,
         SUM(f.seats)*2 AS num_services       
	FROM flights f
	WHERE f.return_time IS NOT NULL
	GROUP BY f.destination_airport

	UNION ALL

	SELECT f.origin_airport AS airport,
         SUM(f.seats) AS num_services       
	FROM flights f
	WHERE f.return_time IS  NULL
	GROUP BY f.origin_airport

	UNION ALL

	SELECT f.destination_airport AS airport,
         SUM(f.seats) AS num_services       
	FROM flights f
	WHERE f.return_time IS  NULL
	GROUP BY f.destination_airport
),
/*CTE to calculate the total number of services per airport and their percent rank.*/
percent_rank as(
   SELECT airport AS airport,
   SUM(num_services) AS total_num_services,
   PERCENT_RANK()OVER(ORDER BY SUM(num_services)) *100 AS percent_rank
FROM services_per_airport_info
GROUP BY airport 
)
/*Main query to return airports ranked by their total number of services, 
with the percent rank to understand their relative standing among all airports.*/
SELECT airport AS airport,
       ROUND(PERCENT_RANK::NUMERIC, 1) AS percent_rank
FROM percent_rank 
ORDER BY percent_rank ASC
;

