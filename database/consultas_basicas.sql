==============================

USE stocksense_db;

-- ============================================
-- 1. CONSULTAS DE USUARIOS
-- ============================================

-- Todos los usuarios ordenados por rol
SELECT id, full_name, email, role, student_code, created_at
FROM users
ORDER BY role, full_name;

-- Usuarios con préstamos activos
SELECT DISTINCT u.*
FROM users u
JOIN loans l ON u.id = l.user_id
WHERE l.status = 'active'
ORDER BY u.full_name;

-- Contar usuarios por rol
SELECT 
    role,
    COUNT(*) as cantidad,
    CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM users), 1), '%') as porcentaje
FROM users
GROUP BY role;

-- ============================================
-- 2. CONSULTAS DE PRODUCTOS
-- ============================================

-- Productos con stock bajo (usando configuración)
SELECT p.*, s.setting_value as threshold
FROM products p
CROSS JOIN (SELECT setting_value FROM settings WHERE setting_key = 'low_stock_threshold') s
WHERE p.stock <= s.setting_value
AND p.is_active = 1
ORDER BY p.stock ASC;

-- Productos por categoría con estadísticas
SELECT 
    category,
    COUNT(*) as total_productos,
    SUM(stock) as total_stock,
    AVG(stock) as promedio_stock,
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
    COUNT(l.id) as veces_prestado
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
    p.name as producto,
    l.loan_date,
    l.return_date,
    DATEDIFF(l.return_date, CURDATE()) as dias_restantes,
    CASE 
        WHEN DATEDIFF(l.return_date, CURDATE()) < 0 THEN 'VENCIDO'
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
    p.name,
    l.loan_date,
    l.return_date,
    DATEDIFF(CURDATE(), l.return_date) as dias_vencido
FROM loans l
JOIN users u ON l.user_id = u.id
JOIN products p ON l.product_id = p.id
WHERE l.status = 'overdue'
ORDER BY l.return_date ASC;

-- Historial de préstamos de un usuario específico
SELECT 
    l.loan_date,
    l.return_date,
    l.actual_return_date,
    l.status,
    p.name as producto,
    p.category,
    a.full_name as aprobado_por
FROM loans l
JOIN products p ON l.product_id = p.id
LEFT JOIN users a ON l.approved_by = a.id
WHERE l.user_id = 6  -- ID del usuario
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
WHERE is_active = 1;

-- Actividad por mes (préstamos)
SELECT 
    DATE_FORMAT(loan_date, '%Y-%m') as mes,
    COUNT(*) as total_prestamos,
    SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) as devueltos,
    SUM(CASE WHEN status = 'overdue' THEN 1 ELSE 0 END) as vencidos
FROM loans
GROUP BY DATE_FORMAT(loan_date, '%Y-%m')
ORDER BY mes DESC
LIMIT 6;

-- Top 5 categorías más prestadas
SELECT 
    p.category,
    COUNT(l.id) as prestamos_totales,
    COUNT(DISTINCT l.user_id) as usuarios_unicos
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
    'Productos sin stock',
    COUNT(*)
FROM products
WHERE stock < 0
UNION ALL
SELECT 
    'Préstamos sin fecha de retorno',
    COUNT(*)
FROM loans
WHERE return_date IS NULL;

-- Verificar relaciones rotas
SELECT 
    'Préstamos sin usuario' as problema,
    COUNT(*) as cantidad
FROM loans l
LEFT JOIN users u ON l.user_id = u.id
WHERE u.id IS NULL
UNION ALL
SELECT 
    'Préstamos sin producto',
    COUNT(*)
FROM loans l
LEFT JOIN products p ON l.product_id = p.id
WHERE p.id IS NULL;

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
    CONCAT('http://your-server.com', p.image_url) as image_url_full,
    CASE 
        WHEN p.stock = 0 THEN 'out_of_stock'
        WHEN p.stock <= 3 THEN 'low_stock'
        ELSE 'available'
    END as availability
FROM products p
WHERE p.is_active = 1
ORDER BY p.category, p.name;

-- Préstamos con detalles para API
SELECT 
    l.id,
    l.loan_date,
    l.return_date,
    l.status,
    u.full_name as user_name,
    u.email as user_email,
    p.name as product_name,
    p.qr_code
FROM loans l
JOIN users u ON l.user_id = u.id
JOIN products p ON l.product_id = p.id
WHERE l.status = 'active'
ORDER BY l.return_date;

-- ============================================
-- 7. CONSULTAS DE MANTENIMIENTO
-- ============================================

-- Limpiar logs antiguos (más de 90 días)
DELETE FROM audit_log 
WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);

-- Marcar reservas expiradas
UPDATE reservations 
SET status = 'expired'
WHERE status = 'pending' 
AND reservation_date < DATE_SUB(NOW(), INTERVAL 24 HOUR);

-- Actualizar estado de préstamos vencidos
UPDATE loans 
SET status = 'overdue'
WHERE status = 'active' 
AND return_date < NOW();

-- ============================================
-- 8. CONSULTAS DE BUSQUEDA
-- ============================================

-- Buscar producto por nombre o descripción
SELECT * FROM products 
WHERE (name LIKE '%laptop%' OR description LIKE '%laptop%')
AND is_active = 1;

-- Buscar usuario por nombre o código
SELECT * FROM users 
WHERE full_name LIKE '%juan%' 
OR email LIKE '%juan%'
OR student_code LIKE '%001%';

-- Buscar préstamos por rango de fechas
SELECT * FROM loans 
WHERE loan_date BETWEEN '2024-12-01' AND '2024-12-31'
ORDER BY loan_date DESC;