--Corregido

USE stocksense_db;

-- ============================================
-- 1. INSERTAR USUARIOS DE PRUEBA
-- ============================================
INSERT INTO users (full_name, email, password, role, student_code) VALUES
-- Administradores (5)
('Admin Principal', 'admin@stocksense.edu', 'Admin123', 'admin', NULL),
('Luis Vasquez', 'luis@stocksense.edu', 'Luis', 'admin', 'ADM001'),
('Alexis Design', 'alexis@stocksense.edu', 'Alexis', 'admin', 'ADM002'),
('Ramses Mobile', 'ramses@stocksense.edu', 'Ramses', 'admin', 'ADM003'),
('RREE21 Data', 'rree21@stocksense.edu', 'RREE21', 'admin', 'ADM004'),

-- Estudiantes (5)
('Juan Pérez', 'juan.perez@student.edu', 'Juan', 'student', 'STU2026001'),
('María García', 'maria.garcia@student.edu', 'María', 'student', 'STU2026002'),
('Carlos López', 'carlos.lopez@student.edu', 'Carlos', 'student', 'STU2026003'),
('Ana Rodríguez', 'ana.rodriguez@student.edu', 'Ana', 'student', 'STU2026004'),
('Pedro Martínez', 'pedro.martinez@student.edu', 'Pedro', 'student', 'STU2026005');

-- ============================================
-- 2. INSERTAR PRODUCTOS DE PRUEBA (15 productos)
-- ============================================
INSERT INTO products (name, description, category, stock, qr_code, image_url, is_active) VALUES
-- Computo (5)
('Laptop Lenovo ThinkPad', 'Laptop empresarial, Intel i7, 16GB RAM, 512GB SSD', 'Computo', 8, 'COMP-LAP-001', '/img/laptops/thinkpad.jpg', 1),
('MacBook Air M2', 'Apple MacBook Air 2023, chip M2, 8GB RAM, 256GB', 'Computo', 5, 'COMP-MAC-002', '/img/laptops/macbook.jpg', 1),
('Monitor Dell 24"', 'Monitor Full HD 24 pulgadas, 144Hz, HDMI/DisplayPort', 'Computo', 12, 'COMP-MON-003', '/img/monitors/dell24.jpg', 1),
('Tablet Samsung S8', 'Tablet Android, S-Pen incluido, 256GB almacenamiento', 'Computo', 7, 'COMP-TAB-004', '/img/tablets/samsung_s8.jpg', 1),
('PC Gamer', 'PC de escritorio, RTX 3060, 32GB RAM, 1TB SSD', 'Computo', 3, 'COMP-PCG-005', '/img/pcs/gamer_pc.jpg', 1),

-- Laboratorio (4)
('Microscopio Digital', 'Microscopio con cámara HD, aumento 1000x', 'Laboratorio', 5, 'LAB-MIC-006', '/img/lab/microscope.jpg', 1),
('Centrífuga 4000rpm', 'Centrífuga para laboratorio, capacidad 12 tubos', 'Laboratorio', 2, 'LAB-CEN-007', '/img/lab/centrifuge.jpg', 1),
('Pipeta Automática', 'Pipeta de precisión, rango 1-1000μL', 'Laboratorio', 15, 'LAB-PIP-008', '/img/lab/pipette.jpg', 1),
('Báscula Digital', 'Báscula de precisión 0.001g, máximo 500g', 'Laboratorio', 6, 'LAB-BAS-009', '/img/lab/scale.jpg', 1),

-- Electronica (3)
('Arduino Uno Kit', 'Kit completo Arduino Uno con sensores y componentes', 'Electronica', 12, 'ELE-ARD-010', '/img/electronics/arduino_kit.jpg', 1),
('Osciloscopio Digital', 'Osciloscopio 50MHz, 2 canales, pantalla color', 'Electronica', 4, 'ELE-OSC-011', '/img/electronics/oscilloscope.jpg', 1),
('Multímetro Profesional', 'Multímetro digital True RMS, CAT III 1000V', 'Electronica', 9, 'ELE-MUL-012', '/img/electronics/multimeter.jpg', 1),

-- Libros (2)
('Física Universitaria', 'Libro de Física, Sears-Zemansky, 14va edición', 'Libros', 20, 'LIB-FIS-013', '/img/books/physics.jpg', 1),
('Química Orgánica', 'Química Orgánica de Morrison-Boyd, 7ma edición', 'Libros', 18, 'LIB-QUI-014', '/img/books/organic_chem.jpg', 1),

-- AudioVideo (1)
('Cámara Canon EOS', 'Cámara DSLR, 24MP, kit con lente 18-55mm', 'AudioVideo', 3, 'AV-CAM-015', '/img/av/canon_eos.jpg', 1);

-- ============================================
-- 3. INSERTAR PRÉSTAMOS DE PRUEBA (8 préstamos)
-- ============================================

-- Insertar préstamos
INSERT INTO loans (user_id, product_id, loan_date, return_date, status, approved_by) VALUES
-- Préstamos activos (3)
(6, 1, '2025-12-20 10:30:00', '2026-01-27 18:00:00', 'active', 1),  -- Juan tiene Laptop
(7, 6, '2025-12-21 14:15:00', '2026-01-28 14:15:00', 'active', 1),  -- María tiene Microscopio
(8, 10, '2025-12-22 09:45:00', '2026-01-29 09:45:00', 'active', 2), -- Carlos tiene Arduino

-- Préstamos devueltos (3)
(6, 2, '2025-12-10 11:00:00', '2025-12-17 11:00:00', 'returned', 1),
(9, 8, '2025-12-15 16:20:00', '2025-12-22 16:20:00', 'returned', 2),
(7, 12, '2025-12-18 13:30:00', '2025-12-25 13:30:00', 'returned', 1),

