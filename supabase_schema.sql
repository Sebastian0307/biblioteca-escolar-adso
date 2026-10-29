-- =============================================================================
-- PROYECTO: SISTEMA DE GESTIÓN DE BIBLIOTECA ESCOLAR (SENA 2026)
-- MOTOR: PostgreSQL (Supabase)
-- DESCRIPCIÓN: Esquema completo de tablas y datos semilla (10+ registros)
-- =============================================================================

-- Limpieza opcional (en orden inverso a las dependencias)
DROP TABLE IF EXISTS devoluciones CASCADE;
DROP TABLE IF EXISTS prestamos CASCADE;
DROP TABLE IF EXISTS solicitudes_prestamo CASCADE;
DROP TABLE IF EXISTS ejemplares_libro CASCADE;
DROP TABLE IF EXISTS libros CASCADE;
DROP TABLE IF EXISTS login CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;

-- 1. TABLA: usuarios
CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    documento VARCHAR(30) UNIQUE NOT NULL,
    tipo_usuario VARCHAR(20) NOT NULL CHECK (tipo_usuario IN ('estudiante', 'profesor', 'administrador'))
);

-- 2. TABLA: login
CREATE TABLE login (
    id_login SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    documento VARCHAR(30) UNIQUE NOT NULL,
    contrasena VARCHAR(255) NOT NULL
);

-- 3. TABLA: libros
CREATE TABLE libros (
    id_libro SERIAL PRIMARY KEY,
    codigo_libro VARCHAR(50) UNIQUE NOT NULL,
    titulo VARCHAR(200) NOT NULL,
    autor VARCHAR(150) NOT NULL,
    area VARCHAR(100) NOT NULL,
    anio_publicacion INTEGER NOT NULL
);

-- 4. TABLA: ejemplares_libro
CREATE TABLE ejemplares_libro (
    id_ejemplar SERIAL PRIMARY KEY,
    id_libro INTEGER NOT NULL REFERENCES libros(id_libro) ON DELETE CASCADE,
    codigo_inventario VARCHAR(50) UNIQUE NOT NULL,
    condicion VARCHAR(20) NOT NULL DEFAULT 'bueno' CHECK (condicion IN ('bueno', 'regular')),
    disponibilidad VARCHAR(20) NOT NULL DEFAULT 'disponible' CHECK (disponibilidad IN ('disponible', 'prestado', 'mantenimiento'))
);

-- 5. TABLA: solicitudes_prestamo
CREATE TABLE solicitudes_prestamo (
    id_solicitud SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    id_ejemplar INTEGER NOT NULL REFERENCES ejemplares_libro(id_ejemplar) ON DELETE CASCADE,
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'aprobada', 'rechazada'))
);

-- 6. TABLA: prestamos
CREATE TABLE prestamos (
    id_prestamo SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    id_libro INTEGER NOT NULL REFERENCES libros(id_libro) ON DELETE CASCADE,
    id_ejemplar INTEGER NOT NULL REFERENCES ejemplares_libro(id_ejemplar) ON DELETE CASCADE,
    fecha_prestamo DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_devolucion DATE NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo', 'devuelto'))
);

-- 7. TABLA: devoluciones
CREATE TABLE devoluciones (
    id_devolucion SERIAL PRIMARY KEY,
    id_prestamo INTEGER NOT NULL REFERENCES prestamos(id_prestamo) ON DELETE CASCADE,
    fecha_devolucion DATE NOT NULL DEFAULT CURRENT_DATE,
    observaciones TEXT
);

-- =============================================================================
-- DATOS DE PRUEBA (10+ REGISTROS POR TABLA PRINCIPAL)
-- Nota: La contraseña inicial de cada usuario es igual a su número de documento.
-- El endpoint POST /seed o el primer inicio de sesión encripta con bcrypt.
-- =============================================================================

INSERT INTO usuarios (nombre, apellido, documento, tipo_usuario) VALUES
('Carlos', 'Ramírez', '10001001', 'administrador'),
('Laura', 'Gómez', '10001002', 'administrador'),
('Andrés', 'Martínez', '20002001', 'profesor'),
('María', 'Fernández', '20002002', 'profesor'),
('Jorge', 'Hernández', '20002003', 'profesor'),
('Valentina', 'López', '30003001', 'estudiante'),
('Santiago', 'García', '30003002', 'estudiante'),
('Camila', 'Rodríguez', '30003003', 'estudiante'),
('Mateo', 'Sánchez', '30003004', 'estudiante'),
('Isabella', 'Torres', '30003005', 'estudiante'),
('Sebastián', 'Díaz', '30003006', 'estudiante'),
('Sofía', 'Morales', '30003007', 'estudiante');

