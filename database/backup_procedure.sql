-- Corregido 

USE stocksense_db;

-- ==========================
-- ELIMINAR TRIGGERS ANTIGUOS
-- ==========================

DROP TRIGGER IF EXISTS tr_products_before_update;
DROP TRIGGER IF EXISTS tr_users_before_update;

-- ============================================
-- 1. TABLAS DE BACKUP
-- ============================================

-- Tabla de historial de backups
CREATE TABLE IF NOT EXISTS backup_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    backup_name VARCHAR(100) NOT NULL,
    file_path VARCHAR(255) NOT NULL,
    description TEXT,
    size_mb DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('success', 'failed', 'in_progress') DEFAULT 'in_progress',
    
    INDEX idx_status (status),
    INDEX idx_created_at (created_at),
    INDEX idx_backup_name (backup_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de metadata de backups
CREATE TABLE IF NOT EXISTS backup_data (
    id INT PRIMARY KEY AUTO_INCREMENT,
    backup_id INT NOT NULL,
    table_name VARCHAR(64) NOT NULL,
    record_count INT NOT NULL,
    backup_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (backup_id) REFERENCES backup_history(id) ON DELETE CASCADE,
    INDEX idx_backup_id (backup_id),
    INDEX idx_table_name (table_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla para backups incrementales
CREATE TABLE IF NOT EXISTS incremental_backup (
    id INT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(64) NOT NULL,
    record_id INT NOT NULL,
    action ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    old_data JSON,
    new_data JSON,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    backed_up TINYINT(1) DEFAULT 0,
    
    INDEX idx_table_record (table_name, record_id),
    INDEX idx_backed_up (backed_up),
    INDEX idx_changed_at (changed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 2. PROCEDIMIENTO PARA BACKUP COMPLETO
-- ============================================

DROP PROCEDURE IF EXISTS sp_create_backup;

DELIMITER $$
CREATE PROCEDURE sp_create_backup(
    IN p_backup_name VARCHAR(100),
    IN p_description TEXT,
    OUT p_backup_id INT,
    OUT p_file_path VARCHAR(255)
)
BEGIN
    DECLARE backup_time VARCHAR(20);
    DECLARE file_name VARCHAR(255);
    DECLARE v_size_mb DECIMAL(10,2);
    
    -- Crear timestamp para el nombre del archivo
    SET backup_time = DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s');
    SET file_name = CONCAT('stocksense_backup_', backup_time, '.sql');
    SET p_file_path = CONCAT('./database/backups/', file_name);
    
    -- Calcular tamaño aproximado
    SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) INTO v_size_mb
    FROM information_schema.tables 
    WHERE table_schema = DATABASE();
    
    -- Iniciar registro
    INSERT INTO backup_history (backup_name, file_path, description, status, size_mb)
    VALUES (p_backup_name, p_file_path, p_description, 'in_progress', v_size_mb);
    
    SET p_backup_id = LAST_INSERT_ID();
    
    -- Crear backup de datos críticos
    CALL sp_create_data_backup(p_backup_id);
    
    -- Actualizar registro como exitoso
    UPDATE backup_history 
    SET status = 'success'
    WHERE id = p_backup_id;
    
    SELECT CONCAT('✓ Backup creado: ', p_file_path, ' (', v_size_mb, ' MB)') as result;
    
END$$
DELIMITER ;

-- ============================================
-- 3. PROCEDIMIENTO PARA BACKUP DE DATOS CRÍTICOS
-- ============================================

DROP PROCEDURE IF EXISTS sp_create_data_backup;

DELIMITER $$
CREATE PROCEDURE sp_create_data_backup(IN p_backup_id INT)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_table_name VARCHAR(64);
    DECLARE v_record_count INT;
    DECLARE cur_tables CURSOR FOR 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = DATABASE()
        AND table_type = 'BASE TABLE'
        AND table_name NOT LIKE 'backup_%';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN cur_tables;
    
    read_loop: LOOP
        FETCH cur_tables INTO v_table_name;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Contar registros de cada tabla
        SET @count_sql = CONCAT('SELECT COUNT(*) INTO @v_record_count FROM ', v_table_name);
        PREPARE stmt FROM @count_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        
        -- Insertar metadata
        INSERT INTO backup_data (backup_id, table_name, record_count)
        VALUES (p_backup_id, v_table_name, @v_record_count);
        
    END LOOP;
    
    CLOSE cur_tables;
    
    -- Backup de datos críticos (últimos 30 días)
    DROP TABLE IF EXISTS backup_loans;
    CREATE TABLE backup_loans ENGINE=ARCHIVE AS 
    SELECT * FROM loans WHERE loan_date >= DATE_SUB(NOW(), INTERVAL 30 DAY);
    
    DROP TABLE IF EXISTS backup_audit_log;
    CREATE TABLE backup_audit_log ENGINE=ARCHIVE AS 
    SELECT * FROM audit_log WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY);
    
    SELECT CONCAT(
        'Respaldados ', 
        (SELECT COUNT(*) FROM backup_loans), ' préstamos y ',
        (SELECT COUNT(*) FROM backup_audit_log), ' logs de auditoría'
    ) as critical_data_backup;
    
END$$
DELIMITER ;

-- ============================================
-- 4. PROCEDIMIENTO PARA BACKUP DE TABLA INDIVIDUAL
-- ============================================

DROP PROCEDURE IF EXISTS sp_backup_table;

DELIMITER $$
CREATE PROCEDURE sp_backup_table(
    IN p_table_name VARCHAR(64),
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE table_exists INT;
    DECLARE backup_table_name VARCHAR(128);
    
    -- Verificar si la tabla existe
    SELECT COUNT(*) INTO table_exists
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
    AND table_name = p_table_name;
    
    IF table_exists = 0 THEN
        SET p_message = CONCAT('ERROR: Tabla ', p_table_name, ' no existe');
    ELSE
        -- Crear nombre de backup con timestamp
        SET backup_table_name = CONCAT(
            'backup_', 
            p_table_name, 
            '_', 
            DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s')
        );
        
        -- Crear backup de la tabla
        SET @sql = CONCAT(
            'CREATE TABLE ', backup_table_name, 
            ' ENGINE=ARCHIVE AS SELECT * FROM ', p_table_name
        );
        
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        
        -- Contar registros
        SET @count_sql = CONCAT('SELECT COUNT(*) FROM ', backup_table_name, ' INTO @row_count');
        PREPARE stmt FROM @count_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        
        SET p_message = CONCAT(
            '✓ Backup creado: ', backup_table_name, 
            ' (', @row_count, ' registros)'
        );
    END IF;
    
    SELECT p_message as result;
END$$
DELIMITER ;

-- ============================================
-- 5. PROCEDIMIENTO PARA RESTAURACIÓN
-- ============================================

DROP PROCEDURE IF EXISTS sp_restore_backup;

DELIMITER $$
CREATE PROCEDURE sp_restore_backup(
    IN p_backup_id INT,
    IN p_restored_by INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE backup_file VARCHAR(255);
    DECLARE backup_exists INT;
    
    -- Verificar si el backup existe
    SELECT COUNT(*), file_path INTO backup_exists, backup_file
    FROM backup_history
    WHERE id = p_backup_id AND status = 'success';
    
    IF backup_exists = 0 THEN
        SET p_message = 'ERROR: Backup no encontrado o fallido';
    ELSE
        -- Registrar la restauración en auditoría
        INSERT INTO audit_log (table_name, record_id, action, user_id)
        VALUES ('system', p_backup_id, 'RESTORE_BACKUP', p_restored_by);
        
        SET p_message = CONCAT(
            'Restauración registrada. ',
            'Archivo: ', backup_file, '. ',
            'Ejecutar manualmente: mysql -u user -p stocksense_db < ', backup_file
        );
    END IF;
    
    SELECT p_message as result;
    
END$$
DELIMITER ;

-- ============================================
-- 6. PROCEDIMIENTO PARA BACKUP AUTOMÁTICO DIARIO
-- ============================================

DROP PROCEDURE IF EXISTS sp_daily_auto_backup;

DELIMITER $$
CREATE PROCEDURE sp_daily_auto_backup()
BEGIN
    DECLARE backup_count INT;
    
    -- Contar backups de hoy
    SELECT COUNT(*) INTO backup_count
    FROM backup_history
    WHERE DATE(created_at) = CURDATE()
    AND backup_name LIKE 'AUTO_DAILY_%';
    
    -- Si no hay backup hoy, crear uno
    IF backup_count = 0 THEN
        CALL sp_create_backup(
            CONCAT('AUTO_DAILY_', DATE_FORMAT(CURDATE(), '%Y%m%d')),
            'Backup automático diario',
            @backup_id,
            @file_path
        );
        
        -- Limpiar backups automáticos antiguos (mantener 7 días)
        CALL sp_clean_old_backups(7, 1, @deleted_count);
        
        SELECT CONCAT('✓ Backup diario completado. ID: ', @backup_id) as result;
    ELSE
        SELECT 'Backup diario ya existe para hoy' as result;
    END IF;
    
END$$
DELIMITER ;

-- ============================================
-- 7. TRIGGERS CONSOLIDADOS (BACKUP INCREMENTAL)
-- ============================================

-- Trigger para productos (Consolidado)
DELIMITER $$
CREATE TRIGGER tr_products_before_update
BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
    -- Validaciones originales
    SET NEW.updated_at = CURRENT_TIMESTAMP;
    
    IF NEW.stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock cannot be negative';
    END IF;
    
    -- Backup incremental
    INSERT INTO incremental_backup (table_name, record_id, action, old_data, new_data)
    VALUES (
        'products',
        NEW.id,
        'UPDATE',
        JSON_OBJECT('name', OLD.name, 'stock', OLD.stock, 'is_active', OLD.is_active),
        JSON_OBJECT('name', NEW.name, 'stock', NEW.stock, 'is_active', NEW.is_active)
    );
END$$
DELIMITER ;

-- Trigger para usuarios (Consolidado)
DELIMITER $$
CREATE TRIGGER tr_users_before_update
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
    -- Validación original
    SET NEW.updated_at = CURRENT_TIMESTAMP;
    
    -- Backup incremental
    INSERT INTO incremental_backup (table_name, record_id, action, old_data, new_data)
    VALUES (
        'users',
        NEW.id,
        'UPDATE',
        JSON_OBJECT('email', OLD.email, 'role', OLD.role, 'is_locked', OLD.is_locked),
        JSON_OBJECT('email', NEW.email, 'role', NEW.role, 'is_locked', NEW.is_locked)
    );
END$$
DELIMITER ;

-- ============================================
-- 8. PROCEDIMIENTO PARA BACKUP INCREMENTAL
-- ============================================

DROP PROCEDURE IF EXISTS sp_incremental_backup;

DELIMITER $$
CREATE PROCEDURE sp_incremental_backup()
BEGIN
    DECLARE backup_time VARCHAR(20);
    DECLARE file_name VARCHAR(255);
    DECLARE changes_count INT;
    
    -- Contar cambios pendientes
    SELECT COUNT(*) INTO changes_count
    FROM incremental_backup
    WHERE backed_up = 0;
    
    IF changes_count = 0 THEN
        SELECT 'ℹ No hay cambios pendientes para respaldar' as result;
    ELSE
        SET backup_time = DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s');
        SET file_name = CONCAT('incremental_backup_', backup_time, '.sql');
        
        -- Marcar como respaldado
        UPDATE incremental_backup SET backed_up = 1 WHERE backed_up = 0;
        
        SELECT CONCAT(
            '✓ Backup incremental creado: ', file_name, 
            ' (', changes_count, ' cambios)'
        ) as result;
    END IF;
    
END$$
DELIMITER ;

-- ============================================
-- 9. PROCEDIMIENTO DE EMERGENCIA
-- ============================================

DROP PROCEDURE IF EXISTS sp_emergency_export;

DELIMITER $$
CREATE PROCEDURE sp_emergency_export()
BEGIN
    SELECT '========================================' as '';
    SELECT '   EXPORTACIÓN DE EMERGENCIA' as '';
    SELECT '========================================' as '';
    
    -- Usuarios activos
    SELECT '--- USUARIOS ACTIVOS ---' as section;
    SELECT id, full_name, email, role, student_code, created_at
    FROM users 
    WHERE is_locked = 0
    ORDER BY role, full_name;
    
    -- Productos con stock
    SELECT '--- PRODUCTOS DISPONIBLES ---' as section;
    SELECT id, name, category, stock, qr_code, is_active
    FROM products 
    WHERE is_active = 1 AND stock > 0
    ORDER BY category, name;
    
    -- Préstamos activos
    SELECT '--- PRÉSTAMOS ACTIVOS ---' as section;
    SELECT 
        l.id,
        l.loan_date,
        l.return_date,
        u.full_name as usuario,
        u.email,
        p.name as producto,
        p.qr_code
    FROM loans l
    JOIN users u ON l.user_id = u.id
    JOIN products p ON l.product_id = p.id
    WHERE l.status = 'active'
    ORDER BY l.return_date;
    
    SELECT '========================================' as '';
    SELECT CONCAT('Exportado: ', NOW()) as timestamp;
    
END$$
DELIMITER ;

-- ============================================
-- 10. VERIFICACIÓN DE BACKUPS
-- ============================================

DROP PROCEDURE IF EXISTS sp_verify_backups;

DELIMITER $$
CREATE PROCEDURE sp_verify_backups()
BEGIN
    SELECT '========================================' as '';
    SELECT '   REPORTE DE ESTADO DE BACKUPS' as '';
    SELECT '========================================' as '';
    SELECT CONCAT('Fecha: ', DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i:%s')) as '';
    SELECT '========================================' as '';
    
    -- Backups recientes
    SELECT 
        backup_name,
        file_path,
        size_mb,
        DATE_FORMAT(created_at, '%Y-%m-%d %H:%i') as fecha,
        status,
        CASE 
            WHEN created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY) THEN '✓ RECIENTE'
            WHEN created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN '⚠ 7 días'
            ELSE '⚠ ANTIGUO'
        END as age_category
    FROM backup_history
    ORDER BY created_at DESC
    LIMIT 10;
    
    -- Estadísticas
    SELECT '========================================' as '';
    SELECT '   ESTADÍSTICAS' as '';
    SELECT '========================================' as '';
    
    SELECT 
        'Total Backups' as metric,
        COUNT(*) as value
    FROM backup_history
    UNION ALL
    SELECT 
        'Espacio Total (MB)',
        ROUND(SUM(size_mb), 2)
    FROM backup_history
    UNION ALL
    SELECT 
        'Tamaño Promedio (MB)',
        ROUND(AVG(size_mb), 2)
    FROM backup_history
    UNION ALL
    SELECT 
        'Backups Exitosos',
        COUNT(*)
    FROM backup_history
    WHERE status = 'success'
    UNION ALL
    SELECT 
        'Backups Fallidos',
        COUNT(*)
    FROM backup_history
    WHERE status = 'failed';
    
END$$
DELIMITER ;

-- ================================
-- 11. LIMPIEZA DE BACKUPS ANTIGUOS
-- ================================

DROP PROCEDURE IF EXISTS sp_clean_old_backups;

DELIMITER $$
CREATE PROCEDURE sp_clean_old_backups(
    IN p_days_to_keep INT,
    IN p_confirm TINYINT(1),
    OUT p_deleted_count INT
)
BEGIN
    DECLARE backup_id_var INT;
    DECLARE done INT DEFAULT FALSE;
    DECLARE cur_backups CURSOR FOR 
        SELECT id 
        FROM backup_history 
        WHERE created_at < DATE_SUB(NOW(), INTERVAL p_days_to_keep DAY)
        AND backup_name LIKE 'AUTO_DAILY_%';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    SET p_deleted_count = 0;
    
    IF p_confirm != 1 THEN
        -- Vista previa
        SELECT 
            'VISTA PREVIA - NO se eliminó nada' as info,
            COUNT(*) as backups_a_eliminar,
            ROUND(SUM(size_mb), 2) as mb_a_liberar
        FROM backup_history
        WHERE created_at < DATE_SUB(NOW(), INTERVAL p_days_to_keep DAY)
        AND backup_name LIKE 'AUTO_DAILY_%';
        
        SELECT 'Ejecuta con p_confirm = 1 para confirmar eliminación' as mensaje;
    ELSE
        -- Eliminar backups
        OPEN cur_backups;
        
        read_loop: LOOP
            FETCH cur_backups INTO backup_id_var;
            IF done THEN
                LEAVE read_loop;
            END IF;
            
            DELETE FROM backup_data WHERE backup_id = backup_id_var;
            DELETE FROM backup_history WHERE id = backup_id_var;
            
            SET p_deleted_count = p_deleted_count + 1;
        END LOOP;
        
        CLOSE cur_backups;
        
        -- Limpiar backups incrementales antiguos
        DELETE FROM incremental_backup 
        WHERE backed_up = 1 
        AND changed_at < DATE_SUB(NOW(), INTERVAL p_days_to_keep DAY);
        
        SELECT CONCAT(
            '✓ Limpieza completada. Eliminados: ', p_deleted_count, 
            ' backups automáticos. Se mantienen últimos ', p_days_to_keep, ' días.'
        ) as result;
    END IF;
END$$
DELIMITER ;

-- ============================================
-- 12. EVENTO PROGRAMADO PARA BACKUP AUTOMÁTICO
-- ============================================

DROP EVENT IF EXISTS event_daily_backup;

DELIMITER $$
CREATE EVENT event_daily_backup
ON SCHEDULE EVERY 1 DAY
STARTS DATE_ADD(DATE_ADD(CURDATE(), INTERVAL 1 DAY), INTERVAL '02:00:00' HOUR_SECOND)
DO
BEGIN
    CALL sp_daily_auto_backup();
END$$
DELIMITER ;

-- Habilitar event scheduler
SET GLOBAL event_scheduler = ON;

-- ============================================
-- FIN DE BACKUP PROCEDURES
-- ============================================

SELECT '========================================' as '';
SELECT '   BACKUP SYSTEM INITIALIZED' as '';
SELECT '========================================' as '';
SELECT 'Ejecuta: CALL sp_verify_backups(); para ver el estado' as '';
SELECT 'Ejecuta: CALL sp_create_backup("Manual_Backup", "Descripción", @id, @path); para backup manual' as '';
SELECT 'Ejecuta: CALL sp_emergency_export(); para exportación de emergencia' as '';
SELECT '========================================' as '';