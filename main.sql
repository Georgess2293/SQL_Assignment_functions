-- 1. Scalar Functions
-- Convert all film titles in the film table to uppercase.

UPDATE public.film
SET title=UPPER(title)

--Calculate the length in hours (rounded to 2 decimal places) for each film in the film table.

SELECT
    se_film.film_id,
    ROUND(CAST(se_film.length AS NUMERIC)/60,2)
FROM public.film AS se_film

--Extract the year from the last_update column in the actor table.
SELECT
    DISTINCT EXTRACT(YEAR FROM CAST(se_actor.last_update AS DATE)) AS year
FROM public.actor AS se_actor

--2. Aggregate Function
--Count the total number of films in the film table.

SELECT
	COUNT(se_film.film_id) AS total_films
FROM public.film AS se_film

--Calculate the average rental rate of films in the film table.

SELECT
	ROUND(AVG(se_film.rental_rate),2) AS avg_rental_rate
FROM public.film AS se_film

--Determine the highest and lowest film lengths.

SELECT
	MAX(se_film.length) AS max_length,
	MIN(se_film.length) AS min_length
FROM public.film AS se_film

--Find the total number of films in each film category.

SELECT
	se_film_category.category_id,
	COUNT(se_film_category.film_id) AS total_films
FROM public.film_category AS se_film_category
GROUP BY 
	se_film_category.category_id

--3- Window Functions
--Rank films in the film table by length using the RANK() function.

SELECT
	se_film.film_id,
	se_film.length,
	RANK() OVER(ORDER BY se_film.length DESC) AS length_rank
FROM public.film AS se_film

--Calculate the cumulative sum of film lengths in the film table using the SUM() window function.

SELECT
	se_film.film_id,
	se_film.length,
	SUM(se_film.length) OVER(ORDER BY se_film.length) AS cumulative_length
FROM public.film AS se_film


--For each film in the film table, 
--retrieve the title of the next film in terms of alphabetical order using the LEAD() function.

SELECT
	se_film.film_id,
	se_film.title,
	LEAD(se_film.title) OVER(ORDER BY se_film.title) AS next_film
FROM public.film AS se_film

--4. Conditional Functions
--Classify films in the film table based on their lengths:
--Short (< 60 minutes)
--Medium (60 - 120 minutes)
--Long (> 120 minutes)

SELECT
	se_film.film_id,
	se_film.title,
	CASE
		WHEN se_film.length<60 THEN 'Short'
		WHEN se_film.length>=60 AND se_film.length<=120 THEN 'Medium'
		WHEN se_film.length>120 THEN 'Long'
	END AS film_length
FROM public.film AS se_film

--For each payment in the payment table, 
--use the COALESCE function to replace null values in the amount column with the average payment amount.

SELECT
	se_payment.payment_id,
	COALESCE(se_payment.amount,AVG(se_payment.amount) OVER())
FROM public.payment AS se_payment

-- 5. User-Defined Functions (UDFs)
--Create a UDF named film_category that accepts a film title as input and returns the category of the film.

CREATE OR REPLACE FUNCTION public.film_category(input_film_title TEXT)
RETURNS TEXT AS
$$
DECLARE 
	category_output TEXT;
BEGIN
	SELECT
		se_category.name
	INTO category_output
	FROM public.film AS se_film
	INNER JOIN public.film_category AS se_film_category
	ON se_film.film_id=se_film_category.film_id
	INNER JOIN public.category AS se_category
	ON se_film_category.category_id=se_category.category_id
	WHERE se_film.title=input_film_title;
	RETURN category_output;
END;
$$
LANGUAGE plpgsql;

--Develop a UDF named total_rentals that takes a film title as an argument 
--and returns the total number of times the film has been rented.

CREATE OR REPLACE FUNCTION public.total_rentals(input_film_title TEXT)
RETURNS TEXT AS
$$
DECLARE 
	rental_number INT;
BEGIN
	SELECT
		COALESCE(COUNT(se_rental.rental_id),0)
	INTO rental_number
	FROM public.rental AS se_rental
	INNER JOIN public.inventory AS se_inventory
	ON se_rental.inventory_id=se_inventory.inventory_id
	INNER JOIN public.film AS se_film
	ON se_inventory.film_id=se_film.film_id
	WHERE se_film.title=input_film_title;
	RETURN rental_number;
END;
$$
LANGUAGE plpgsql;

--Design a UDF named customer_stats which takes a customer ID as input and returns a JSON containing the customer's name, 
--total rentals, and total amount spent.

CREATE OR REPLACE FUNCTION public.customer_stats(input_customer_id INT)
RETURNS JSONB AS
$$
DECLARE 
	return_jsonb JSONB;
BEGIN
	SELECT
		JSONB_AGG(row_to_json(row(customer_info.full_name,customer_info.total_rentals,customer_info.total_amount)))
	INTO return_jsonb
	FROM 
	(
	SELECT 
		se_customer.customer_id AS customer_id,
		CONCAT(se_customer.first_name,' ',se_customer.last_name) AS full_name,
		COALESCE(COUNT(se_rental.rental_id),0) AS total_rentals,
		COALESCE(SUM(se_payment.amount),0) AS total_amount
	FROM public.customer AS se_customer
	INNER JOIN public.payment AS se_payment
	ON se_customer.customer_id=se_payment.customer_id
	INNER JOIN public.rental AS se_rental
	ON se_payment.rental_id=se_rental.rental_id
	GROUP BY 
		se_customer.customer_id,
		CONCAT(se_customer.first_name,' ',se_customer.last_name)
	)AS customer_info
	WHERE customer_info.customer_id=input_customer_id;
	RETURN return_jsonb;
END;
$$
LANGUAGE plpgsql;