-- Contraseñas de texto plano iniciales (el backend soporta validación híbrida y hasheo automático con bcrypt)
INSERT INTO login (id_usuario, documento, contrasena) VALUES
(1, '10001001', '10001001'),
(2, '10001002', '10001002'),
(3, '20002001', '20002001'),
(4, '20002002', '20002002'),
(5, '20002003', '20002003'),
(6, '30003001', '30003001'),
(7, '30003002', '30003002'),
(8, '30003003', '30003003'),
(9, '30003004', '30003004'),
(10, '30003005', '30003005'),
(11, '30003006', '30003006'),
(12, '30003007', '30003007');

INSERT INTO libros (codigo_libro, titulo, autor, area, anio_publicacion) VALUES
('LIB-001', 'Cien años de soledad', 'Gabriel García Márquez', 'Literatura', 1967),
('LIB-002', 'El amor en los tiempos del cólera', 'Gabriel García Márquez', 'Literatura', 1985),
('LIB-003', 'Álgebra de Baldor', 'Aurelio Baldor', 'Matemáticas', 1941),
('LIB-004', 'Física Universitaria Vol. 1', 'Sears y Zemansky', 'Ciencias Naturales', 2018),
('LIB-005', 'Química: La Ciencia Central', 'Theodore L. Brown', 'Ciencias Naturales', 2014),
('LIB-006', 'Historia de Colombia', 'Jesús María Henao', 'Ciencias Sociales', 2010),
('LIB-007', 'Clean Code', 'Robert C. Martin', 'Tecnología e Informática', 2008),
('LIB-008', 'El Principito', 'Antoine de Saint-Exupéry', 'Literatura', 1943),
('LIB-009', 'Biología de Campbell', 'Neil A. Campbell', 'Ciencias Naturales', 2020),
('LIB-010', 'Gramática de la Lengua Española', 'Real Academia Española', 'Humanidades', 2015),
('LIB-011', 'Cálculo de una Variable', 'James Stewart', 'Matemáticas', 2017),
('LIB-012', 'La Vorágine', 'José Eustasio Rivera', 'Literatura', 1924);

INSERT INTO ejemplares_libro (id_libro, codigo_inventario, condicion, disponibilidad) VALUES
(1, 'INV-001-A', 'bueno', 'disponible'),
(1, 'INV-001-B', 'bueno', 'prestado'),
(2, 'INV-002-A', 'bueno', 'disponible'),
(3, 'INV-003-A', 'bueno', 'disponible'),
(3, 'INV-003-B', 'regular', 'disponible'),
(4, 'INV-004-A', 'bueno', 'disponible'),
(5, 'INV-005-A', 'bueno', 'disponible'),
(6, 'INV-006-A', 'regular', 'disponible'),
(7, 'INV-007-A', 'bueno', 'disponible'),
(7, 'INV-007-B', 'bueno', 'disponible'),
(8, 'INV-008-A', 'bueno', 'disponible'),
(9, 'INV-009-A', 'bueno', 'mantenimiento'),
(10, 'INV-010-A', 'bueno', 'disponible'),
(11, 'INV-011-A', 'bueno', 'disponible'),
(12, 'INV-012-A', 'bueno', 'disponible');

INSERT INTO solicitudes_prestamo (id_usuario, id_ejemplar, estado) VALUES
(6, 2, 'aprobada'),
(7, 4, 'pendiente'),
(8, 9, 'pendiente'),
(9, 1, 'aprobada');

INSERT INTO prestamos (id_usuario, id_libro, id_ejemplar, fecha_prestamo, fecha_devolucion, estado) VALUES
(6, 1, 2, CURRENT_DATE - INTERVAL '3 days', NULL, 'activo'),
(9, 1, 1, CURRENT_DATE - INTERVAL '10 days', CURRENT_DATE - INTERVAL '2 days', 'devuelto');

INSERT INTO devoluciones (id_prestamo, fecha_devolucion, observaciones) VALUES
(2, CURRENT_DATE - INTERVAL '2 days', 'Entregado a tiempo y en buen estado físico.');
