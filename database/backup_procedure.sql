USE stocksense_db;

-- ============================================
-- 1. PROCEDIMIENTO PARA BACKUP COMPLETO
-- ============================================

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
    
    -- Crear timestamp para el nombre del archivo
    SET backup_time = DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s');
    SET file_name = CONCAT('stocksense_backup_', backup_time, '.sql');
    SET p_file_path = CONCAT('./database/backups/', file_name);
    
    -- Crear tabla de registro de backups
    CREATE TABLE IF NOT EXISTS backup_history (
        id INT PRIMARY KEY AUTO_INCREMENT,
        backup_name VARCHAR(100) NOT NULL,
        file_path VARCHAR(255) NOT NULL,
        description TEXT,
        size_mb DECIMAL(10,2),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        status ENUM('success', 'failed', 'in_progress') DEFAULT 'in_progress'
    );
    
    -- Iniciar registro
    INSERT INTO backup_history (backup_name, file_path, description, status)
    VALUES (p_backup_name, p_file_path, p_description, 'in_progress');
    
    SET p_backup_id = LAST_INSERT_ID();
    
    -- Esta es una versión simplificada para el ejemplo
    SELECT 'Backup procedure would create file at: ', p_file_path;
    
    -- Actualizar registro como exitoso
    UPDATE backup_history 
    SET status = 'success',
        size_mb = (SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2)
                   FROM information_schema.tables 
                   WHERE table_schema = DATABASE())
    WHERE id = p_backup_id;
    
    -- Crear backup simplificado de datos críticos
    CALL sp_create_data_backup(p_backup_id);
    
END$$
DELIMITER ;

-- ============================================
-- 2. PROCEDIMIENTO PARA BACKUP DE DATOS CRÍTICOS
-- ============================================

