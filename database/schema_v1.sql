
-- Crear la base de datos
CREATE DATABASE IF NOT EXISTS stocksense_db;
USE stocksense_db;

-- ============================================
-- TABLA: users (Usuarios del sistema)
-- ============================================
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin', 'student') NOT NULL DEFAULT 'student',
    student_code VARCHAR(20) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Índices para búsquedas rápidas
    INDEX idx_email (email),
    INDEX idx_role (role),
    INDEX idx_student_code (student_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLA: products (Productos/Equipos)
-- ============================================
CREATE TABLE products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    qr_code VARCHAR(100) UNIQUE NOT NULL,
    image_url VARCHAR(255),
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Índices
    INDEX idx_category (category),
    INDEX idx_qr_code (qr_code),
    INDEX idx_is_active (is_active),
    INDEX idx_stock (stock),
    
    -- Restricciones
    CONSTRAINT chk_stock_non_negative CHECK (stock >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLA: loans (Préstamos)
-- ============================================
CREATE TABLE loans (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    loan_date DATETIME NOT NULL,
    return_date DATETIME NOT NULL,
    status ENUM('active', 'returned', 'overdue') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (product_id) REFERENCES products(id),
    
    INDEX idx_user_id (user_id),
    INDEX idx_product_id (product_id),
    INDEX idx_status (status),
    INDEX idx_return_date (return_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLA: categories (Categorías predefinidas)
-- ============================================
CREATE TABLE categories (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    color VARCHAR(7) DEFAULT '#3498db'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertar categorías base
INSERT INTO categories (name, description, color) VALUES
('Computo', 'Equipos de cómputo: laptops, PCs, tablets', '#3498db'),
('Laboratorio', 'Equipos de laboratorio científico', '#e74c3c'),
('Electronica', 'Componentes y kits electrónicos', '#2ecc71'),
('Libros', 'Libros y material bibliográfico', '#9b59b6'),
('AudioVideo', 'Equipos de audio y video', '#f39c12'),
('Herramientas', 'Herramientas y equipo general', '#1abc9c');

-- ============================================
-- PROCEDIMIENTOS ALMACENADOS
-- ============================================

-- Procedimiento para registrar un nuevo usuario
DELIMITER $$
CREATE PROCEDURE sp_register_user(
    IN p_full_name VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_password VARCHAR(255),
    IN p_role ENUM('admin', 'student'),
    IN p_student_code VARCHAR(20)
)
BEGIN
    INSERT INTO users (full_name, email, password, role, student_code)
    VALUES (p_full_name, p_email, p_password, p_role, p_student_code);
    
    SELECT LAST_INSERT_ID() as user_id;
END$$
DELIMITER ;

-- Procedimiento para actualizar stock
DELIMITER $$
CREATE PROCEDURE sp_update_product_stock(
    IN p_product_id INT,
    IN p_quantity_change INT,
    OUT p_new_stock INT
)
BEGIN
    UPDATE products 
    SET stock = stock + p_quantity_change
    WHERE id = p_product_id;
    
    SELECT stock INTO p_new_stock FROM products WHERE id = p_product_id;
END$$
DELIMITER ;

-- ============================================
-- TRIGGERS
-- ============================================

-- Trigger para registrar cambios en productos
DELIMITER $$
CREATE TRIGGER tr_products_before_update
BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
    
    -- Validar que stock no sea negativo
    IF NEW.stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock cannot be negative';
    END IF;
END$$
DELIMITER ;

-- Trigger para usuarios
DELIMITER $$
CREATE TRIGGER tr_users_before_update
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END$$
DELIMITER ;

-- ============================================
-- VISTAS
-- ============================================

-- Vista de productos activos
CREATE VIEW vw_active_products AS
SELECT 
    p.id,
    p.name,
    p.description,
    p.category,
    p.stock,
    p.qr_code,
    p.image_url,
    CASE 
        WHEN p.stock = 0 THEN 'Agotado'
        WHEN p.stock <= 3 THEN 'Stock Bajo'
        ELSE 'Disponible'
    END as stock_status
FROM products p
WHERE p.is_active = 1;

-- Vista de usuarios con información básica
CREATE VIEW vw_users_basic AS
SELECT 
    id,
    full_name,
    email,
    role,
    student_code,
    created_at
FROM users
WHERE role = 'student';