-- Corregido
USE stocksense_db;

-- ============================================
-- 1. CONSULTAS DE USUARIOS
-- ============================================

-- Todos los usuarios ordenados por rol
SELECT
    id,
    full_name,
    email,
    role,
    student_code,
    created_at,
    last_login,
    is_locked
FROM users
ORDER BY role, full_name;

-- Usuarios con préstamos activos
SELECT DISTINCT 
    u.*,
    COUNT(l.id) as prestamos_activos
FROM users u
JOIN loans l ON u.id = l.user_id
WHERE l.status = 'active'
GROUP BY u.id
ORDER BY prestamos_activos DESC, u.full_name;

-- Contar usuarios por rol
SELECT 
    role,
    COUNT(*) as cantidad,
    CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM users), 1), '%') as porcentaje
FROM users
GROUP BY role;

-- Usuarios bloqueados
SELECT 
    id,
    full_name,
    email,
    student_code,
    is_locked,
    locked_until,
    login_attempts
FROM users
WHERE is_locked = 1
ORDER BY locked_until DESC;

-- ============================================
-- 2. CONSULTAS DE PRODUCTOS
-- ============================================

-- Productos con stock bajo (OPTIMIZADO)
SET @threshold = (SELECT CAST(setting_value AS UNSIGNED) FROM settings WHERE setting_key = 'low_stock_threshold');

SELECT 
    p.id,
    p.name,
    p.category,
    p.stock,
    @threshold as threshold,
    (SELECT COUNT(*) FROM loans WHERE product_id = p.id AND status = 'active') as prestamos_activos,
    CASE 
        WHEN p.stock = 0 THEN 'AGOTADO'
        WHEN p.stock <= @threshold / 2 THEN 'CRÍTICO'
        WHEN p.stock <= @threshold THEN 'BAJO'
        ELSE 'OK'
    END as nivel_alerta
FROM products p
WHERE p.stock <= @threshold
AND p.is_active = 1
ORDER BY p.stock ASC, p.category;

-- Productos por categoría con estadísticas
SELECT 
    category,
    COUNT(*) as total_productos,
    SUM(stock) as total_stock,
    ROUND(AVG(stock), 2) as promedio_stock,
    MIN(stock) as min_stock,
    MAX(stock) as max_stock
FROM products
WHERE is_active = 1
GROUP BY category
ORDER BY total_productos DESC;

-- Productos más populares (más préstamos)
SELECT 
    p.id,
    p.name,
    p.category,
    p.stock,
    COUNT(l.id) as veces_prestado,
    SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END) as prestamos_activos
FROM products p
LEFT JOIN loans l ON p.id = l.product_id
WHERE p.is_active = 1
GROUP BY p.id, p.name, p.category, p.stock
ORDER BY veces_prestado DESC
LIMIT 10;

-- ============================================
-- 3. CONSULTAS DE PRÉSTAMOS
-- ============================================

-- Préstamos activos con días restantes
SELECT 
    l.id,
    u.full_name as usuario,
    u.email,
    u.student_code,
    p.name as producto,
    p.category,
    l.loan_date,
    l.return_date,
    DATEDIFF(l.return_date, CURDATE()) as dias_restantes,
    TIMESTAMPDIFF(HOUR, NOW(), l.return_date) as horas_restantes,
    CASE 
        WHEN DATEDIFF(l.return_date, CURDATE()) < 0 THEN 'VENCIDO'
        WHEN DATEDIFF(l.return_date, CURDATE()) = 0 THEN 'VENCE HOY'
        WHEN DATEDIFF(l.return_date, CURDATE()) <= 2 THEN 'POR VENCER'
        ELSE 'OK'
    END as estado_vencimiento
FROM loans l
JOIN users u ON l.user_id = u.id
JOIN products p ON l.product_id = p.id
WHERE l.status = 'active'
ORDER BY l.return_date ASC;

-- Préstamos vencidos
SELECT 
    l.id,
    u.full_name,
    u.email,
    u.student_code,
    p.name as producto,
    l.loan_date,
    l.return_date,
    DATEDIFF(CURDATE(), l.return_date) as dias_vencido,
    l.notes
FROM loans l
JOIN users u ON l.user_id = u.id
JOIN products p ON l.product_id = p.id
WHERE l.status = 'overdue'
ORDER BY dias_vencido DESC;

-- Historial de préstamos de un usuario específico
SET @user_id = 6;