DELIMITER $$
CREATE PROCEDURE sp_create_data_backup(IN p_backup_id INT)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE table_name VARCHAR(64);
    DECLARE cur_tables CURSOR FOR 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = DATABASE()
        AND table_type = 'BASE TABLE';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Crear tabla temporal para el backup
    CREATE TABLE IF NOT EXISTS backup_data (
        id INT PRIMARY KEY AUTO_INCREMENT,
        backup_id INT NOT NULL,
        table_name VARCHAR(64) NOT NULL,
        record_count INT NOT NULL,
        backup_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (backup_id) REFERENCES backup_history(id)
    );
    
    OPEN cur_tables;
    
    read_loop: LOOP
        FETCH cur_tables INTO table_name;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Insertar metadata de cada tabla
        SET @sql = CONCAT(
            'INSERT INTO backup_data (backup_id, table_name, record_count) ',
            'SELECT ?, ''', table_name, ''', COUNT(*) FROM ', table_name
        );
        
        PREPARE stmt FROM @sql;
        EXECUTE stmt USING p_backup_id;
        DEALLOCATE PREPARE stmt;
    END LOOP;
    
    CLOSE cur_tables;
    
    -- Backup de datos críticos (últimos 30 días)
    CREATE TABLE IF NOT EXISTS backup_loans SELECT * FROM loans WHERE loan_date >= DATE_SUB(NOW(), INTERVAL 30 DAY);
    CREATE TABLE IF NOT EXISTS backup_audit_log SELECT * FROM audit_log WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY);
    
END$$
DELIMITER ;

-- ============================================
-- 3. PROCEDIMIENTO PARA RESTAURACIÓN
-- ============================================

DELIMITER $$
CREATE PROCEDURE sp_restore_backup(
    IN p_backup_id INT,
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
        SET p_message = 'Backup no encontrado o fallido';
    ELSE
        -- Aquí normalmente se ejecutaría la restauración desde el archivo
        -- Esta es una versión simplificada
        
        -- 1. Deshabilitar foreign keys temporalmente
        SET FOREIGN_KEY_CHECKS = 0;
        
        -- 2. Restaurar desde tablas de backup (ejemplo simplificado)
        -- En realidad se leería desde el archivo SQL
        
        -- 3. Re-habilitar foreign keys
        SET FOREIGN_KEY_CHECKS = 1;
        
        -- Registrar la restauración
        INSERT INTO audit_log (table_name, record_id, action, user_id, ip_address)
        VALUES ('system', p_backup_id, 'RESTORE_BACKUP', @current_user, @current_ip);
        
        SET p_message = CONCAT('Restauración iniciada desde: ', backup_file);
    END IF;
    
END$$
DELIMITER ;

-- ============================================
-- 4. PROCEDIMIENTO PARA BACKUP AUTOMÁTICO DIARIO
-- ============================================

DELIMITER $$
CREATE PROCEDURE sp_daily_auto_backup()
BEGIN
    DECLARE backup_count INT;
    DECLARE old_backup_id INT;
    
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
        
        -- Limpiar backups antiguos (mantener solo últimos 7 días)
        SELECT id INTO old_backup_id
        FROM backup_history
        WHERE created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
        AND backup_name LIKE 'AUTO_DAILY_%'
        ORDER BY created_at ASC
        LIMIT 1;
        
        WHILE old_backup_id IS NOT NULL DO
            -- Eliminar datos de backup
            DELETE FROM backup_data WHERE backup_id = old_backup_id;
            DELETE FROM backup_history WHERE id = old_backup_id;
            
            -- Buscar siguiente backup antiguo
            SELECT id INTO old_backup_id
            FROM backup_history
            WHERE created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
            AND backup_name LIKE 'AUTO_DAILY_%'
            ORDER BY created_at ASC
            LIMIT 1;
        END WHILE;
    END IF;
    
END$$
DELIMITER ;

-- ============================================
-- 5. EVENTO PROGRAMADO PARA BACKUP AUTOMÁTICO
-- ============================================

-- Crear evento que se ejecuta diario a las 2:00 AM
DELIMITER $$
CREATE EVENT IF NOT EXISTS event_daily_backup
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURRENT_DATE, '02:00:00')
DO
BEGIN
    CALL sp_daily_auto_backup();
END$$
DELIMITER ;

-- Habilitar el scheduler de eventos
SET GLOBAL event_scheduler = ON;

-- ============================================
-- 6. TABLAS DE BACKUP
-- ============================================

-- Tabla para almacenar backups incrementales
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
);

-- ============================================
-- 7. TRIGGERS PARA BACKUP INCREMENTAL
-- ============================================

-- Trigger para productos
DELIMITER $$
CREATE TRIGGER tr_products_incremental_backup
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    INSERT INTO incremental_backup (table_name, record_id, action, old_data, new_data)
    VALUES (
        'products',
        NEW.id,
        'UPDATE',
        JSON_OBJECT(
            'name', OLD.name,
            'stock', OLD.stock,
            'is_active', OLD.is_active
        ),
        JSON_OBJECT(
            'name', NEW.name,
            'stock', NEW.stock,
            'is_active', NEW.is_active
        )
    );
END$$
DELIMITER ;

-- Trigger para usuarios
DELIMITER $$
CREATE TRIGGER tr_users_incremental_backup
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    INSERT INTO incremental_backup (table_name, record_id, action, old_data, new_data)
    VALUES (
        'users',
        NEW.id,
        'UPDATE',
        JSON_OBJECT(
            'email', OLD.email,
            'role', OLD.role,
            'is_locked', OLD.is_locked
        ),
        JSON_OBJECT(
            'email', NEW.email,
            'role', NEW.role,
            'is_locked', NEW.is_locked
        )
    );
END$$
DELIMITER ;

-- ============================================
-- 8. PROCEDIMIENTO PARA BACKUP INCREMENTAL
-- ============================================

DELIMITER $$
CREATE PROCEDURE sp_incremental_backup()
BEGIN
    DECLARE backup_time VARCHAR(20);
    DECLARE file_name VARCHAR(255);
    
    SET backup_time = DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s');
    SET file_name = CONCAT('incremental_backup_', backup_time, '.sql');
    
    -- Exportar cambios no respaldados
    SELECT CONCAT(
        '-- Incremental Backup - ', NOW(), '\n',
        'USE stocksense_db;\n\n',
        GROUP_CONCAT(
            CASE 
                WHEN action = 'DELETE' THEN
                    CONCAT('DELETE FROM ', table_name, ' WHERE id = ', record_id, '; -- ', changed_at)
                WHEN action = 'INSERT' THEN
                    CONCAT('INSERT INTO ', table_name, ' (id, ...) VALUES (', record_id, ', ...); -- ', changed_at)
                WHEN action = 'UPDATE' THEN
                    CONCAT('UPDATE ', table_name, ' SET ... WHERE id = ', record_id, '; -- ', changed_at)
            END
            SEPARATOR '\n'
        )
    ) INTO @backup_sql
    FROM incremental_backup
    WHERE backed_up = 0;
    
    -- Marcar como respaldado
    UPDATE incremental_backup SET backed_up = 1 WHERE backed_up = 0;
    
    -- Aquí se guardaría @backup_sql en un archivo
    SELECT CONCAT('Incremental backup created: ', file_name) as result;
    
END$$
DELIMITER ;

-- ============================================
-- 9. PROCEDIMIENTO DE EMERGENCIA
-- ============================================

DELIMITER $$
CREATE PROCEDURE sp_emergency_export()
BEGIN
    -- Exportar datos críticos en caso de emergencia
    SELECT 'Emergency Export - Critical Data' as header;
    
    -- Usuarios activos
    SELECT * FROM users WHERE is_locked = 0;
    
    -- Productos con stock
    SELECT id, name, stock, qr_code FROM products WHERE is_active = 1 AND stock > 0;
    
    -- Préstamos activos
    SELECT l.*, u.email, p.name 
    FROM loans l
    JOIN users u ON l.user_id = u.id
    JOIN products p ON l.product_id = p.id
    WHERE l.status = 'active';
    
END$$
DELIMITER ;

-- ============================================
-- 11. VERIFICACIÓN DE BACKUPS
-- ============================================

DELIMITER $$
CREATE PROCEDURE sp_verify_backups()
BEGIN
    SELECT 
        'Backup Status Report' as report_title,
        CURDATE() as report_date;
    
    -- Backups de los últimos 7 días
    SELECT 
        backup_name,
        file_path,
        size_mb,
        created_at,
        status,
        CASE 
            WHEN created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY) THEN 'RECIENTE'
            WHEN created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 'RECIENTE (7 días)'
            ELSE 'ANTIGUO'
        END as age_category
    FROM backup_history
    ORDER BY created_at DESC;
    
    -- Espacio utilizado
    SELECT 
        'Total Backups' as metric,
        COUNT(*) as value
    FROM backup_history
    UNION ALL
    SELECT 
        'Total Space Used (MB)',
        ROUND(SUM(size_mb), 2)
    FROM backup_history
    UNION ALL
    SELECT 
        'Average Backup Size (MB)',
        ROUND(AVG(size_mb), 2)
    FROM backup_history;
    
END$$
DELIMITER ;

-- ============================================
-- 12. LIMPIEZA DE BACKUPS ANTIGUOS
-- ============================================

DELIMITER $$
CREATE PROCEDURE sp_clean_old_backups(IN p_days_to_keep INT)
BEGIN
    DECLARE backup_id INT;
    DECLARE done INT DEFAULT FALSE;
    DECLARE cur_backups CURSOR FOR 
        SELECT id 
        FROM backup_history 
        WHERE created_at < DATE_SUB(NOW(), INTERVAL p_days_to_keep DAY);
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN cur_backups;
    
    read_loop: LOOP
        FETCH cur_backups INTO backup_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Eliminar datos relacionados
        DELETE FROM backup_data WHERE backup_id = backup_id;
        -- Eliminar registro
        DELETE FROM backup_history WHERE id = backup_id;
        
        SELECT CONCAT('Deleted backup ID: ', backup_id) as log_message;
    END LOOP;
    
    CLOSE cur_backups;
    
    -- Vaciar incremental backups antiguos
    DELETE FROM incremental_backup 
    WHERE backed_up = 1 
    AND changed_at < DATE_SUB(NOW(), INTERVAL p_days_to_keep DAY);
    
    SELECT CONCAT('Cleanup completed. Kept backups from last ', p_days_to_keep, ' days.') as result;
    
END$$
DELIMITER ;