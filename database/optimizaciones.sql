
USE stocksense_db;


-- ============================================
-- 2. OPTIMIZACIÓN DE ÍNDICES
-- ============================================

-- Crear índices faltantes para consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_products_name_category ON products(name, category);
CREATE INDEX IF NOT EXISTS idx_loans_dates_status ON loans(loan_date, return_date, status);
CREATE INDEX IF NOT EXISTS idx_users_email_role ON users(email, role);

-- ============================================
-- 3. OPTIMIZACIÓN DE TABLAS
-- ============================================

-- Optimizar tablas fragmentadas
OPTIMIZE TABLE users;
OPTIMIZE TABLE products;
OPTIMIZE TABLE loans;
OPTIMIZE TABLE loan_history;

-- Analizar tablas para optimizar estadísticas
ANALYZE TABLE users;
ANALYZE TABLE products;
ANALYZE TABLE loans;

-- ============================================
-- 4. OPTIMIZACIÓN DE CONSULTAS
-- ============================================

-- Crear vistas materializadas para reportes pesados

CREATE TABLE IF NOT EXISTS mv_daily_stats (
    stat_date DATE PRIMARY KEY,
    total_users INT,
    total_products INT,
    active_loans INT,
    overdue_loans INT,
    low_stock_items INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
-- ============================================
-- 7. LIMPIEZA Y MANTENIMIENTO
-- ============================================

-- Eliminar datos antiguos
DROP PROCEDURE IF EXISTS sp_clean_old_data;

DELIMITER $$
CREATE PROCEDURE sp_clean_old_data()
BEGIN
    -- Mantener logs de auditoría por 90 días
    DELETE FROM audit_log 
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);
    
    -- Mantener historial de préstamos completos por 1 año
    DELETE FROM loan_history 
    WHERE changed_at < DATE_SUB(NOW(), INTERVAL 365 DAY);
    
    -- Mantener notificaciones leídas por 30 días
    DELETE FROM notifications 
    WHERE is_read = 1 
    AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);
    
    -- Eliminar reservas expiradas antiguas
    DELETE FROM reservations 
    WHERE status = 'expired' 
    AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY);
    
    SELECT 'Old data cleaned successfully' as result;
END$$
DELIMITER ;

-- ============================================
-- 8. MONITOREO DE PERFORMANCE
-- ============================================

CREATE TABLE IF NOT EXISTS performance_log (
    id INT PRIMARY KEY AUTO_INCREMENT,
    query_type VARCHAR(50),
    execution_time_ms DECIMAL(10,2),
    rows_affected INT,
    table_name VARCHAR(50),
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_host VARCHAR(100)
);

-- Trigger para monitorear consultas lentas en loans
DROP TRIGGER IF EXISTS tr_monitor_slow_loans_queries;

DELIMITER $$
CREATE TRIGGER tr_monitor_slow_loans_queries
AFTER INSERT ON loans
FOR EACH ROW
BEGIN
    INSERT INTO performance_log (query_type, table_name, rows_affected)
    VALUES ('INSERT', 'loans', 1);
END$$
DELIMITER ;

-- ============================================
-- 9. OPTIMIZACIÓN PARA REPORTES
-- ============================================

-- Crear tablas de resumen para reportes frecuentes
CREATE TABLE IF NOT EXISTS summary_daily_loans (
    summary_date DATE PRIMARY KEY,
    category VARCHAR(50),
    loan_count INT,
    unique_users INT,
    INDEX idx_summary_date (summary_date),
    INDEX idx_category (category)
);

DROP PROCEDURE IF EXISTS sp_generate_daily_summary;

DELIMITER $$
CREATE PROCEDURE sp_generate_daily_summary()
BEGIN
    DECLARE yesterday DATE;
    SET yesterday = DATE_SUB(CURDATE(), INTERVAL 1 DAY);
    
    -- Resumen por categoría
    INSERT INTO summary_daily_loans (summary_date, category, loan_count, unique_users)
    SELECT 
        DATE(l.loan_date),
        p.category,
        COUNT(l.id),
        COUNT(DISTINCT l.user_id)
    FROM loans l
    JOIN products p ON l.product_id = p.id
    WHERE DATE(l.loan_date) = yesterday
    GROUP BY DATE(l.loan_date), p.category
    ON DUPLICATE KEY UPDATE
        loan_count = VALUES(loan_count),
        unique_users = VALUES(unique_users);
END$$
DELIMITER ;

-- ============================================
-- 13. BACKUP DE CONFIGURACIONES
-- ============================================

-- Guardar configuración actual de performance
CREATE TABLE IF NOT EXISTS db_config_backup (
    id INT PRIMARY KEY AUTO_INCREMENT,
    variable_name VARCHAR(100),
    variable_value VARCHAR(500),
    backed_up_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DROP PROCEDURE IF EXISTS sp_backup_db_config;

DELIMITER $$
CREATE PROCEDURE sp_backup_db_config()
BEGIN
    -- Backup de variables importantes
    INSERT INTO db_config_backup (variable_name, variable_value)
    SELECT 'innodb_buffer_pool_size', @@innodb_buffer_pool_size
    UNION ALL
    SELECT 'query_cache_size', @@query_cache_size
    UNION ALL
    SELECT 'tmp_table_size', @@tmp_table_size
    UNION ALL
    SELECT 'max_connections', @@max_connections;
    
    SELECT 'Database configuration backed up' as result;
END$$
DELIMITER ;

-- ============================================
-- 14. SCRIPT DE OPTIMIZACIÓN COMPLETO
-- ============================================

DROP PROCEDURE IF EXISTS sp_full_optimization;

DELIMITER $$
CREATE PROCEDURE sp_full_optimization()
BEGIN
    DECLARE start_time TIMESTAMP;
    SET start_time = NOW();
    
    SELECT 'Starting full optimization...' as status;
    
    -- 1. Analizar tablas
    ANALYZE TABLE users, products, loans, loan_history, reservations;
    
    -- 2. Optimizar tablas
    OPTIMIZE TABLE users, products, loans;
    
    -- 3. Limpiar datos antiguos
    CALL sp_clean_old_data();
    
    -- 4. Actualizar estadísticas
    CALL sp_refresh_materialized_views();
    
    -- 5. Generar resúmenes
    CALL sp_generate_daily_summary();
    
    -- 6. Backup de configuración
    CALL sp_backup_db_config();
    
    SELECT CONCAT('Optimization completed in ', 
           TIMESTAMPDIFF(SECOND, start_time, NOW()), 
           ' seconds') as completion_message;
    
    -- Mostrar mejoras
    SHOW STATUS LIKE 'Handler_read%';
    
END$$
DELIMITER ;

-- ============================================
-- 15. MONITOREO CONTINUO
-- ============================================

-- Crear evento para optimización semanal
DROP EVENT IF EXISTS event_weekly_optimization;

DELIMITER $$
CREATE EVENT event_weekly_optimization
ON SCHEDULE EVERY 1 WEEK
STARTS TIMESTAMP(CURRENT_DATE, '03:00:00') + INTERVAL 7 DAY
DO
BEGIN
    CALL sp_full_optimization();
END$$
DELIMITER ;

-- Evento para limpieza diaria
DROP EVENT IF EXISTS event_daily_cleanup;

DELIMITER $$
CREATE EVENT event_daily_cleanup
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURRENT_DATE, '04:00:00')
DO
BEGIN
    CALL sp_clean_old_data();
    CALL sp_generate_daily_summary();
END$$
DELIMITER ;