SELECT 
    l.id,
    l.loan_date,
    l.return_date,
    l.actual_return_date,
    l.status,
    p.name as producto,
    p.category,
    p.qr_code,
    a.full_name as aprobado_por,
    DATEDIFF(COALESCE(l.actual_return_date, l.return_date), l.loan_date) as duracion_dias
FROM loans l
JOIN products p ON l.product_id = p.id
LEFT JOIN users a ON l.approved_by = a.id
WHERE l.user_id = @user_id
ORDER BY l.loan_date DESC;

-- ============================================
-- 4. CONSULTAS PARA DASHBOARD/REPORTES
-- ============================================

-- Estadísticas generales del sistema
SELECT 
    'Total Usuarios' as metric,
    COUNT(*) as value
FROM users
WHERE role = 'student'
UNION ALL
SELECT 
    'Total Productos',
    COUNT(*)
FROM products
WHERE is_active = 1
UNION ALL
SELECT 
    'Préstamos Activos',
    COUNT(*)
FROM loans
WHERE status = 'active'
UNION ALL
SELECT 
    'Préstamos Vencidos',
    COUNT(*)
FROM loans
WHERE status = 'overdue'
UNION ALL
SELECT 
    'Stock Total',
    SUM(stock)
FROM products
WHERE is_active = 1
UNION ALL
SELECT 
    'Notificaciones No Leídas',
    COUNT(*)
FROM notifications
WHERE is_read = 0;


-- Actividad por mes (préstamos)
SELECT 
    DATE_FORMAT(loan_date, '%Y-%m') as mes,
    DATE_FORMAT(loan_date, '%M %Y') as mes_nombre,
    COUNT(*) as total_prestamos,
    SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as activos,
    SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) as devueltos,
    SUM(CASE WHEN status = 'overdue' THEN 1 ELSE 0 END) as vencidos
FROM loans
GROUP BY DATE_FORMAT(loan_date, '%Y-%m')
ORDER BY mes DESC
LIMIT 12;

-- Top 5 categorías más prestadas
SELECT 
    p.category,
    COUNT(l.id) as prestamos_totales,
    COUNT(DISTINCT l.user_id) as usuarios_unicos,
    SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END) as prestamos_activos
FROM products p
JOIN loans l ON p.id = l.product_id
GROUP BY p.category
ORDER BY prestamos_totales DESC
LIMIT 5;

-- ============================================
-- 5. CONSULTAS DE VALIDACIÓN
-- ============================================

-- Verificar integridad de datos
SELECT 
    'Usuarios sin email' as check_type,
    COUNT(*) as problemas
FROM users
WHERE email IS NULL OR email = ''
UNION ALL
SELECT 
    'Productos sin stock negativo',
    COUNT(*)
FROM products
WHERE stock < 0
UNION ALL
SELECT 
    'Préstamos sin fecha de retorno',
    COUNT(*)
FROM loans
WHERE return_date IS NULL
UNION ALL
SELECT 
    'Préstamos con fecha de retorno anterior a préstamo',
    COUNT(*)
FROM loans
WHERE return_date < loan_date
UNION ALL
SELECT 
    'Usuarios bloqueados',
    COUNT(*)
FROM users
WHERE is_locked = 1;

-- Verificar relaciones rotas (Foreign Keys)
SELECT 
    'Préstamos sin usuario válido' as problema,
    COUNT(*) as cantidad
FROM loans l
LEFT JOIN users u ON l.user_id = u.id
WHERE u.id IS NULL
UNION ALL
SELECT 
    'Préstamos sin producto válido',
    COUNT(*)
FROM loans l
LEFT JOIN products p ON l.product_id = p.id
WHERE p.id IS NULL
UNION ALL
SELECT 
    'Notificaciones sin usuario válido',
    COUNT(*)
FROM notifications n
LEFT JOIN users u ON n.user_id = u.id
WHERE u.id IS NULL;


-- ============================================
-- 6. CONSULTAS ÚTILES PARA LA API
-- ============================================

-- Productos para API 
SELECT 
    p.id,
    p.name,
    p.description,
    p.category,
    p.stock,
    p.qr_code,
    p.image_url,
    CONCAT(
        COALESCE((SELECT setting_value FROM settings WHERE setting_key = 'base_url' LIMIT 1), 'http://localhost'),
        p.image_url
    ) as image_url_full,
    CASE 
        WHEN p.stock = 0 THEN 'out_of_stock'
        WHEN p.stock <= 3 THEN 'low_stock'
        ELSE 'available'
    END as availability,
    (SELECT COUNT(*) FROM loans WHERE product_id = p.id AND status = 'active') as currently_borrowed,
    p.created_at,
    p.updated_at
