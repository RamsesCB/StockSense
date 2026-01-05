-- Corregido y añadido cosas nuevas

USE stocksense_db;

-- ============================================
-- 1. HABILITAR EVENT SCHEDULER
-- ============================================

SET GLOBAL event_scheduler = ON;

-- ============================================
-- 2. OPTIMIZACIÓN DE ÍNDICES
-- ============================================

-- Crear índices faltantes para consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_products_name_category ON products(name, category);
CREATE INDEX IF NOT EXISTS idx_loans_dates_status ON loans(loan_date, return_date, status);
CREATE INDEX IF NOT EXISTS idx_users_email_role ON users(email, role);

-- Índices adicionales para reportes
CREATE INDEX IF NOT EXISTS idx_loans_date_product ON loans(loan_date, product_id);
CREATE INDEX IF NOT EXISTS idx_loans_user_dates ON loans(user_id, loan_date, return_date);
CREATE INDEX IF NOT EXISTS idx_loan_history_changed_at ON loan_history(changed_at);
CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, is_read);

-- ============================================
-- 3. OPTIMIZACIÓN DE TABLAS
-- ============================================

-- Optimizar tablas fragmentadas
OPTIMIZE TABLE users;
OPTIMIZE TABLE products;
OPTIMIZE TABLE loans;
OPTIMIZE TABLE loan_history;
OPTIMIZE TABLE notifications;
OPTIMIZE TABLE reservations;

-- Analizar tablas para optimizar estadísticas
ANALYZE TABLE users;
ANALYZE TABLE products;
ANALYZE TABLE loans;
ANALYZE TABLE loan_history;

-- ============================================
-- 4. VISTAS MATERIALIZADAS
-- ============================================

