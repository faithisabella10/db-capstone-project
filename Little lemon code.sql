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
