USE stocksense_db;

-- ============================================
-- REPORTE 1: Productos más prestados este mes
-- ============================================
SELECT 
    p.id,
    p.name,
    p.category,
    p.stock,
    COUNT(l.id) as prestamos_este_mes,
    -- Comparación con mes anterior
    (SELECT COUNT(*) 
     FROM loans l2 
     WHERE l2.product_id = p.id 
     AND MONTH(l2.loan_date) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
     AND YEAR(l2.loan_date) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
    ) as prestamos_mes_anterior,
    -- Tasa de uso (préstamos/stock)
    ROUND(COUNT(l.id) * 100.0 / GREATEST(p.stock, 1), 2) as tasa_uso_porcentaje
FROM products p
LEFT JOIN loans l ON p.id = l.product_id
WHERE MONTH(l.loan_date) = MONTH(CURDATE())
AND YEAR(l.loan_date) = YEAR(CURDATE())
AND p.is_active = 1
GROUP BY p.id, p.name, p.category, p.stock
ORDER BY prestamos_este_mes DESC
LIMIT 10;

-- ============================================
-- REPORTE 2: Análisis de usuarios recurrentes
-- ============================================
WITH user_loan_stats AS (
    SELECT 
        u.id,
        u.full_name,
        u.email,
        u.student_code,
        COUNT(l.id) as total_prestamos,
        COUNT(DISTINCT p.category) as categorias_diferentes,
        MAX(l.loan_date) as ultimo_prestamo,
        MIN(l.loan_date) as primer_prestamo,
        DATEDIFF(MAX(l.loan_date), MIN(l.loan_date)) as rango_dias,
        SUM(CASE WHEN l.status = 'overdue' THEN 1 ELSE 0 END) as prestamos_vencidos
    FROM users u
    LEFT JOIN loans l ON u.id = l.user_id
    LEFT JOIN products p ON l.product_id = p.id
    WHERE u.role = 'student'
    GROUP BY u.id, u.full_name, u.email, u.student_code
)
SELECT 
    *,
    CASE 
        WHEN total_prestamos = 0 THEN 'Nunca ha prestado'
        WHEN total_prestamos >= 10 THEN 'Usuario Frecuente'
        WHEN total_prestamos >= 5 THEN 'Usuario Regular'
        ELSE 'Usuario Ocasional'
    END as segmentacion,
    CASE 
        WHEN rango_dias = 0 THEN 0
        ELSE ROUND(total_prestamos * 30.0 / rango_dias, 2)
    END as tasa_mensual_estimada
FROM user_loan_stats
ORDER BY total_prestamos DESC;