FROM products p
WHERE p.is_active = 1
ORDER BY p.category, p.name;


-- Préstamos con detalles para API
SELECT 
    l.id,
    l.loan_date,
    l.return_date,
    l.status,
    DATEDIFF(l.return_date, CURDATE()) as days_remaining,
    JSON_OBJECT(
        'id', u.id,
        'name', u.full_name,
        'email', u.email,
        'student_code', u.student_code
    ) as user,
    JSON_OBJECT(
        'id', p.id,
        'name', p.name,
        'category', p.category,
        'qr_code', p.qr_code
    ) as product
FROM loans l
JOIN users u ON l.user_id = u.id
JOIN products p ON l.product_id = p.id
WHERE l.status = 'active'
ORDER BY l.return_date;

-- ============================================
-- 7. CONSULTAS DE MANTENIMIENTO
-- ============================================

-- Limpiar logs antiguos (más de 90 días)
SELECT 
    'Logs que serán eliminados (>90 días)' as info,
    COUNT(*) as total_registros,
    MIN(created_at) as fecha_mas_antigua,
    MAX(created_at) as fecha_mas_reciente
FROM audit_log 
WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);
-- Para eliminar usar: CALL sp_clean_old_data();

-- Marcar reservas expiradas
SELECT 
    'Reservas pendientes que serán expiradas' as info,
    COUNT(*) as total_registros
FROM reservations 
WHERE status = 'pending' 
AND reservation_date < DATE_SUB(NOW(), INTERVAL 24 HOUR);

-- Actualizar estado de préstamos vencidos
SELECT 
    'Préstamos activos vencidos' as info,
    COUNT(*) as total_registros,
    GROUP_CONCAT(DISTINCT u.email SEPARATOR ', ') as usuarios_afectados
FROM loans l
JOIN users u ON l.user_id = u.id
WHERE l.status = 'active' 
AND l.return_date < NOW();
-- Nota: El trigger tr_check_overdue_loans debería manejar esto automáticamente

-- ============================================
-- 8. CONSULTAS DE BUSQUEDA
-- ============================================
-- IMPORTANTE: Estas consultas DEBEN usarse con PREPARED STATEMENTS
-- en PHP para prevenir SQL Injection. Ejemplo en PHP:
-- $stmt = $pdo->prepare("SELECT * FROM products WHERE name LIKE ? AND is_active = 1");
-- $stmt->execute(["%$search%"]);
-- Si les corre bien y si no usen eso

-- Buscar producto por nombre o descripción
-- Parámetro: @search_term
SET @search_term = 'laptop';

SELECT 
    p.*,
    (SELECT COUNT(*) FROM loans WHERE product_id = p.id) as total_loans,
    (SELECT COUNT(*) FROM loans WHERE product_id = p.id AND status = 'active') as active_loans
FROM products p
WHERE (
    p.name LIKE CONCAT('%', @search_term, '%') 
    OR p.description LIKE CONCAT('%', @search_term, '%')
    OR p.qr_code LIKE CONCAT('%', @search_term, '%')
)
AND p.is_active = 1
ORDER BY 
    CASE WHEN p.name LIKE CONCAT(@search_term, '%') THEN 1 ELSE 2 END,
    p.name;

-- Buscar usuario por nombre o código
-- Parámetro: @search_term
SET @search_term = 'juan';

SELECT 
    u.id,
    u.full_name,
    u.email,
    u.student_code,
    u.role,
    (SELECT COUNT(*) FROM loans WHERE user_id = u.id) as total_loans,
    (SELECT COUNT(*) FROM loans WHERE user_id = u.id AND status = 'active') as active_loans,
    (SELECT COUNT(*) FROM loans WHERE user_id = u.id AND status = 'overdue') as overdue_loans
FROM users u
WHERE (
    u.full_name LIKE CONCAT('%', @search_term, '%')
    OR u.email LIKE CONCAT('%', @search_term, '%')
    OR u.student_code LIKE CONCAT('%', @search_term, '%')
)
ORDER BY 
    CASE WHEN u.full_name LIKE CONCAT(@search_term, '%') THEN 1 ELSE 2 END,
    u.full_name;

