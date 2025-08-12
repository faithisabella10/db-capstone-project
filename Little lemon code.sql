-- Create database
CREATE DATABASE IF NOT EXISTS LittleLemonDB
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE LittleLemonDB;

-- Customers
CREATE TABLE Customers (
  customer_id     INT AUTO_INCREMENT PRIMARY KEY,
  first_name      VARCHAR(50) NOT NULL,
  last_name       VARCHAR(50) NOT NULL,
  email           VARCHAR(255) NOT NULL,
  phone           VARCHAR(25),
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_customers_email (email)
);

-- Staff
CREATE TABLE Staff (
  staff_id        INT AUTO_INCREMENT PRIMARY KEY,
  first_name      VARCHAR(50) NOT NULL,
  last_name       VARCHAR(50) NOT NULL,
  role            VARCHAR(50) NOT NULL,
  salary          DECIMAL(10,2) NOT NULL CHECK (salary >= 0),
  email           VARCHAR(255),
  phone           VARCHAR(25),
  hired_at        DATE,
  UNIQUE KEY uk_staff_email (email)
);

-- Physical tables in the restaurant
CREATE TABLE RestaurantTables (
  table_id        INT AUTO_INCREMENT PRIMARY KEY,
  table_number    INT NOT NULL,
  capacity        INT NOT NULL CHECK (capacity > 0),
  UNIQUE KEY uk_tables_number (table_number)
);

