--Corregido

USE stocksense_db;

-- ============================================
-- REPORTE 1: Productos más prestados este mes (Corregido)
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
    AND MONTH(l.loan_date) = MONTH(CURDATE())
    AND YEAR(l.loan_date) = YEAR(CURDATE())
WHERE p.is_active = 1
GROUP BY p.id, p.name, p.category, p.stock
HAVING prestamos_este_mes > 0
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
-- REPORTE 3A: Análisis temporal por dia de semana (Simplificado)
-- ============================================
SELECT 
    DAYNAME(loan_date) as dia_semana,
    COUNT(*) as prestamos,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM loans), 2) as porcentaje_total,
    -- Hora pico del día
    (SELECT HOUR(loan_date) 
     FROM loans l2 
     WHERE DAYNAME(l2.loan_date) = DAYNAME(loans.loan_date)
     GROUP BY HOUR(loan_date)
     ORDER BY COUNT(*) DESC
     LIMIT 1) as hora_pico
FROM loans
GROUP BY DAYNAME(loan_date)
ORDER BY FIELD(DAYNAME(loan_date), 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');

-- ============================================
-- REPORTE 3B: Análisis temporal por hora del día
-- ============================================
SELECT 
    HOUR(loan_date) as hora,
    COUNT(*) as prestamos,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM loans), 2) as porcentaje_total,
    -- Categorización de horario
    CASE 
        WHEN HOUR(loan_date) BETWEEN 6 AND 11 THEN 'Mañana'
        WHEN HOUR(loan_date) BETWEEN 12 AND 17 THEN 'Tarde'
        WHEN HOUR(loan_date) BETWEEN 18 AND 21 THEN 'Noche'
        ELSE 'Madrugada'
    END as periodo_dia
FROM loans
GROUP BY HOUR(loan_date)
ORDER BY hora;

-- ============================================
-- REPORTE 4: Tiempo promedio de devolución
-- ============================================
SELECT 
    p.category,
    COUNT(l.id) as total_prestamos,
    ROUND(AVG(DATEDIFF(l.actual_return_date, l.loan_date)), 2) as dias_promedio_prestamo,
    ROUND(AVG(DATEDIFF(l.actual_return_date, l.return_date)), 2) as dias_promedio_retraso,
    SUM(CASE WHEN l.actual_return_date > l.return_date THEN 1 ELSE 0 END) as prestamos_con_retraso,
    ROUND(SUM(CASE WHEN l.actual_return_date > l.return_date THEN 1 ELSE 0 END) * 100.0 / COUNT(l.id), 2) as porcentaje_retraso
FROM loans l
JOIN products p ON l.product_id = p.id
WHERE l.status = 'returned'
AND l.actual_return_date IS NOT NULL
GROUP BY p.category
ORDER BY dias_promedio_prestamo DESC;

-- ============================================
-- REPORTE 5: Predicción de stock (necesidades futuras)--(Mejorado el 4/01/26)
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
        AND l.loan_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
    WHERE p.is_active = 1
    GROUP BY p.id, p.name, p.category, p.stock, DATE_FORMAT(l.loan_date, '%Y-%m')
),
trend_analysis AS (
    SELECT 
        id,
        name,
        category,
        stock,
        AVG(COALESCE(prestamos_mes, 0)) as promedio_mensual,
        MAX(COALESCE(prestamos_mes, 0)) as maximo_mensual,
        COALESCE(STD(prestamos_mes), 0) as desviacion_estandar,
        COUNT(mes) as meses_con_datos
    FROM monthly_trend
    GROUP BY id, name, category, stock
)
SELECT 
    *,
    ROUND(promedio_mensual * 1.1, 0) as prediccion_proximo_mes,
    CASE 
        WHEN maximo_mensual > stock THEN maximo_mensual - stock
        ELSE 0
    END as stock_faltante,
    CASE 
        WHEN stock = 0 THEN 'CRÍTICO - Sin stock'
        WHEN maximo_mensual > stock * 2 THEN 'ALTO - Stock insuficiente'
        WHEN maximo_mensual > stock THEN 'MEDIO - Posible desabasto'
        ELSE 'BAJO - Stock adecuado'
    END as nivel_riesgo
FROM trend_analysis
WHERE meses_con_datos >= 3 OR stock <= 5
ORDER BY 
    FIELD(nivel_riesgo, 'CRÍTICO - Sin stock', 'ALTO - Stock insuficiente', 'MEDIO - Posible desabasto', 'BAJO - Stock adecuado'),
    stock_faltante DESC;