-- Préstamos vencidos (2)
(8, 3, '2025-12-05 10:00:00', '2025-12-12 10:00:00', 'overdue', 1),
(9, 5, '2025-12-08 15:45:00', '2025-12-15 15:45:00', 'overdue', 2);

-- ============================================
-- 4. ACTUALIZAR STOCK SEGÚN PRÉSTAMOS ACTIVOS
-- ============================================

-- Actualizar stock basado en conteo de préstamos activos
UPDATE products p
SET p.stock = p.stock - (
    SELECT COUNT(*) 
    FROM loans l 
    WHERE l.product_id = p.id 
    AND l.status = 'active'
)
WHERE p.id IN (SELECT DISTINCT product_id FROM loans WHERE status = 'active');

-- ============================================
-- 5. INSERTAR REGISTROS EN LOAN_HISTORY
-- ============================================

-- Registrar el historial de los préstamos creados
INSERT INTO loan_history (loan_id, user_id, product_id, action, new_status, changed_by) VALUES
(1, 6, 1, 'created', 'active', 1),
(2, 7, 6, 'created', 'active', 1),
(3, 8, 10, 'created', 'active', 2),
(4, 6, 2, 'created', 'returned', 1),
(5, 9, 8, 'created', 'returned', 2),
(6, 7, 12, 'created', 'returned', 1),
(7, 8, 3, 'created', 'overdue', 1),
(8, 9, 5, 'created', 'overdue', 2);

-- ============================================
-- 6. INSERTAR NOTIFICACIONES DE PRUEBA
-- ============================================

INSERT INTO notifications (user_id, title, message, type, is_read) VALUES
-- Notificaciones para administradores
(1, 'Bienvenido al Sistema', 'El sistema StockSense ha sido inicializado correctamente', 'success', 1),
(1, 'Stock Bajo Alert', 'El producto "PC Gamer" tiene stock bajo: 3 unidades', 'warning', 0),
(1, 'Stock Bajo Alert', 'El producto "Centrífuga 4000rpm" tiene stock bajo: 2 unidades', 'warning', 0),

-- Notificaciones para estudiantes
(8, 'Préstamo Vencido', 'Tu préstamo del producto "Monitor Dell 24" está vencido', 'error', 0),
(9, 'Préstamo Vencido', 'Tu préstamo del producto "PC Gamer" está vencido', 'error', 0),
(6, 'Préstamo Próximo a Vencer', 'Tu préstamo vence en 7 días', 'warning', 0);

-- ============================================
-- 7. INSERTAR RESERVAS DE PRUEBA
-- ============================================

INSERT INTO reservations (user_id, product_id, reservation_date, pickup_date, status, notes) VALUES
(9, 2, NOW(), DATE_ADD(NOW(), INTERVAL 2 DAY), 'pending', 'Necesito para proyecto de tesis'),
(6, 11, NOW(), DATE_ADD(NOW(), INTERVAL 1 DAY), 'confirmed', 'Para práctica de laboratorio');

-- ============================================
-- 8. INSERTAR LOGS DE AUDITORÍA
-- ============================================

INSERT INTO audit_log (table_name, record_id, action, user_id, ip_address) VALUES
('products', 1, 'INSERT', 1, '192.168.1.100'),
('products', 2, 'INSERT', 1, '192.168.1.100'),
('users', 6, 'INSERT', 1, '192.168.1.100'),
('users', 7, 'INSERT', 1, '192.168.1.100'),
('loans', 1, 'INSERT', 1, '192.168.1.100'),
('loans', 2, 'INSERT', 1, '192.168.1.100'),
('loans', 7, 'UPDATE', 1, '192.168.1.101'),
('loans', 8, 'UPDATE', 2, '192.168.1.101');

-- ============================================
-- 9. ACTUALIZAR LAST_MOVEMENT EN PRODUCTOS
-- ============================================

UPDATE products 
SET last_movement_date = '2025-12-29 09:45:00',
    last_movement_type = 'loan'
WHERE id IN (1, 6, 10);

-- ============================================
-- 10. CONSULTA DE VERIFICACIÓN
-- ============================================

SELECT '========================================' as '';
SELECT '    RESUMEN DE DATOS INSERTADOS' as '';
SELECT '========================================' as '';

SELECT 'Usuarios:' as Tipo, COUNT(*) as Cantidad FROM users 
UNION ALL
SELECT 'Productos:', COUNT(*) FROM products 
UNION ALL
SELECT 'Categorías:', COUNT(*) FROM categories
UNION ALL
SELECT 'Préstamos Total:', COUNT(*) FROM loans 
UNION ALL
SELECT '  - Activos:', COUNT(*) FROM loans WHERE status = 'active'
UNION ALL
SELECT '  - Devueltos:', COUNT(*) FROM loans WHERE status = 'returned'
UNION ALL
SELECT '  - Vencidos:', COUNT(*) FROM loans WHERE status = 'overdue'
UNION ALL
SELECT 'Notificaciones:', COUNT(*) FROM notifications
UNION ALL
SELECT 'Reservas:', COUNT(*) FROM reservations
UNION ALL
SELECT 'Logs Auditoría:', COUNT(*) FROM audit_log;

SELECT '========================================' as '';
SELECT 'CREDENCIALES DE PRUEBA:' as '';
SELECT '========================================' as '';
SELECT 'Admin: admin@stocksense.edu / admin123' as '';
SELECT 'Student: juan.perez@student.edu / student123' as '';
SELECT '========================================' as '';
