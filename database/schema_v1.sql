-- Crear la base de datos (corregido)

CREATE DATABASE IF NOT EXISTS stocksense_db;
USE stocksense_db;

-- ============================================
-- TABLA: users (Usuarios del sistema)
-- ============================================

CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL COMMENT 'Hash BCrypt, nunca texto plano',
    role ENUM('admin', 'student') NOT NULL DEFAULT 'student',
    student_code VARCHAR(20) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Índices para búsquedas rápidas
    INDEX idx_email (email),
    INDEX idx_role (role),
    INDEX idx_student_code (student_code),
    
    --Validación de email
    CONSTRAINT chk_email_format CHECK (email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLA: categories (Categorías predefinidas)
-- ============================================

CREATE TABLE categories (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    color VARCHAR(7) DEFAULT '#3498db',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
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
-- TABLA: products (Productos/Equipos)
-- ============================================

CREATE TABLE products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL COMMENT 'Debe coincidir con categories.name',
    stock INT NOT NULL DEFAULT 0,
    qr_code VARCHAR(100) UNIQUE NOT NULL,
    image_url VARCHAR(255),
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indices
    INDEX idx_category (category),
    INDEX idx_qr_code (qr_code),
    INDEX idx_is_active (is_active),
    INDEX idx_stock (stock),
    INDEX idx_name (name),
    
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
    
    --Foreign Keys con políticas
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_user_id (user_id),
    INDEX idx_product_id (product_id),
    INDEX idx_status (status),
    INDEX idx_return_date (return_date),
    INDEX idx_loan_date (loan_date),
    
    --Validación de fechas
    CONSTRAINT chk_return_after_loan CHECK (return_date > loan_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- PROCEDIMIENTOS ALMACENADOS
-- ============================================

-- Procedimiento para registrar un nuevo usuario (Mejorado)
DELIMITER $$
CREATE PROCEDURE sp_register_user(
    IN p_full_name VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_password VARCHAR(255),
    IN p_role ENUM('admin', 'student'),
    IN p_student_code VARCHAR(20),
    OUT p_user_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE email_exists INT;
    DECLARE code_exists INT;
    --Verificar si el email ya existe
    SELECT COUNT (*) INTO email_exists FROM users WHERE email = p_email;
    --Verificar si el codigo de estudiante ya existe (solo si no es NULL)
    IF p_student_code IS NOT NULL THEN
        SELECT COUNT(*) INTO code_exists FROM users WHERE student_code = p_student_code;
    ELSE
        SET code_exists = 0;
    END IF;
    
    IF email_exists > 0 THEN
        SET p_message = 'EL email ya esta registrado';
        SET p_user_id = NULL;
    ELSEIF code_exists > 0 THEN
        SET p_message = 'El codigo de estudiante ya esta registrado';
        SET p_user_id = NULL;
    ELSE
    INSERT INTO users (full_name, email, password, role, student_code)
    VALUES (p_full_name, p_email, p_password, p_role, p_student_code);
    
        SET p_user_id = LAST_INSERT_ID();
        SET p_message = 'Usuario registrado exitosamnete';
    END IF; 
    SELECT p_user_id as user_id, p_message as message;
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

-- Vista de productos activos (MEJORADA)
CREATE VIEW vw_active_products AS
SELECT 
    p.id,
    p.name,
    p.description,
    p.category,
    p.stock,
    p.qr_code,
    p.image_url,
    p.created_at,
    CASE 
        WHEN p.stock = 0 THEN 'Agotado'
        WHEN p.stock <= 3 THEN 'Stock Bajo'
        ELSE 'Disponible'
    END as stock_status,
    (SELECT COUNT(*) FROM loans l WHERE l.product_id = p.id AND l.status = 'active') as loans_active
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