-- ============================================
-- REPORTE 6: Análisis de categorías (ABC Analysis)
-- ============================================
WITH category_stats AS (
    SELECT 
        p.category,
        COUNT(DISTINCT p.id) as productos_totales,
        SUM(p.stock) as stock_total,
        COUNT(l.id) as prestamos_totales,
        SUM(p.stock * 100) as valor_estimado
    FROM products p
    LEFT JOIN loans l ON p.id = l.product_id
    WHERE p.is_active = 1
    GROUP BY p.category
),
cumulative_analysis AS (
    SELECT 
        *,
        SUM(prestamos_totales) OVER (ORDER BY prestamos_totales DESC) / NULLIF(SUM(prestamos_totales) OVER (), 0) as cum_porcentaje_prestamos,
        SUM(valor_estimado) OVER (ORDER BY valor_estimado DESC) / NULLIF(SUM(valor_estimado) OVER (), 0) as cum_porcentaje_valor
    FROM category_stats
)
SELECT 
    category,
    productos_totales,
    stock_total,
    prestamos_totales,
    valor_estimado,
    ROUND(COALESCE(cum_porcentaje_prestamos, 0) * 100, 2) as porcentaje_acumulado_prestamos,
    ROUND(COALESCE(cum_porcentaje_valor, 0) * 100, 2) as porcentaje_acumulado_valor,
    CASE 
        WHEN COALESCE(cum_porcentaje_prestamos, 0) <= 0.8 THEN 'A - Alta Rotación'
        WHEN COALESCE(cum_porcentaje_prestamos, 0) <= 0.95 THEN 'B - Media Rotación'
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
    ROUND(AVG(CASE WHEN l.actual_return_date > l.return_date 
        THEN DATEDIFF(l.actual_return_date, l.return_date) 
        ELSE 0 END), 2) as promedio_retraso_dias,
    -- Frecuencia de préstamos
    ROUND(DATEDIFF(MAX(l.loan_date), MIN(l.loan_date)) / NULLIF(COUNT(l.id), 0), 2) as dias_entre_prestamos_promedio,
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
-- REPORTE 8: Eficiencia del sistema (Optimizado)
-- ============================================
WITH metrics AS (
    SELECT 
        COUNT(*) as total_products,
        SUM(CASE WHEN is_active = 1 AND stock > 0 THEN 1 ELSE 0 END) as products_available,
        SUM(stock) as total_stock,
        SUM(CASE WHEN is_active = 1 THEN stock ELSE 0 END) as active_stock
    FROM products
),
loan_metrics AS (
    SELECT 
        SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active_loans,
        SUM(CASE WHEN status = 'returned' AND actual_return_date <= return_date THEN 1 ELSE 0 END) as ontime_returns,
        SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) as total_returns,
        COUNT(DISTINCT CASE WHEN loan_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN user_id END) as active_users
    FROM loans
),
product_movement AS (
    SELECT COUNT(*) as no_movement_count
    FROM products
    WHERE is_active = 1 
    AND (last_movement_date < DATE_SUB(CURDATE(), INTERVAL 30 DAY) OR last_movement_date IS NULL)
)
SELECT 
    'Tasa de Utilización' as metric,
    CONCAT(ROUND(lm.active_loans * 100.0 / NULLIF(m.products_available, 0), 2), '%') as value
FROM metrics m, loan_metrics lm
UNION ALL
SELECT 
    'Tasa de Devolución a Tiempo',
    CONCAT(ROUND(lm.ontime_returns * 100.0 / NULLIF(lm.total_returns, 0), 2), '%')
FROM loan_metrics lm
UNION ALL
SELECT 
    'Productos sin Movimiento (30 días)',
    pm.no_movement_count
FROM product_movement pm
UNION ALL
SELECT 
    'Usuarios Activos (30 días)',
    lm.active_users
FROM loan_metrics lm
UNION ALL
SELECT 
    'Capacidad de Stock Usada',
    CONCAT(ROUND(m.active_stock * 100.0 / NULLIF(m.total_stock, 0), 2), '%')
FROM metrics m;

-- ============================================
-- REPORTE 9: Tendencia mensual (para gráficos) (Optimizado el 4/01/23)
-- ============================================
WITH monthly_loans AS (
    SELECT 
        DATE_FORMAT(l.loan_date, '%Y-%m') as periodo,
        COUNT(*) as total_prestamos,
        SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END) as activos,
        SUM(CASE WHEN l.status = 'returned' THEN 1 ELSE 0 END) as devueltos,
        SUM(CASE WHEN l.status = 'overdue' THEN 1 ELSE 0 END) as vencidos,
        SUM(CASE WHEN p.category = 'Computo' THEN 1 ELSE 0 END) as prestamos_computo
    FROM loans l
    JOIN products p ON l.product_id = p.id
    WHERE l.loan_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
    GROUP BY DATE_FORMAT(l.loan_date, '%Y-%m')
),
new_users_monthly AS (
    SELECT 
        DATE_FORMAT(created_at, '%Y-%m') as periodo,
        COUNT(*) as nuevos_usuarios
    FROM users
    WHERE role = 'student'
    AND created_at >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
    GROUP BY DATE_FORMAT(created_at, '%Y-%m')
)
SELECT 
    ml.periodo,
    ml.total_prestamos,
    ml.activos,
    ml.devueltos,
    ml.vencidos,
    ml.prestamos_computo,
    COALESCE(nu.nuevos_usuarios, 0) as nuevos_usuarios,
    LAG(ml.total_prestamos) OVER (ORDER BY ml.periodo) as prestamos_mes_anterior,
    ROUND(
        (ml.total_prestamos - LAG(ml.total_prestamos) OVER (ORDER BY ml.periodo)) * 100.0 /
        NULLIF(LAG(ml.total_prestamos) OVER (ORDER BY ml.periodo), 0),
    2) as crecimiento_porcentual
FROM monthly_loans ml
LEFT JOIN new_users_monthly nu ON ml.periodo = nu.periodo
ORDER BY ml.periodo DESC;