-- Buscar préstamos por rango de fechas
-- Parámetros: @fecha_inicio, @fecha_fin
SET @fecha_inicio = '2025-12-01';
SET @fecha_fin = '2025-12-31';

SELECT 
    l.id,
    l.loan_date,
    l.return_date,
    l.status,
    u.full_name as usuario,
    u.email,
    p.name as producto,
    p.category,
    DATEDIFF(COALESCE(l.actual_return_date, l.return_date), l.loan_date) as duracion_dias
FROM loans l
JOIN users u ON l.user_id = u.id
JOIN products p ON l.product_id = p.id
WHERE l.loan_date BETWEEN @fecha_inicio AND @fecha_fin
ORDER BY l.loan_date DESC;

-- ============================================
-- 9. CONSULTAS ADICIONALES
-- ============================================

-- Préstamos que vencen hoy
SELECT 
    l.id,
    u.full_name,
    u.email,
    u.student_code,
    p.name as producto,
    l.return_date,
    TIMESTAMPDIFF(HOUR, NOW(), l.return_date) as horas_restantes
FROM loans l
JOIN users u ON l.user_id = u.id
JOIN products p ON l.product_id = p.id
WHERE l.status = 'active'
AND DATE(l.return_date) = CURDATE()
ORDER BY l.return_date;

-- Préstamos que vencen en próximos 3 días
SELECT 
    l.id,
    u.full_name,
    u.email,
    p.name as producto,
    l.return_date,
    DATEDIFF(l.return_date, CURDATE()) as dias_restantes
FROM loans l
JOIN users u ON l.user_id = u.id
JOIN products p ON l.product_id = p.id
WHERE l.status = 'active'
AND l.return_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 3 DAY)
ORDER BY l.return_date;

-- Usuarios sin préstamos
SELECT 
    u.id,
    u.full_name,
    u.email,
    u.student_code,
    u.created_at,
    DATEDIFF(CURDATE(), u.created_at) as dias_registrado
FROM users u
WHERE u.role = 'student'
AND NOT EXISTS (SELECT 1 FROM loans WHERE user_id = u.id)
ORDER BY u.created_at DESC;

-- Productos nunca prestados
SELECT 
    p.id,
    p.name,
    p.category,
    p.stock,
    p.created_at,
    DATEDIFF(CURDATE(), p.created_at) as dias_en_inventario
    FROM products p
WHERE p.is_active = 1
AND NOT EXISTS (SELECT 1 FROM loans WHERE product_id = p.id)
ORDER BY dias_en_inventario DESC;

-- Top 10 usuarios más activos
SELECT
    u.id,
    u.full_name,
    u.email,
    u.student_code,
    COUNT(l.id) as total_prestamos,
    SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END) as prestamos_activos,
    SUM(CASE WHEN l.status = 'returned' THEN 1 ELSE 0 END) as prestamos_devueltos,
    SUM(CASE WHEN l.status = 'overdue' THEN 1 ELSE 0 END) as prestamos_vencidos,
    MAX(l.loan_date) as ultimo_prestamo
FROM users u
LEFT JOIN loans l ON u.id = l.user_id
WHERE u.role = 'student'
GROUP BY u.id, u.full_name, u.email, u.student_code
HAVING total_prestamos > 0
ORDER BY total_prestamos DESC
LIMIT 10;
-- Notificaciones no leídas por usuario
SELECT
    u.id,
    u.full_name,
    u.email,
    COUNT(n.id) as notificaciones_no_leidas,
    GROUP_CONCAT(
    CONCAT(n.type, ': ', n.title)
    ORDER BY n.created_at DESC
    SEPARATOR ' | '
    ) as notificaciones
FROM users u
LEFT JOIN notifications n ON u.id = n.user_id AND n.is_read = 0
WHERE u.role IN ('admin', 'student')
GROUP BY u.id, u.full_name, u.email
HAVING notificaciones_no_leidas > 0
ORDER BY notificaciones_no_leidas DESC;

-- Reservas pendientes
SELECT
    r.id,
    u.full_name,
    u.email,
    u.student_code,
    p.name as producto,
    p.stock,
    r.reservation_date,
    r.pickup_date,
    TIMESTAMPDIFF(HOUR, r.reservation_date, NOW()) as horas_desde_reserva,
    r.notes,
    r.status
FROM reservations r
JOIN users u ON r.user_id = u.id
JOIN products p ON r.product_id = p.id
WHERE r.status = 'pending'
ORDER BY r.reservation_date;