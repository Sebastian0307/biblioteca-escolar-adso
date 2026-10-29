# INFORME TÉCNICO DEL PROYECTO: SISTEMA DE GESTIÓN DE BIBLIOTECA ESCOLAR

**SENA REGIONAL CAUCA — CENTRO DE TELEINFORMÁTICA Y PRODUCCIÓN INDUSTRIAL (CTPI - ADSO)**  
**Actividad de Conocimiento:** Analizar los requisitos del cliente para construir el sistema de información  
**Proyecto:** Biblioteca Escolar (Backend Node.js + Express + Sequelize | Frontend Flutter + Simulador Móvil | BD Relacional)

---

## 1. Arquitectura del Sistema

El sistema **Biblioteca Escolar** fue diseñado bajo una arquitectura **Cliente-Servidor desacoplada en 3 capas**, comunicadas a través de una API RESTful sobre protocolo HTTP/JSON con autenticación basada en **JSON Web Tokens (JWT)**:

1. **Capa de Presentación (Clientes Móvil y Web):**
   - **Aplicación Multiplataforma en Flutter (`/app_flutter`):** Desarrollada en Dart siguiendo principios de separación de responsabilidades (`services/`, `screens/`), consumo asíncrono de API y persistencia local de sesión.
   - **Simulador Móvil Instantáneo (`/api/public/index.html`):** Interfaz interactiva tipo *Phone Mockup* servida directamente por Express que permite demostrar en tiempo real todos los flujos de usuario (Estudiante, Profesor, Bibliotecario/Administrador) junto con un monitor en vivo de peticiones HTTP.

2. **Capa de Lógica de Negocio y Servicios (`/api`):**
   - Implementada en **Node.js** con el framework **Express.js**.
   - **Seguridad y Control de Acceso:** Uso de `bcryptjs` (con factor de costo *salt* = 10) para el hash irreversible de contraseñas y `jsonwebtoken` para emitir tokens firmados con el rol del usuario (`id_usuario`, `documento`, `tipo_usuario`).
   - **Procesamiento de Archivos:** Uso de `multer` en memoria (`memoryStorage`) y `xlsx` para la lectura, validación e inserción masiva de estudiantes desde hojas de cálculo Excel (`.xlsx`).

3. **Capa de Persistencia y Datos (`Supabase PostgreSQL` + `Sequelize ORM`):**
   - Base de datos relacional alojada en la nube (Supabase PostgreSQL con conexión segura SSL mediante Session Pooler).
   - Modelado mediante 7 entidades relacionales: `usuarios`, `login`, `libros`, `ejemplares_libro`, `solicitudes_prestamo`, `prestamos` y `devoluciones`.

---

## 2. Decisiones de Diseño y Reglas de Negocio

### 2.1. Separación entre Obra Bibliográfica (`libros`) e Inventario Físico (`ejemplares_libro`)
Una decisión clave de diseño fue desacoplar los metadatos del libro (`codigo_libro`, `titulo`, `autor`, `area`, `anio_publicacion`) de las copias físicas reales (`codigo_inventario`, `condicion`, `disponibilidad`). Esto permite:
- Tener múltiples ejemplares de un mismo título (por ejemplo, `INV-001-A`, `INV-001-B`).
- Controlar individualmente si un ejemplar está `'disponible'`, `'prestado'` o en `'mantenimiento'`, así como su estado físico (`'bueno'` o `'regular'`).
- Calcular en tiempo real la relación `disponibles / total` en las búsquedas del catálogo.

### 2.2. Separación de Identidad (`usuarios`) y Credenciales (`login`)
Siguiendo el modelo entidad-relación propuesto:
- La tabla `usuarios` almacena la información institucional y el rol (`estudiante`, `profesor`, `administrador`).
- La tabla `login` almacena las credenciales asociadas por llave foránea (`id_usuario`), garantizando que las consultas de negocio nunca expongan el hash de la contraseña.
- **Regla de primer ingreso y cambio de contraseña (`/auth/change-password`):** Cuando un estudiante es creado mediante carga masiva desde Excel, su contraseña inicial corresponde a su número de documento encriptado con `bcrypt`. Al cambiar su contraseña, el backend valida explícitamente que la nueva contraseña **no sea igual a su número de documento**, cumpliendo el criterio de aceptación de la Historia de Usuario #1.