-- Tabla para estadísticas diarias
CREATE TABLE IF NOT EXISTS mv_daily_stats (
    stat_date DATE PRIMARY KEY,
    total_users INT DEFAULT 0,
    total_products INT DEFAULT 0,
    active_loans INT DEFAULT 0,
    overdue_loans INT DEFAULT 0,
    returned_loans INT DEFAULT 0,
    low_stock_items INT DEFAULT 0,
    new_users_today INT DEFAULT 0,
    avg_loan_duration DECIMAL(5,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_stat_date (stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 5. PROCEDIMIENTO PARA ACTUALIZAR VISTAS MATERIALIZADAS
-- ============================================

DROP PROCEDURE IF EXISTS sp_refresh_materialized_views;

DELIMITER $$
CREATE PROCEDURE sp_refresh_materialized_views()
BEGIN
    DECLARE v_today DATE;
    DECLARE v_threshold INT;
    
    SET v_today = CURDATE();
    
    -- Obtener threshold de stock bajo
    SELECT CAST(setting_value AS UNSIGNED) INTO v_threshold
    FROM settings 
    WHERE setting_key = 'low_stock_threshold'
    LIMIT 1;
    
    -- Actualizar estadísticas diarias
    INSERT INTO mv_daily_stats (
        stat_date,
        total_users,
        total_products,
        active_loans,
        overdue_loans,
        returned_loans,
        low_stock_items,
        new_users_today,
        avg_loan_duration
    )
    SELECT 
        v_today,
        (SELECT COUNT(*) FROM users WHERE role = 'student'),
        (SELECT COUNT(*) FROM products WHERE is_active = 1),
        (SELECT COUNT(*) FROM loans WHERE status = 'active'),
        (SELECT COUNT(*) FROM loans WHERE status = 'overdue'),
        (SELECT COUNT(*) FROM loans WHERE status = 'returned' AND DATE(actual_return_date) = v_today),
        (SELECT COUNT(*) FROM products WHERE stock <= v_threshold AND is_active = 1),
        (SELECT COUNT(*) FROM users WHERE DATE(created_at) = v_today AND role = 'student'),
        (SELECT AVG(DATEDIFF(return_date, loan_date)) FROM loans WHERE status = 'returned')
    ON DUPLICATE KEY UPDATE
        total_users = VALUES(total_users),
        total_products = VALUES(total_products),
        active_loans = VALUES(active_loans),
        overdue_loans = VALUES(overdue_loans),
        returned_loans = VALUES(returned_loans),
        low_stock_items = VALUES(low_stock_items),
        new_users_today = VALUES(new_users_today),
        avg_loan_duration = VALUES(avg_loan_duration),
        updated_at = CURRENT_TIMESTAMP;
    
    SELECT 'Materialized views refreshed' as result;
END$$
DELIMITER ;

-- ============================================
-- 6. LIMPIEZA Y MANTENIMIENTO
-- ============================================

DROP PROCEDURE IF EXISTS sp_clean_old_data;

DELIMITER $$
CREATE PROCEDURE sp_clean_old_data()
BEGIN
    DECLARE rows_deleted INT DEFAULT 0;
    
    -- Mantener logs de auditoría por 90 días
    DELETE FROM audit_log 
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);
    SET rows_deleted = rows_deleted + ROW_COUNT();
    
    -- Mantener historial de préstamos completos por 1 año
    DELETE FROM loan_history 
    WHERE changed_at < DATE_SUB(NOW(), INTERVAL 365 DAY);
    SET rows_deleted = rows_deleted + ROW_COUNT();
    
    -- Mantener notificaciones leídas por 30 días
    DELETE FROM notifications 
    WHERE is_read = 1 
    AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);
    SET rows_deleted = rows_deleted + ROW_COUNT();
    
    -- Eliminar reservas expiradas antiguas
    DELETE FROM reservations 
    WHERE status = 'expired' 
    AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY);
    SET rows_deleted = rows_deleted + ROW_COUNT();
    
    -- Limpiar logs de performance antiguos
    DELETE FROM performance_log 
    WHERE executed_at < DATE_SUB(NOW(), INTERVAL 30 DAY);
    SET rows_deleted = rows_deleted + ROW_COUNT();
    
    -- Limpiar estadísticas antiguas (mantener 1 año)
    DELETE FROM mv_daily_stats 
    WHERE stat_date < DATE_SUB(CURDATE(), INTERVAL 365 DAY);
    SET rows_deleted = rows_deleted + ROW_COUNT();
    
    SELECT CONCAT('Old data cleaned successfully. Rows deleted: ', rows_deleted) as result;
END$$
DELIMITER ;

-- ============================================
-- 7. MONITOREO DE PERFORMANCE
-- ============================================

