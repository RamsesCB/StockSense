--SCHEMA V2 (EXTENSIONS - CORREGIDO)

USE stocksense_db;

-- ============================================
-- MEJORAS A TABLAS EXISTENTES
-- ============================================

-- 1. Agregar campo a products para historial de movimientos
ALTER TABLE products
ADD COLUMN last_movement_date DATETIME,
ADD COLUMN last_movement_type VARCHAR(20);

-- 2. Agregar campo a users para intentos de login
ALTER TABLE users
ADD COLUMN login_attempts INT DEFAULT 0,
ADD COLUMN last_login DATETIME,
ADD COLUMN is_locked TINYINT(1) DEFAULT 0,
ADD COLUMN locked_until DATETIME;

-- 3. Mejorar tabla loans con más detalles
ALTER TABLE loans
ADD COLUMN actual_return_date DATETIME,
ADD COLUMN condition_before TEXT,
ADD COLUMN condition_after TEXT,
ADD COLUMN notes TEXT,
ADD COLUMN approved_by INT DEFAULT NULL,
-- Con politica ON DELETE SET NULL
ADD FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE;


-- ============================================
-- NUEVA TABLA: loan_history (Historial completo)
-- ============================================
CREATE TABLE loan_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    loan_id INT NOT NULL,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    action ENUM('created', 'updated', 'returned', 'cancelled', 'extended') NOT NULL,
    old_status ENUM('active', 'returned', 'overdue'),
    new_status ENUM('active', 'returned', 'overdue'),
    details JSON,
    changed_by INT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
    FOREIGN KEY (changed_by) REFERENCES users(id) ON DELETE SET NULL,
    
    INDEX idx_loan_id (loan_id),
    INDEX idx_changed_at (changed_at),
    INDEX idx_changed_by (changed_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- NUEVA TABLA: reservations (Reservas futuras)
-- ============================================
CREATE TABLE reservations (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    reservation_date DATETIME NOT NULL,
    pickup_date DATETIME NOT NULL,
    status ENUM('pending', 'confirmed', 'cancelled', 'expired') DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    
    INDEX idx_user_id (user_id),
    INDEX idx_product_id (product_id),
    INDEX idx_status (status),
    INDEX idx_pickup_date (pickup_date),
    
    CONSTRAINT chk_pickup_after_reservation CHECK (pickup_date >= reservation_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- NUEVA TABLA: notifications (Notificaciones)
-- ============================================
CREATE TABLE notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    title VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    type ENUM('info', 'warning', 'success', 'error') DEFAULT 'info',
    is_read TINYINT(1) DEFAULT 0,
    related_table VARCHAR(50),
    related_id INT,
    expires_at DATETIME DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    
    INDEX idx_user_id (user_id),
    INDEX idx_is_read (is_read),
    INDEX idx_created_at (created_at),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- NUEVA TABLA: settings (Configuraciones)
-- ============================================
CREATE TABLE settings (
    id INT PRIMARY KEY AUTO_INCREMENT,
    setting_key VARCHAR(50) UNIQUE NOT NULL,
    setting_value TEXT,
    setting_type ENUM('string', 'integer', 'boolean', 'json') DEFAULT 'string',
    category VARCHAR(30),
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    -- VAlidacion de booleanos
    CONSTRAINT chk_boolean_values 
    CHECK (
        setting_type != 'boolean' OR 
        setting_value IN ('0', '1', 'true', 'false')
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertar configuraciones por defecto
INSERT INTO settings (setting_key, setting_value, setting_type, category, description) VALUES
('loan_duration_days', '7', 'integer', 'loans', 'Duración por defecto de préstamos en días'),
('max_loans_per_user', '3', 'integer', 'loans', 'Máximo de préstamos activos por usuario'),
('low_stock_threshold', '5', 'integer', 'inventory', 'Umbral para alertas de stock bajo'),
('overdue_penalty_days', '3', 'integer', 'loans', 'Días de penalización por retraso'),
('auto_cancel_reservation_hours', '24', 'integer', 'reservations', 'Horas para cancelar reservas no confirmadas'),
('system_email', 'sistema@stocksense.edu', 'string', 'system', 'Email del sistema'),
('maintenance_mode', '0', 'boolean', 'system', 'Modo mantenimiento (1=activado)');

-- ============================================
-- MEJORAS A ÍNDICES
-- ============================================

-- Índices compuestos para mejor performance
CREATE INDEX idx_products_category_stock ON products(category, stock);
CREATE INDEX idx_loans_user_status ON loans(user_id, status);
CREATE INDEX idx_loans_dates ON loans(loan_date, return_date);

-- ============================================
-- NUEVOS PROCEDIMIENTOS ALMACENADOS
-- ============================================

-- Procedimiento para realizar un préstamo (Mejorado)
DELIMITER $$
CREATE PROCEDURE sp_create_loan(
    IN p_user_id INT,
    IN p_product_id INT,
    IN p_loan_days INT,
    IN p_approved_by INT,
    OUT p_loan_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_stock INT;
    DECLARE v_is_active TINYINT(1);
    DECLARE v_max_loans INT;
    DECLARE v_current_loans INT;
    DECLARE v_user_locked TINYINT(1);
    -- Verificacion si el ususario esta bloqueado
    SELECT is_locked INTO v_user_locked FROM users WHERE id = p_user_id;
    
    IF v_user_locked = 1 THEN
        SET p_message = 'Usuario bloqueado. No puede realizar préstamos';
        SET p_loan_id = NULL;
    ELSE
        -- Verificar stock Y si producto está activo
        SELECT stock, is_active INTO v_stock, v_is_active 
        FROM products 
        WHERE id = p_product_id;
        
        -- Verificar límite de préstamos
        SELECT setting_value INTO v_max_loans 
        FROM settings 
        WHERE setting_key = 'max_loans_per_user';
        
        SELECT COUNT(*) INTO v_current_loans 
        FROM loans 
        WHERE user_id = p_user_id AND status = 'active';
        
        IF v_is_active = 0 THEN
            SET p_message = 'Producto no activo';
            SET p_loan_id = NULL;
        ELSEIF v_stock <= 0 THEN
            SET p_message = 'Producto no disponible en stock';
            SET p_loan_id = NULL;
        ELSEIF v_current_loans >= v_max_loans THEN
            SET p_message = CONCAT('Límite de préstamos alcanzado (', v_max_loans, ')');
            SET p_loan_id = NULL;
        ELSE
            -- Crear préstamo
            INSERT INTO loans (user_id, product_id, loan_date, return_date, approved_by)
            VALUES (
                p_user_id, 
                p_product_id, 
                NOW(), 
                DATE_ADD(NOW(), INTERVAL p_loan_days DAY),
                p_approved_by
            );
            
            SET p_loan_id = LAST_INSERT_ID();
            
            -- Actualizar stock
            UPDATE products 
            SET stock = stock - 1,
                last_movement_date = NOW(),
                last_movement_type = 'loan'
            WHERE id = p_product_id;
            
            -- Registrar en historial
            INSERT INTO loan_history (loan_id, user_id, product_id, action, new_status, changed_by)
            VALUES (p_loan_id, p_user_id, p_product_id, 'created', 'active', p_approved_by);
            
            SET p_message = 'Préstamo creado exitosamente';
        END IF;
    END IF;
END$$
DELIMITER ;

-- Procedimiento para devolver un préstamo (MEJORADO)
DELIMITER $$
CREATE PROCEDURE sp_return_loan(
    IN p_loan_id INT,
    IN p_condition_notes TEXT,
    IN p_returned_by INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_product_id INT;
    DECLARE v_user_id INT;
    DECLARE v_status VARCHAR(20);
    
    -- Obtener datos del préstamo
    SELECT product_id, user_id, status 
    INTO v_product_id, v_user_id, v_status
    FROM loans 
    WHERE id = p_loan_id;
    --Aceptar tanto 'active' como 'overdue'
    IF v_status NOT IN ('active', 'overdue') THEN
        SET p_message = CONCAT('Este préstamo no puede ser devuelto (estado: ', v_status, ')');
    ELSE
        -- Actualizar préstamo
        UPDATE loans 
        SET status = 'returned',
            actual_return_date = NOW(),
            condition_after = p_condition_notes
        WHERE id = p_loan_id;
        
        -- Actualizar stock
        UPDATE products 
        SET stock = stock + 1,
            last_movement_date = NOW(),
            last_movement_type = 'return'
        WHERE id = v_product_id;
        
        -- Registrar en historial
        INSERT INTO loan_history (loan_id, user_id, product_id, action, old_status, new_status, changed_by)
        VALUES (p_loan_id, v_user_id, v_product_id, 'returned', v_status, 'returned', p_returned_by);
        
        SET p_message = 'Préstamo devuelto exitosamente';
    END IF;
END$$
DELIMITER ;

-- ============================================
-- TRIGGERS MEJORADOS
-- ============================================

-- Trigger para notificar stock bajo (Mejorado)
DELIMITER $$
CREATE TRIGGER tr_check_low_stock
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    DECLARE v_threshold INT;
    
    IF NEW.stock != OLD.stock THEN
        -- Obtener umbral
        SELECT CAST(setting_value AS UNSIGNED) INTO v_threshold 
        FROM settings 
        WHERE setting_key = 'low_stock_threshold';
        -- Crear notificación si stock es bajo (Solo a 5 admins, avisar si se añaden a más)
        IF NEW.stock <= v_threshold AND NEW.stock > 0 THEN
            INSERT INTO notifications (user_id, title, message, type)
            SELECT id, 
                   'Stock Bajo Alert',
                   CONCAT('El producto "', NEW.name, '" tiene stock bajo: ', NEW.stock, ' unidades'),
                   'warning'
            FROM users 
            WHERE role = 'admin'
            LIMIT 5; 
        END IF;
        -- Notificar si stock es cero (Repito solo a 5 admins)
        IF NEW.stock = 0 THEN
            INSERT INTO notifications (user_id, title, message, type)
            SELECT id, 
                   'Stock Agotado',
                   CONCAT('El producto "', NEW.name, '" se ha agotado'),
                   'error'
            FROM users 
            WHERE role = 'admin'
            LIMIT 5;
        END IF;
    END IF;
END$$
DELIMITER ;

-- Trigger para préstamos vencidos (CORREGIDO - SIN LOOP)
DELIMITER $$
CREATE TRIGGER tr_check_overdue_loans
BEFORE UPDATE ON loans
FOR EACH ROW
BEGIN
    -- Solo marcar como vencido si se está actualizando y ya pasó la fecha
    IF NEW.return_date < NOW() AND NEW.status = 'active' AND OLD.status = 'active' THEN
        SET NEW.status = 'overdue';
        -- Crear notificación
        INSERT INTO notifications (user_id, title, message, type)
        VALUES (
            NEW.user_id,
            'Préstamo Vencido',
            CONCAT('Tu préstamo del producto ID ', NEW.product_id, ' está vencido'),
            'error'
        );
        
        -- Registrar en historial
        INSERT INTO loan_history (loan_id, user_id, product_id, action, old_status, new_status)
        VALUES (NEW.id, NEW.user_id, NEW.product_id, 'updated', 'active', 'overdue');
    END IF;
END$$
DELIMITER ;

-- ============================================
-- VISTAS MEJORADAS
-- ============================================

-- Vista de préstamos con detalles
CREATE VIEW vw_loans_detailed AS
SELECT 
    l.id,
    l.loan_date,
    l.return_date,
    l.actual_return_date,
    l.status,
    u.full_name as user_name,
    u.email as user_email,
    u.student_code,
    p.name as product_name,
    p.category,
    p.qr_code,
    a.full_name as approved_by_name,
    DATEDIFF(l.return_date, l.loan_date) as loan_duration,
    CASE 
        WHEN l.status = 'active' AND l.return_date < NOW() THEN 'overdue'
        ELSE l.status
    END as real_status
FROM loans l
JOIN users u ON l.user_id = u.id
JOIN products p ON l.product_id = p.id
LEFT JOIN users a ON l.approved_by = a.id;

-- Vista de productos con estadísticas
CREATE VIEW vw_products_stats AS
SELECT 
    p.id,
    p.name,
    p.category,
    p.stock,
    p.qr_code,
    COUNT(l.id) as total_loans,
    SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END) as active_loans,
    SUM(CASE WHEN l.status = 'overdue' THEN 1 ELSE 0 END) as overdue_loans,
    MAX(l.loan_date) as last_loan_date
FROM products p
LEFT JOIN loans l ON p.id = l.product_id
GROUP BY p.id, p.name, p.category, p.stock, p.qr_code;

-- Vista de usuarios con estadísticas de préstamos
CREATE VIEW vw_users_loan_stats AS
SELECT 
    u.id,
    u.full_name,
    u.email,
    u.role,
    u.student_code,
    COUNT(l.id) as total_loans,
    SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END) as active_loans,
    SUM(CASE WHEN l.status = 'overdue' THEN 1 ELSE 0 END) as overdue_loans,
    MAX(l.loan_date) as last_loan_date
FROM users u
LEFT JOIN loans l ON u.id = l.user_id
WHERE u.role = 'student'
GROUP BY u.id, u.full_name, u.email, u.role, u.student_code;