-- ============================================
-- REPORTE 3: Análisis temporal por hora/día
-- ============================================
SELECT 
    -- Por día de la semana
    DAYNAME(loan_date) as dia_semana,
    COUNT(*) as prestamos,
    -- Por hora del día
    HOUR(loan_date) as hora,
    COUNT(*) as prestamos_por_hora,
    -- Porcentaje del total
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM loans), 2) as porcentaje_total
FROM loans
GROUP BY DAYNAME(loan_date), HOUR(loan_date)
WITH ROLLUP
HAVING dia_semana IS NOT NULL OR hora IS NULL
ORDER BY 
    FIELD(dia_semana, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'),
    hora;

-- ============================================
-- REPORTE 4: Tiempo promedio de devolución
-- ============================================
SELECT 
    p.category,
    COUNT(l.id) as total_prestamos,
    AVG(DATEDIFF(l.actual_return_date, l.loan_date)) as dias_promedio_prestamo,
    AVG(DATEDIFF(l.actual_return_date, l.return_date)) as dias_promedio_retraso,
    SUM(CASE WHEN l.actual_return_date > l.return_date THEN 1 ELSE 0 END) as prestamos_con_retraso,
    ROUND(SUM(CASE WHEN l.actual_return_date > l.return_date THEN 1 ELSE 0 END) * 100.0 / COUNT(l.id), 2) as porcentaje_retraso
FROM loans l
JOIN products p ON l.product_id = p.id
WHERE l.status = 'returned'
AND l.actual_return_date IS NOT NULL
GROUP BY p.category
ORDER BY dias_promedio_prestamo DESC;

-- ============================================
-- REPORTE 5: Predicción de stock (necesidades futuras)
-- ============================================
WITH monthly_trend AS (
    SELECT 
        p.id,
        p.name,
        p.category,
        p.stock,
        DATE_FORMAT(l.loan_date, '%Y-%m') as mes,
        COUNT(l.id) as prestamos_mes
    FROM products p
    LEFT JOIN loans l ON p.id = l.product_id
    WHERE l.loan_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
    GROUP BY p.id, p.name, p.category, p.stock, DATE_FORMAT(l.loan_date, '%Y-%m')
),
trend_analysis AS (
    SELECT 
        id,
        name,
        category,
        stock,
        AVG(prestamos_mes) as promedio_mensual,
        MAX(prestamos_mes) as maximo_mensual,
        STD(prestamos_mes) as desviacion_estandar,
        COUNT(mes) as meses_con_datos
    FROM monthly_trend
    GROUP BY id, name, category, stock
)
SELECT 
    *,
    -- Predicción para próximo mes (promedio + 10% por crecimiento)
    ROUND(promedio_mensual * 1.1, 0) as prediccion_proximo_mes,
    -- Stock necesario para cubrir máxima demanda
    CASE 
        WHEN maximo_mensual > stock THEN maximo_mensual - stock
        ELSE 0
    END as stock_faltante,
    -- Nivel de riesgo
    CASE 
        WHEN stock = 0 THEN 'CRÍTICO - Sin stock'
        WHEN maximo_mensual > stock * 2 THEN 'ALTO - Stock insuficiente'
        WHEN maximo_mensual > stock THEN 'MEDIO - Posible desabasto'
        ELSE 'BAJO - Stock adecuado'
    END as nivel_riesgo
FROM trend_analysis
WHERE meses_con_datos >= 3  -- Solo productos con historial
ORDER BY nivel_riesgo, stock_faltante DESC;

-- ============================================
-- REPORTE 6: Análisis de categorías (ABC Analysis)
-- ============================================
WITH category_stats AS (
    SELECT 
        p.category,
        COUNT(DISTINCT p.id) as productos_totales,
        SUM(p.stock) as stock_total,
        COUNT(l.id) as prestamos_totales,
        SUM(p.stock * 100) as valor_estimado  -- Asumiendo un valor por producto
    FROM products p
    LEFT JOIN loans l ON p.id = l.product_id
    WHERE p.is_active = 1
    GROUP BY p.category
),
cumulative_analysis AS (
    SELECT 
        *,
        SUM(prestamos_totales) OVER (ORDER BY prestamos_totales DESC) / SUM(prestamos_totales) OVER () as cum_porcentaje_prestamos,
        SUM(valor_estimado) OVER (ORDER BY valor_estimado DESC) / SUM(valor_estimado) OVER () as cum_porcentaje_valor
    FROM category_stats
)
SELECT 
    category,
    productos_totales,
    stock_total,
    prestamos_totales,
    valor_estimado,
    ROUND(cum_porcentaje_prestamos * 100, 2) as porcentaje_acumulado_prestamos,
    ROUND(cum_porcentaje_valor * 100, 2) as porcentaje_acumulado_valor,
    CASE 
        WHEN cum_porcentaje_prestamos <= 0.8 THEN 'A - Alta Rotación'
        WHEN cum_porcentaje_prestamos <= 0.95 THEN 'B - Media Rotación'
        ELSE 'C - Baja Rotación'
    END as clasificacion_abc
FROM cumulative_analysis
ORDER BY prestamos_totales DESC;

-- ============================================
-- REPORTE 7: Usuarios con patrones de riesgo
-- ============================================
SELECT 
    u.id,
    u.full_name,
    u.email,
    u.student_code,
    -- Estadísticas básicas
    COUNT(l.id) as total_prestamos,
    SUM(CASE WHEN l.status = 'overdue' THEN 1 ELSE 0 END) as prestamos_vencidos,
    SUM(CASE WHEN l.status = 'active' AND l.return_date < CURDATE() THEN 1 ELSE 0 END) as prestamos_actualmente_vencidos,
    -- Patrones de riesgo
    MAX(DATEDIFF(l.actual_return_date, l.return_date)) as max_retraso_dias,
    AVG(CASE WHEN l.actual_return_date > l.return_date 
        THEN DATEDIFF(l.actual_return_date, l.return_date) 
        ELSE 0 END) as promedio_retraso_dias,
    -- Frecuencia de préstamos
    DATEDIFF(MAX(l.loan_date), MIN(l.loan_date)) / NULLIF(COUNT(l.id), 0) as dias_entre_prestamos_promedio,
    -- Calificación de riesgo
    CASE 
        WHEN SUM(CASE WHEN l.status = 'overdue' THEN 1 ELSE 0 END) >= 3 THEN 'ALTO RIESGO'
        WHEN SUM(CASE WHEN l.status = 'overdue' THEN 1 ELSE 0 END) >= 1 THEN 'RIESGO MODERADO'
        WHEN COUNT(l.id) = 0 THEN 'SIN HISTORIAL'
        ELSE 'BAJO RIESGO'
    END as nivel_riesgo_usuario
FROM users u
LEFT JOIN loans l ON u.id = l.user_id
WHERE u.role = 'student'
GROUP BY u.id, u.full_name, u.email, u.student_code
HAVING total_prestamos > 0
ORDER BY prestamos_vencidos DESC, nivel_riesgo_usuario;

-- ============================================
-- REPORTE 8: Eficiencia del sistema
-- ============================================
SELECT 
    -- Tasa de utilización
    'Tasa de Utilización' as metric,
    CONCAT(ROUND(
        (SELECT COUNT(*) FROM loans WHERE status = 'active') * 100.0 / 
        (SELECT COUNT(*) FROM products WHERE is_active = 1 AND stock > 0), 
    2), '%') as value
UNION ALL
SELECT 
    'Tasa de Devolución a Tiempo',
    CONCAT(ROUND(
        (SELECT COUNT(*) FROM loans WHERE status = 'returned' AND actual_return_date <= return_date) * 100.0 /
        NULLIF((SELECT COUNT(*) FROM loans WHERE status = 'returned'), 0),
    2), '%')
UNION ALL
SELECT 
    'Productos sin Movimiento (30 días)',
    (SELECT COUNT(*) 
     FROM products p
     WHERE p.is_active = 1 
     AND p.last_movement_date < DATE_SUB(CURDATE(), INTERVAL 30 DAY)
     OR p.last_movement_date IS NULL)
UNION ALL
SELECT 
    'Usuarios Activos (30 días)',
    (SELECT COUNT(DISTINCT user_id)
     FROM loans 
     WHERE loan_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY))
