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
('Juan Pérez', 'juan.perez@student.edu', 'Juan', 'student', 'STU2024001'),
('María García', 'maria.garcia@student.edu', 'María', 'student', 'STU2024002'),
('Carlos López', 'carlos.lopez@student.edu', 'Carlos', 'student', 'STU2024003'),
('Ana Rodríguez', 'ana.rodriguez@student.edu', 'Ana', 'student', 'STU2024004'),
('Pedro Martínez', 'pedro.martinez@student.edu', 'Pedro', 'student', 'STU2024005');

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
INSERT INTO loans (user_id, product_id, loan_date, return_date, status) VALUES
-- Préstamos activos (3)
(6, 1, '2024-12-20 10:30:00', '2024-12-27 18:00:00', 'active'),  -- Juan tiene Laptop
(7, 6, '2024-12-21 14:15:00', '2024-12-28 14:15:00', 'active'),  -- María tiene Microscopio
(8, 10, '2024-12-22 09:45:00', '2024-12-29 09:45:00', 'active'), -- Carlos tiene Arduino

-- Préstamos devueltos (3)
(6, 2, '2024-12-10 11:00:00', '2024-12-17 11:00:00', 'returned'),
(9, 8, '2024-12-15 16:20:00', '2024-12-22 16:20:00', 'returned'),
(7, 12, '2024-12-18 13:30:00', '2024-12-25 13:30:00', 'returned'),

-- Préstamos vencidos (2)
(8, 3, '2024-12-05 10:00:00', '2024-12-12 10:00:00', 'overdue'),
(9, 5, '2024-12-08 15:45:00', '2024-12-15 15:45:00', 'overdue');

-- ============================================
-- 4. ACTUALIZAR STOCK SEGÚN PRÉSTAMOS ACTIVOS
-- ============================================
-- Reducir stock de productos prestados actualmente
UPDATE products p
JOIN loans l ON p.id = l.product_id
SET p.stock = p.stock - 1
WHERE l.status = 'active';

-- ============================================
-- 5. DATOS ADICIONALES: Auditoría
-- ============================================
CREATE TABLE IF NOT EXISTS audit_log (
    id INT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(50) NOT NULL,
    record_id INT NOT NULL,
    action VARCHAR(20) NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    old_data JSON,
    new_data JSON,
    user_id INT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_table_record (table_name, record_id),
    INDEX idx_created_at (created_at)
);

-- Insertar algunos logs de auditoría
INSERT INTO audit_log (table_name, record_id, action, user_id, ip_address) VALUES
('products', 1, 'INSERT', 1, '192.168.1.100'),
('users', 6, 'INSERT', 1, '192.168.1.100'),
('loans', 1, 'INSERT', 2, '192.168.1.101');

-- ============================================
-- CONSULTA DE VERIFICACIÓN
-- ============================================
SELECT '=== RESUMEN DE DATOS ===' as info;
SELECT 'Usuarios:' as tipo, COUNT(*) as cantidad FROM users UNION ALL
SELECT 'Productos:', COUNT(*) FROM products UNION ALL
SELECT 'Préstamos:', COUNT(*) FROM loans UNION ALL
SELECT 'Préstamos activos:', COUNT(*) FROM loans WHERE status = 'active' UNION ALL
SELECT 'Préstamos vencidos:', COUNT(*) FROM loans WHERE status = 'overdue';