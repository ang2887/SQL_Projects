/*
Question #1: 
Vibestream is designed for users to share brief updates about 
how they are feeling, as such the platform enforces a character limit of 25. 
How many posts are exactly 25 characters long?

Expected column names: char_limit_posts
*/

-- q1 solution:

-- SELECT statement counts the number of posts that are exactly 25 characters long.
SELECT COUNT(*) AS char_limit_posts

FROM posts

-- Filtering condition for posts based on their content length in characters.
WHERE CHAR_LENGTH(content) = 25;

/*
1. COUNT(*) is used for performance, as it's optimized in PostgreSQL 
and content cannot be NULL due to the filter condition in the WHERE clause.
2. CHAR_LENGTH() instead of LENGTH() is chosen for better portability 
across some database systems.
3. To ensure that a string does not exceed a certain byte limit, consider
using OCTET_LENGTH() function.
*/


/*

Question #2: 
Users JamesTiger8285 and RobertMermaid7605 are Vibestream’s most active posters.

Find the difference in the number of posts these two users made on each day 
that at least one of them made a post. Return dates where the absolute value of 
the difference between posts made is greater than 2 
(i.e dates where JamesTiger8285 made at least 3 more posts than RobertMermaid7605 or vice versa).

Expected column names: post_date
*/

-- q2 solution:

  

/*-- Query to find the difference in the number of posts
made by JamesTiger8285 and RobertMermaid7605 on each day.*/
SELECT p.post_date AS post_date

FROM posts AS p

    JOIN users AS u 
    ON p.user_id = u.user_id
    
-- Filter posts by the two specified users.
WHERE u.user_name IN ('JamesTiger8285', 'RobertMermaid7605')

GROUP BY p.post_date

-- Filtering on conditional aggregation where the absolute difference in post counts exceeds 2.
HAVING ABS( 
             (COUNT(*) FILTER(WHERE u.user_name = 'JamesTiger8285'))
           - (COUNT(*) FILTER(WHERE u.user_name = 'RobertMermaid7605'))
          ) > 2

ORDER BY p.post_date DESC
;          

/*
Filtering posts by specific users early in the query, 
reduces the volume of data processed in the GROUP BY and HAVING clauses,
enchancing performance with large datasets.

Note: For the databases not compartible with FILTER clause, 
consider using CASE statement and SUM function as an alternative approach.
*/




/*
Question #3: 
Most users have relatively low engagement and few connections. 
User WilliamEagle6815, for example, has only 2 followers.

Network Analysts would say this user has two **1-step path** relationships. 
Having 2 followers doesn’t mean WilliamEagle6815 is isolated, however. 
Through his followers, he is indirectly connected to the larger Vibestream network.  

Consider all users up to 3 steps away from this user:

- 1-step path (X → WilliamEagle6815)
- 2-step path (Y → X → WilliamEagle6815)
- 3-step path (Z → Y → X → WilliamEagle6815)

Write a query to find follower_id of all users within 4 steps of WilliamEagle6815. 
Order by follower_id and return the top 10 records.

Expected column names: follower_id

*/

-- q3 solution:


/*
CTE named path_to_followers. It will be self-referenced, recursively 
tracing paths to users within 4 steps of WilliamEagle6815.
*/
WITH RECURSIVE path_to_followers AS(
  
 /*Base query starts the recursion with direct followers of WilliamEagle6815, 
 sets step tracking as 1 step*/
 SELECT f.follower_id AS follower_id, 1 AS step
 FROM follows AS f
 JOIN users AS u 
 ON f.followee_id = u.user_id
 WHERE u.user_name = 'WilliamEagle6815'
  
 UNION ALL
  
 -- Recursive step increments step tracking by 1 step
 SELECT f.follower_id AS follower_id, step + 1 AS step
 FROM follows AS f
 JOIN path_to_followers AS ptf 
 ON f.followee_id = ptf.follower_id
  
 -- Limit depth to 4 steps
 WHERE step < 4 
)
SELECT DISTINCT follower_id AS follower_id

FROM path_to_followers

-- Recursion termination condition 4 steps
WHERE step = 4 

ORDER BY follower_id

LIMIT 10
;

/*
1. Recursive queries are more efficient for hierarchical data, 
with their simplicity and scalability. 
2. Using JOINs might be considered for cases with less hierarchical depth 
and when joining multiple tables.
*/

/*
Question #4: 
Return top posters for 2023-11-30 and 2023-12-01. 
A top poster is a user who has the most OR second most number of posts 
in a given day. Include the number of posts in the result and 
order the result by post_date and user_id.

Expected column names: post_date, user_id, posts


*/

-- q4 solution:

-- Query to return the posters with max posts for 2023-11-30 and 2023-12-01.
WITH num_posts AS(
-- CTE to aggregate number of posts by date and user_id
   SELECT p.post_date AS post_date,
       p.user_id AS user_id,
       COUNT(p.post_id) AS num_posts

FROM posts p
-- Filtering for 2023-11-30 and 2023-12-01 only.  
WHERE p.post_date IN ( '2023-11-30', '2023-12-01')
GROUP BY post_date, user_id
)
/*Main query to return users who have the most OR second most number of posts 
in the specified days, using DENSE_RANK() to rank users by the number of posts,
using subquery to rank users by their number of posts.*/
SELECT post_date,
       user_id,
       num_posts
FROM  (      
				SELECT *, 
/* DENSE_RANK() function ranks users by their number of posts in descending order, 
where the most active user gets the rank #1*/
        DENSE_RANK()OVER(PARTITION BY post_date ORDER BY num_posts DESC) AS rank
        FROM num_posts
       ) AS sub
-- Filtering for the most OR second most active user.       
WHERE rank <= 2
ORDER BY 1,2
;

/*Using DENSE_RANK() however, not intuitive, is a concise and straightforward
way to answer the question. Alternatively, it can be done with four CTEs with 
using subqueries as filtering condition in WHERE clauses, 
and UNION ALL set operation in main query to combine CTEs outputs 
for getting the most or the second most top posters*/

-- version 2

WITH post_per_date_user_count AS(
	SELECT post_date AS post_date, 
         user_id AS user_id,       	 
         COUNT(post_id) AS num_post	
  FROM posts
  WHERE post_date IN ('2023-11-30', '2023-12-01')
  GROUP BY post_date, user_id
),
top_1_posters as(
SELECT * 

  FROM post_per_date_user_count
WHERE num_post = (SELECT MAX(num_post) 
                  FROM post_per_date_user_count) 
), 
filtering_for_top_2_posters AS(
SELECT *
FROM post_per_date_user_count pp

WHERE num_post <> (SELECT MAX(num_post) 
                  FROM post_per_date_user_count) 

),
top_2_posters AS(
SELECT *
  
  FROM filtering_for_top_2_posters
  WHERE num_post = (SELECT MAX(num_post) 
                  FROM filtering_for_top_2_posters) 
)
SELECT * FROM top_1_posters
UNION ALL
SELECT * FROM top_2_posters
ORDER BY post_date, user_id
;  