### 2.3. Ciclo de Vida Transaccional del Préstamo
El flujo completo desde la solicitud hasta la devolución mantiene la integridad referencial en tres pasos:
1. **Solicitud (`POST /solicitudes`):** Valida que `ejemplar.disponibilidad === 'disponible'` y que el usuario no tenga una solicitud pendiente duplicada para ese ejemplar. Crea el registro en estado `'pendiente'`.
2. **Aprobación (`PATCH /solicitudes/:id/approve`):** El bibliotecario/administrador aprueba la solicitud; el sistema cambia automáticamente `solicitud.estado = 'aprobada'`, actualiza `ejemplar.disponibilidad = 'prestado'` y genera el registro en `prestamos` con `estado = 'activo'` y `fecha_prestamo = NOW()`.
3. **Devolución (`POST /prestamos/:id/devolver` o `POST /solicitudes/:id/devolver`):** Crea el registro de auditoría en `devoluciones` con `fecha_devolucion` y `observaciones`, marca el préstamo como `'devuelto'`, restaura `ejemplar.disponibilidad = 'disponible'` y actualiza opcionalmente la `condicion` física del ejemplar (`'bueno'` o `'regular'`).

---

## 3. Dificultades Encontradas y Soluciones Aplicadas

1. **Conexión IPv4/IPv6 y SSL con Base de Datos en la Nube (Supabase):**
   - *Dificultad:* La conexión directa por defecto de Supabase utiliza hosts IPv6 que en ciertas redes locales generan errores de resolución (`ENOTFOUND` o rechazos de certificado SSL).
   - *Solución:* Se configuró el **Session Pooler IPv4** de Supabase (`aws-0-us-east-1.pooler.supabase.com:5432`) junto con `dialectOptions: { ssl: { require: true, rejectUnauthorized: false } }` en Sequelize.

2. **Conversión Automática de Tipos `ENUM` en PostgreSQL con Sequelize:**
   - *Dificultad:* Al ejecutar `sequelize.sync({ alter: true })` sobre tablas existentes en PostgreSQL con valores por defecto (`DEFAULT`), PostgreSQL lanza el error `default for column cannot be cast automatically to type enum`.
   - *Solución:* Se empleó `DataTypes.STRING` combinado con validaciones a nivel de ORM (`validate: { isIn: [[...]] }`) y `CHECK` constraints en SQL, junto con `sequelize.sync()`, logrando compatibilidad total y validación estricta sin conflictos de migración.

3. **Pruebas Ágiles Multi-Rol durante la Sustentación:**
   - *Dificultad:* Compilar emuladores móviles pesados durante una demostración en vivo puede retrasar la validación de los roles (Estudiante, Profesor, Administrador).
   - *Solución:* Además del proyecto en Flutter (`/app_flutter`), se integró un **Simulador Móvil Web Instantáneo** en `/api/public/index.html` conectado directamente a la API real y con cambio de sesión en 1 clic.

---

## 4. Mejoras Futuras

1. **Notificaciones Automáticas de Vencimiento:** Implementar un *cron job* que envíe alertas por correo electrónico o notificaciones *push* cuando un préstamo activo supere los días límite de entrega.
2. **Lectura de Código de Barras / QR para Inventario:** Integrar la cámara del dispositivo en Flutter para escanear la etiqueta `codigo_inventario` del ejemplar físico al momento de aprobar préstamos o registrar devoluciones.
3. **Reservas en Cola y Multas Pedagógicas:** Permitir que un estudiante reserve un libro cuyos ejemplares estén todos prestados y sea notificado apenas se registre una devolución.
4. **Dashboard Analítico de Lectura:** Incorporar gráficas estadísticas por área de conocimiento, libros más solicitados del semestre e indicadores de rotación de inventario.
