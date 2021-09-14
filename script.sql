CREATE DATABASE stc;
USE stc;

#1
# Creating a softuni taxi company database consisting of the following tables and defining relations.

CREATE TABLE addresses (
	id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR (100) NOT NULL
);

CREATE TABLE categories (
	id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR (10) NOT NULL
);

CREATE TABLE clients (
	id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR (50) NOT NULL,
    phone_number VARCHAR (20) NOT NULL
);

CREATE TABLE drivers (
	id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR (30) NOT NULL,
    last_name VARCHAR (30) NOT NULL,
	age INT NOT NULL,
    rating FLOAT NOT NULL DEFAULT 5.5
);

CREATE TABLE cars (
	id INT PRIMARY KEY AUTO_INCREMENT,
    make VARCHAR (20) NOT NULL,
    model VARCHAR(20),
    `year` INT NOT NULL DEFAULT 0,
    mileage INT DEFAULT 0,
    `condition` CHAR(1) NOT NULL,
    category_id INT NOT NULL,
    CONSTRAINT fk_drivers_categoris
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

CREATE TABLE courses(
	id INT PRIMARY KEY AUTO_INCREMENT,
    from_address_id INT NOT NULL,
    `start` DATETIME NOT NULL,
    bill DECIMAL (10,2)  DEFAULT 10,
    car_id INT NOT NULL,
    client_id INT NOT NULL,
    CONSTRAINT fk_courses_addresses
    FOREIGN KEY (from_address_id) REFERENCES addresses(id),
    CONSTRAINT fk_courses_cars
    FOREIGN KEY (car_id) REFERENCES cars(id),
    CONSTRAINT fk_courses_clients
    FOREIGN KEY(client_id) REFERENCES clients(id)
);

CREATE TABLE cars_drivers (
	car_id INT NOT NULL,
    driver_id INT NOT NULL,
    CONSTRAINT pk_cars_drivers
    PRIMARY KEY (car_id,driver_id),
    CONSTRAINT fk_cars_drivers_cars
    FOREIGN KEY (car_id) REFERENCES cars(id),
    CONSTRAINT fk_cars_drivers_drivers 
    FOREIGN KEY (driver_id) REFERENCES drivers(id)
);

#2
# When drivers are not working and need a taxi to transport them, they will also be registered 
# at the database as customers.

INSERT INTO clients (full_name,phone_number)
SELECT concat(d.first_name,' ',d.last_name) AS full_name,
	   concat('(088) 9999',d.id*2)
FROM drivers AS d
WHERE d.id BETWEEN 10 AND 20;

#3
# Updating all cars and set the condition to be 'C'. The cars  must have a mileage greater than 800000 (inclusive) or NULL and must be older than 2010(inclusive).

SET SQL_SAFE_UPDATES = 0;
UPDATE cars 
SET `condition` = 'C'
WHERE (mileage >= 800000 OR mileage IS NULL) AND `year` <= 2010;
SET SQL_SAFE_UPDATES = 1;

#4
# Deleting all clients from clients table, that do not have any courses and the count of the characters in the full_name is more than 3 characters. 

SET SQL_SAFE_UPDATES = 0;
DELETE cl FROM clients AS cl
LEFT JOIN courses AS c
ON cl.id = c.client_id
WHERE c.client_id IS NULL AND char_length(full_name) > 3 ;
SET SQL_SAFE_UPDATES = 1;

#5 
# Extract the info about all the cars. 

SELECT make,model,`condition`
FROM cars
ORDER BY id;

#6
# Selecting all drivers and cars that they drive. Extracting the driver’s first and last 
# name from the drivers table and the make, the model and the mileage from the cars table. 
# Skipping records with null value for muleage

SELECT d.first_name,d.last_name,c.make,c.model,c.mileage
FROM drivers AS d
JOIN cars_drivers AS cd
ON d.id = cd.driver_id
JOIN cars AS c
ON c.id = cd.car_id
WHERE c.mileage IS NOT NULL
ORDER BY c.mileage DESC,d.first_name;

#7 
# Extracting from the database all the cars and the count of their courses
# and displaying the average bill of each course by the car, rounded to the second digit.
# Skipping the cars with exactly 2 courses.

SELECT c2.id,c2.make,c2.mileage,COUNT(c.car_id) AS 'count_of_courses',
	   round(AVG(c.bill),2) AS 'avg_bill'
FROM courses AS c
right JOIN cars AS c2
ON c.car_id = c2.id
GROUP BY c2.id
HAVING count_of_courses != 2
ORDER BY count_of_courses DESC,c2.id;

#8
# Extracting the regular clients, who have ridden in more than one car. The second letter of the customer's full name must be 'a'.
# Selecting the full name, the count of cars that he ridden and total sum of all courses.

SELECT cl.full_name,COUNT(c.car_id) AS 'count_of_cars', SUM(c.bill) AS 'total_sum'
FROM clients AS cl
JOIN courses AS c
ON cl.id = c.client_id
WHERE cl.full_name LIKE '_a%'
GROUP BY cl.full_name
HAVING count_of_cars >1
ORDER BY cl.full_name;

#9
# Splitting starting time in new column which can be day (6-20) and night(21-5)
SELECT a.`name`,
		(CASE
        WHEN HOUR(c.start) BETWEEN 6 AND 20 THEN 'Day'
        ELSE 'Night'
		END) AS 'day_time',
		c.bill,
		cl.full_name,
		cr.make,
		cr.model,
        ctg.name
FROM addresses AS a
JOIN courses AS c
ON a.id = c.from_address_id
JOIN clients AS cl 
ON cl.id = c.client_id
JOIN cars AS cr
ON cr.id = c.car_id
JOIN categories AS ctg
ON ctg.id = cr.category_id
ORDER BY c.id;

#10 
# Creating function that recieves a number of a client and return how many courses courses have the client taken.
DELIMITER $$
CREATE FUNCTION `udf_courses_by_client` (phone_num VARCHAR (20))
RETURNS INTEGER
DETERMINISTIC
BEGIN
DECLARE count_clients INT;
SET count_clients := (SELECT COUNT(c.client_id)
FROM clients AS cl
JOIN courses AS c
ON c.client_id = cl.id
WHERE cl.phone_number = phone_num
GROUP BY cl.id);
RETURN count_clients;
END$$

DELIMITER ;

#11
# Extracting data about the addresses with the given address_name. The needed data is the name of the address, full name of the client, 
# level of bill (depends of course bill – Low – lower than 20(inclusive), Medium – lower than 30(inclusive), and High)
# , make and condition of the car and the name of the category.

USE `stc`;
DROP procedure IF EXISTS `udp_courses_by_address`;

DELIMITER $$
USE `stc`$$
CREATE PROCEDURE `udp_courses_by_address` (address_name VARCHAR(100))
BEGIN
SELECT a.`name`,
	cl.full_name, 
	(CASE
		WHEN c.bill <= 20 THEN 'Low'
       WHEN c.bill <= 30 THEN 'Medium'
       ELSE 'High'
	END) AS 'level_of_bill',
	cr.make,
    cr.`condition`,
    ctg.`name`
FROM addresses AS a
JOIN courses AS c
ON c.from_address_id = a.id
JOIN clients AS cl
ON cl.id = c.client_id
JOIN cars AS cr
ON cr.id = c.car_id
JOIN categories AS ctg
ON ctg.id = cr.category_id
WHERE a.`name` = address_name
ORDER BY cr.make,cl.full_name;
END$$

DELIMITER ;

CALL udp_courses_by_address('700 Monterey Avenue');