CREATE TABLE IF NOT EXISTS performance_log (
    id INT PRIMARY KEY AUTO_INCREMENT,
    query_type VARCHAR(50),
    execution_time_ms DECIMAL(10,2),
    rows_affected INT,
    table_name VARCHAR(50),
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_host VARCHAR(100),
    
    INDEX idx_executed_at (executed_at),
    INDEX idx_table_name (table_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 8. RESUMEN DIARIO DE PRÉSTAMOS
-- ============================================

CREATE TABLE IF NOT EXISTS summary_daily_loans (
    id INT PRIMARY KEY AUTO_INCREMENT,
    summary_date DATE NOT NULL,
    category VARCHAR(50) NOT NULL,
    loan_count INT DEFAULT 0,
    unique_users INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY idx_date_category (summary_date, category),
    INDEX idx_summary_date (summary_date),
    INDEX idx_category (category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP PROCEDURE IF EXISTS sp_generate_daily_summary;

DELIMITER $$
CREATE PROCEDURE sp_generate_daily_summary()
BEGIN
    DECLARE yesterday DATE;
    SET yesterday = DATE_SUB(CURDATE(), INTERVAL 1 DAY);
    
    -- Resumen por categoría
    INSERT INTO summary_daily_loans (summary_date, category, loan_count, unique_users)
    SELECT 
        DATE(l.loan_date) as summary_date,
        p.category,
        COUNT(l.id) as loan_count,
        COUNT(DISTINCT l.user_id) as unique_users
    FROM loans l
    JOIN products p ON l.product_id = p.id
    WHERE DATE(l.loan_date) = yesterday
    GROUP BY DATE(l.loan_date), p.category
    ON DUPLICATE KEY UPDATE
        loan_count = VALUES(loan_count),
        unique_users = VALUES(unique_users),
        updated_at = CURRENT_TIMESTAMP;
    
    SELECT CONCAT('Daily summary generated for ', yesterday) as result;
END$$
DELIMITER ;

-- ============================================
-- 9. BACKUP DE CONFIGURACIONES
-- ============================================

CREATE TABLE IF NOT EXISTS db_config_backup (
    id INT PRIMARY KEY AUTO_INCREMENT,
    variable_name VARCHAR(100),
    variable_value VARCHAR(500),
    backed_up_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_backed_up_at (backed_up_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP PROCEDURE IF EXISTS sp_backup_db_config;

DELIMITER $$
CREATE PROCEDURE sp_backup_db_config()
BEGIN
    -- Backup de variables importantes (Compatible MySQL 5.7 y 8.0+ me avisan si no es compatible)
    INSERT INTO db_config_backup (variable_name, variable_value)
    SELECT 'innodb_buffer_pool_size', @@innodb_buffer_pool_size
    UNION ALL
    SELECT 'tmp_table_size', @@tmp_table_size
    UNION ALL
    SELECT 'max_connections', @@max_connections
    UNION ALL
    SELECT 'innodb_log_file_size', @@innodb_log_file_size
    UNION ALL
    SELECT 'max_allowed_packet', @@max_allowed_packet
    UNION ALL
    SELECT 'mysql_version', VERSION();
    
    SELECT 'Database configuration backed up' as result;
END$$
DELIMITER ;

-- ============================================
-- 10. HEALTH CHECK (VERIFICACIÓN DE SALUD)
-- ============================================

DROP PROCEDURE IF EXISTS sp_health_check;

DELIMITER $$
CREATE PROCEDURE sp_health_check()
BEGIN
    -- Tamaño y fragmentación de tablas
    SELECT 
        '=== TAMAÑO DE TABLAS ===' as info;
    
    SELECT 
        TABLE_NAME,
        ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) AS size_mb,
        TABLE_ROWS,
        ROUND(DATA_FREE / 1024 / 1024, 2) AS fragmentation_mb,
        ROUND((DATA_FREE / (DATA_LENGTH + INDEX_LENGTH)) * 100, 2) AS fragmentation_pct
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_TYPE = 'BASE TABLE'
    ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;
    
    -- Eventos activos
    SELECT 
        '=== EVENTOS PROGRAMADOS ===' as info;
    
    SELECT 
        EVENT_NAME,
        STATUS,
        LAST_EXECUTED,
        INTERVAL_VALUE,
        INTERVAL_FIELD
    FROM information_schema.EVENTS
    WHERE EVENT_SCHEMA = DATABASE();
    
    -- Estadísticas generales
    SELECT 
        '=== ESTADÍSTICAS GENERALES ===' as info;
    
    SELECT 
        'Total Usuarios' as metric,
        COUNT(*) as value
    FROM users
    UNION ALL
    SELECT 
        'Total Productos',
        COUNT(*)
    FROM products
    UNION ALL
    SELECT 
        'Préstamos Activos',
        COUNT(*)
    FROM loans
    WHERE status = 'active'
    UNION ALL
    SELECT 
        'Stock Total',
        SUM(stock)
    FROM products
    WHERE is_active = 1;
END$$
DELIMITER ;

-- ============================================
-- 11. SCRIPT DE OPTIMIZACIÓN COMPLETO
-- ============================================

DROP PROCEDURE IF EXISTS sp_full_optimization;

DELIMITER $$
CREATE PROCEDURE sp_full_optimization()
BEGIN
    DECLARE start_time TIMESTAMP;
    DECLARE exit handler for sqlexception
    BEGIN
        ROLLBACK;
        SELECT 'Optimization failed! Rolling back...' as error_message;
    END;
    
    SET start_time = NOW();
    
    SELECT 'Starting full optimization...' as status;
    
    -- 1. Analizar tablas
    SELECT '1. Analyzing tables...' as step;
    ANALYZE TABLE users, products, loans, loan_history, reservations, notifications;
    
    -- 2. Optimizar tablas
    SELECT '2. Optimizing tables...' as step;
    OPTIMIZE TABLE users, products, loans, notifications;
    
    -- 3. Limpiar datos antiguos
    SELECT '3. Cleaning old data...' as step;
    CALL sp_clean_old_data();
    
    -- 4. Actualizar estadísticas
    SELECT '4. Refreshing materialized views...' as step;
    CALL sp_refresh_materialized_views();
    
    -- 5. Generar resúmenes
    SELECT '5. Generating daily summary...' as step;
    CALL sp_generate_daily_summary();
    
    -- 6. Backup de configuración
    SELECT '6. Backing up configuration...' as step;
    CALL sp_backup_db_config();
    
    SELECT CONCAT('✓ Optimization completed in ', 
           TIMESTAMPDIFF(SECOND, start_time, NOW()), 
           ' seconds') as completion_message;
END$$
DELIMITER ;

-- ============================================
-- 12. EVENTOS PROGRAMADOS
-- ============================================

-- Evento para optimización semanal (Domingos a las 3:00 AM)
DROP EVENT IF EXISTS event_weekly_optimization;

DELIMITER $$
CREATE EVENT event_weekly_optimization
ON SCHEDULE EVERY 1 WEEK
STARTS DATE_ADD(DATE_ADD(CURDATE(), INTERVAL (7 - WEEKDAY(CURDATE())) % 7 DAY), INTERVAL '03:00:00' HOUR_SECOND)
DO
BEGIN
    CALL sp_full_optimization();
END$$
DELIMITER ;

-- Evento para limpieza diaria (Todos los días a las 4:00 AM)
DROP EVENT IF EXISTS event_daily_cleanup;

DELIMITER $$
CREATE EVENT event_daily_cleanup
ON SCHEDULE EVERY 1 DAY
STARTS DATE_ADD(DATE_ADD(CURDATE(), INTERVAL 1 DAY), INTERVAL '04:00:00' HOUR_SECOND)
DO
BEGIN
    CALL sp_clean_old_data();
    CALL sp_generate_daily_summary();
    CALL sp_refresh_materialized_views();
END$$
DELIMITER ;

-- Evento para actualizar vistas materializadas cada hora
DROP EVENT IF EXISTS event_hourly_stats_update;

DELIMITER $$
CREATE EVENT event_hourly_stats_update
ON SCHEDULE EVERY 1 HOUR
STARTS DATE_ADD(DATE_ADD(CURDATE(), INTERVAL HOUR(NOW()) + 1 HOUR), INTERVAL -MINUTE(NOW()) MINUTE)
DO
BEGIN
    CALL sp_refresh_materialized_views();
END$$
DELIMITER ;

-- ============================================
-- 13. VERIFICAR ESTADO DE EVENTOS
-- ============================================

SELECT 
    EVENT_NAME,
    STATUS,
    EVENT_TYPE,
    INTERVAL_VALUE,
    INTERVAL_FIELD,
    STARTS,
    LAST_EXECUTED,
    CREATED
FROM information_schema.EVENTS
WHERE EVENT_SCHEMA = DATABASE();

-- ============================================
-- FIN DE OPTIMIZACIÓN
-- ============================================
SELECT '========================================' as '';
SELECT '   OPTIMIZACIÓN COMPLETADA' as '';
SELECT '========================================' as '';
SELECT 'Ejecuta: CALL sp_health_check(); para ver el estado del sistema' as '';
SELECT 'Ejecuta: CALL sp_full_optimization(); para optimizar manualmente' as '';