UNION ALL
SELECT 
    'Capacidad de Stock Usada',
    CONCAT(ROUND(
        (SELECT SUM(stock) FROM products WHERE is_active = 1) * 100.0 /
        NULLIF((SELECT SUM(stock) FROM products), 0),
    2), '%');

-- ============================================
-- REPORTE 9: Tendencia mensual (para gráficos)
-- ============================================
SELECT 
    DATE_FORMAT(loan_date, '%Y-%m') as periodo,
    -- Totales
    COUNT(*) as total_prestamos,
    -- Por estado
    SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as activos,
    SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) as devueltos,
    SUM(CASE WHEN status = 'overdue' THEN 1 ELSE 0 END) as vencidos,
    -- Por categoría (ejemplo: Cómputo)
    SUM(CASE WHEN p.category = 'Computo' THEN 1 ELSE 0 END) as prestamos_computo,
    -- Nuevos usuarios ese mes
    (SELECT COUNT(*) 
     FROM users u2 
     WHERE DATE_FORMAT(u2.created_at, '%Y-%m') = DATE_FORMAT(loans.loan_date, '%Y-%m')
     AND u2.role = 'student') as nuevos_usuarios,
    -- Tasa de crecimiento
    LAG(COUNT(*)) OVER (ORDER BY DATE_FORMAT(loan_date, '%Y-%m')) as prestamos_mes_anterior,
    ROUND(
        (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY DATE_FORMAT(loan_date, '%Y-%m'))) * 100.0 /
        NULLIF(LAG(COUNT(*)) OVER (ORDER BY DATE_FORMAT(loan_date, '%Y-%m')), 0),
    2) as crecimiento_porcentual
FROM loans l
JOIN products p ON l.product_id = p.id
WHERE loan_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY DATE_FORMAT(loan_date, '%Y-%m')
ORDER BY periodo DESC;