-- Bookings (customer reserves a specific table at a specific time)
CREATE TABLE Bookings (
  booking_id        INT AUTO_INCREMENT PRIMARY KEY,
  customer_id       INT NOT NULL,
  table_id          INT NOT NULL,
  booking_datetime  DATETIME NOT NULL,
  party_size        INT NOT NULL CHECK (party_size > 0),
  notes             VARCHAR(255),
  CONSTRAINT fk_bookings_customer
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_bookings_table
    FOREIGN KEY (table_id) REFERENCES RestaurantTables(table_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX idx_bookings_datetime (booking_datetime)
);

-- Menu items
CREATE TABLE MenuItems (
  menu_item_id   INT AUTO_INCREMENT PRIMARY KEY,
  item_name      VARCHAR(100) NOT NULL,
  item_desc      VARCHAR(500),
  category       ENUM('Cuisine','Starter','Course','Drink','Dessert') NOT NULL,
  price          DECIMAL(10,2) NOT NULL CHECK (price >= 0),
  is_active      TINYINT(1) NOT NULL DEFAULT 1
);

-- Orders
CREATE TABLE Orders (
  order_id        INT AUTO_INCREMENT PRIMARY KEY,
  customer_id     INT NOT NULL,
  booking_id      INT NULL,
  order_datetime  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total_cost      DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (total_cost >= 0),
  created_by_staff_id INT NULL,
  CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_orders_booking
    FOREIGN KEY (booking_id) REFERENCES Bookings(booking_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_orders_staff
    FOREIGN KEY (created_by_staff_id) REFERENCES Staff(staff_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  INDEX idx_orders_datetime (order_datetime)
);

-- Order line items (junction: Orders ↔ MenuItems)
CREATE TABLE OrderItems (
  order_id       INT NOT NULL,
  menu_item_id   INT NOT NULL,
  quantity       INT NOT NULL CHECK (quantity > 0),
  unit_price     DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
  PRIMARY KEY (order_id, menu_item_id),
  CONSTRAINT fk_orderitems_order
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_orderitems_menuitem
    FOREIGN KEY (menu_item_id) REFERENCES MenuItems(menu_item_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Delivery status (1:1 with Orders)
CREATE TABLE OrderDeliveryStatus (
  order_id       INT PRIMARY KEY,
  delivery_date  DATETIME NULL,
  status         ENUM('Preparing','Out for delivery','Delivered','Cancelled','Pickup Ready','Picked Up')
                 NOT NULL DEFAULT 'Preparing',
  CONSTRAINT fk_deliverystatus_order
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)
    ON UPDATE CASCADE ON DELETE CASCADE
);
show databases;

CREATE OR REPLACE VIEW OrdersView AS
SELECT
  o.order_id,
  SUM(oi.quantity) AS total_quantity,
  o.total_cost
FROM Orders o
JOIN OrderItems oi
  ON oi.order_id = o.order_id
GROUP BY o.order_id, o.total_cost
HAVING SUM(oi.quantity) > 2;
SELECT * FROM OrdersView;

SELECT
  c.customer_id,
  CONCAT(c.first_name, ' ', c.last_name) AS full_name,
  o.order_id,
  o.total_cost,
  -- all Course items in the order
  GROUP_CONCAT(
    CASE WHEN mi.category = 'Course' THEN mi.item_name END
    ORDER BY mi.item_name
    SEPARATOR ', '
  ) AS course_names,
  -- all Starter items in the order
  GROUP_CONCAT(
    CASE WHEN mi.category = 'Starter' THEN mi.item_name END
    ORDER BY mi.item_name
    SEPARATOR ', '
  ) AS starter_names
FROM Orders o
JOIN Customers c
  ON c.customer_id = o.customer_id
JOIN OrderItems oi
  ON oi.order_id = o.order_id
JOIN MenuItems mi
  ON mi.menu_item_id = oi.menu_item_id
WHERE o.total_cost > 150
GROUP BY
  c.customer_id, full_name, o.order_id, o.total_cost
ORDER BY o.total_cost ASC;

SELECT m.item_name
FROM MenuItems m
WHERE m.menu_item_id = ANY (
  SELECT oi.menu_item_id
  FROM OrderItems oi
  WHERE oi.quantity > 2
);

DELIMITER $$

CREATE PROCEDURE GetMaxQuantity()
BEGIN
    SELECT MAX(quantity) AS MaxQuantity
    FROM OrderItems;
END $$

DELIMITER ;

-- Test
CALL GetMaxQuantity();

-- Create prepared statement
PREPARE GetOrderDetail 
FROM '
SELECT 
    o.order_id,
    SUM(oi.quantity) AS total_quantity,
    o.total_cost
FROM Orders o
JOIN OrderItems oi
  ON o.order_id = oi.order_id
WHERE o.customer_id = ?
GROUP BY o.order_id, o.total_cost
';

-- Set variable and execute
SET @id = 1;
EXECUTE GetOrderDetail USING @id;

DELIMITER $$

CREATE PROCEDURE CancelOrder(IN p_order_id INT)
BEGIN
    DELETE FROM Orders
    WHERE order_id = p_order_id;
END $$

DELIMITER ;

-- Test
CALL CancelOrder(3);  -- deletes order with ID 3

INSERT INTO Bookings
  (booking_id, booking_datetime, table_id, customer_id, party_size)
VALUES
  (1, '2022-10-10', 5, 1, 2),
  (2, '2022-11-12', 3, 3, 4),
  (3, '2022-10-11', 2, 2, 3),
  (4, '2022-10-13', 2, 1, 2);

DELIMITER $$

CREATE PROCEDURE CheckBooking(
    IN p_booking_date DATE,
    IN p_table_id INT
)
BEGIN
    DECLARE booking_status VARCHAR(255);

    IF EXISTS (
        SELECT 1
        FROM Bookings
        WHERE booking_datetime = p_booking_date
          AND table_id = p_table_id
    ) THEN
        SET booking_status = CONCAT('Table ', p_table_id, ' is already booked');
    ELSE
        SET booking_status = CONCAT('Table ', p_table_id, ' is available');
    END IF;

    SELECT booking_status AS 'Booking status';
END $$

DELIMITER ;

-- Example test:
CALL CheckBooking('2022-11-12', 3);


DELIMITER $$

USE LittleLemonDB;

DELIMITER $$

DROP PROCEDURE IF EXISTS AddValidBooking $$
CREATE PROCEDURE AddValidBooking(
    IN p_booking_date DATE,
    IN p_table_id INT,
    IN p_customer_id INT
)
BEGIN
    DECLARE booking_count INT;

    START TRANSACTION;

    SELECT COUNT(*)
      INTO booking_count
      FROM Bookings
     WHERE booking_datetime = p_booking_date
       AND table_id = p_table_id;

    IF booking_count > 0 THEN
        ROLLBACK;
        SELECT CONCAT('Table ', p_table_id, ' is already booked - booking canceled') AS 'Booking status';
    ELSE
        -- choose a party_size (example: 2). Adjust as needed or add as a 4th param.
        INSERT INTO Bookings (booking_datetime, table_id, customer_id, party_size)
        VALUES (p_booking_date, p_table_id, p_customer_id, 2);
        COMMIT;
        SELECT CONCAT('Table ', p_table_id, ' successfully booked') AS 'Booking status';
    END IF;
END $$
DELIMITER ;

-- 
CALL AddValidBooking('2022-12-17', 6, 2);


DELIMITER ;

-- Example test:
CALL AddValidBooking('2022-12-17', 6, 2);

DELIMITER $$

CREATE PROCEDURE AddBooking(
    IN p_booking_id INT,
    IN p_customer_id INT,
    IN p_table_id INT,
    IN p_booking_date DATE
)
BEGIN
    INSERT INTO Bookings (booking_id, customer_id, table_id, booking_datetime)
    VALUES (p_booking_id, p_customer_id, p_table_id, p_booking_date);

    SELECT 'New booking added' AS Confirmation;
END $$

DELIMITER ;

-- Example:
CALL AddBooking(9, 3, 4, '2022-12-30');

DELIMITER $$

CREATE PROCEDURE UpdateBooking(
    IN p_booking_id INT,
    IN p_booking_date DATE
)
BEGIN
    UPDATE Bookings
    SET booking_datetime = p_booking_date
    WHERE booking_id = p_booking_id;

    SELECT CONCAT('Booking ', p_booking_id, ' updated') AS Confirmation;
END $$

DELIMITER ;

-- Example:
CALL UpdateBooking(9, '2022-12-17');

DELIMITER $$

CREATE PROCEDURE CancelBooking(
    IN p_booking_id INT
)
BEGIN
    DELETE FROM Bookings
    WHERE booking_id = p_booking_id;

    SELECT CONCAT('Booking ', p_booking_id, ' cancelled') AS Confirmation;
END $$

DELIMITER ;

-- Example:
CALL CancelBooking(9);

SHOW TABLES;
DESCRIBE customers;
DESCRIBE orders;

SELECT
  c.FullName,
  c.ContactNumber AS Phone,
  c.Email,
  o.TotalCost AS BillAmount
FROM customers AS c
JOIN orders    AS o
  ON o.CustomerID = c.CustomerID
WHERE o.TotalCost > 60
ORDER BY o.TotalCost DESC;

SELECT
  CONCAT(c.FirstName,' ',c.LastName) AS FullName,
  c.PhoneNumber AS Phone,
  c.Email,
  o.TotalCost AS BillAmount
FROM customers AS c
JOIN orders    AS o
  ON o.CustomerID = c.CustomerID
WHERE o.TotalCost > 60
ORDER BY o.TotalCost DESC;







