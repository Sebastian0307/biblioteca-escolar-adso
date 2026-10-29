# 📚 Sistema de Gestión de Biblioteca Escolar (SENA 2026)

Sistema integral Cliente-Servidor para la administración del catálogo bibliográfico, control de inventario por ejemplar físico, solicitudes de préstamo, aprobaciones, devoluciones y carga masiva de usuarios mediante Excel.

---

## 🏗️ 1. Arquitectura y Estructura del Proyecto

```text
Biblioteca-escolar/
├── api/                                # Backend REST API (Node.js + Express + Sequelize)
│   ├── public/
│   │   └── index.html                  # 📱 Simulador Móvil Instantáneo (Phone Mockup en vivo)
│   ├── src/
│   │   ├── config/
│   │   │   └── database.js             # Conexión Sequelize SSL a PostgreSQL (Supabase)
│   │   ├── models/                     # 7 Modelos relacionales + index.js
│   │   │   ├── usuario.js              # Tabla usuarios
│   │   │   ├── login.js                # Tabla login (contraseñas bcrypt)
│   │   │   ├── libro.js                # Tabla libros
│   │   │   ├── ejemplar.js             # Tabla ejemplares_libro
│   │   │   ├── solicitud.js            # Tabla solicitudes_prestamo
│   │   │   ├── prestamo.js             # Tabla prestamos
│   │   │   ├── devolucion.js           # Tabla devoluciones
│   │   │   └── index.js
│   │   ├── middlewares/
│   │   │   └── authMiddleware.js       # Verificación JWT (Authorization: Bearer <token>)
│   │   ├── controllers/
│   │   │   ├── authController.js       # Login híbrido/bcrypt y Seed automático
│   │   │   ├── libroController.js      # CRUD de libros y ejemplares físicos
│   │   │   ├── solicitudController.js  # Solicitudes, aprobación, préstamos y devoluciones
│   │   │   └── adminController.js      # Carga masiva desde Excel (.xlsx) con multer + xlsx
│   │   ├── routes/
│   │   │   ├── authRoutes.js
│   │   │   ├── libroRoutes.js
│   │   │   ├── solicitudRoutes.js
│   │   │   └── adminRoutes.js
│   │   └── app.js                      # Servidor principal Express + sync({ alter: true })
│   ├── .env                            # Variables de entorno configuradas para Supabase
│   └── package.json
├── app_flutter/                        # Aplicación Móvil / Web en Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── services/
│   │   │   └── api_service.dart        # Cliente HTTP conectado a http://localhost:3000
│   │   └── screens/
│   │       ├── login_screen.dart
│   │       └── home_screen.dart
│   └── pubspec.yaml
├── supabase_schema.sql                 # Script SQL PostgreSQL con las 7 tablas y 12+ registros semilla
├── Coleccion_Postman_Biblioteca.json   # Colección Postman v2.1 lista para importar
└── README.md                           # Documentación general
```

---

## 🚀 2. Cómo Ejecutar el Proyecto Rápidamente

### Paso 1: Iniciar el Backend (`/api`) y el Simulador Móvil Web
Abre una terminal en la carpeta `api`:

```bash
cd api
npm install
npm start
```

Al iniciar:
1. Sequelize se conectará automáticamente a **Supabase PostgreSQL** (`db.wbaipudqapjgtujdjfzr.supabase.co`).
2. Sincronizará las 7 tablas (`sequelize.sync({ alter: true })`).
3. Inicializará los datos de prueba y encriptará las contraseñas con `bcryptjs`.
4. Abre en tu navegador **[http://localhost:3000](http://localhost:3000)** para usar el **Simulador Móvil Interactivo** en tiempo real.

### Paso 2: Ejecutar la App en Flutter (`/app_flutter`) (Opcional)
```bash
cd app_flutter
flutter pub get
flutter run -d chrome
```

---

## 🔑 3. Credenciales de Prueba (1 Clic en el Simulador)

| Rol | Nombre | Documento | Contraseña |
| :--- | :--- | :--- | :--- |
| **Administrador** | Carlos Ramírez | `10001001` | `10001001` |
| **Estudiante** | Valentina López | `30003001` | `30003001` |
| **Profesor** | Andrés Martínez | `20002001` | `20002001` |

---

## 📡 4. Endpoints Principales de la API REST

| Método | Ruta | Autenticación | Descripción |
| :--- | :--- | :--- | :--- |
| `POST` | `/seed` | Pública | Inicializa datos de prueba y encripta contraseñas en Supabase |
| `POST` | `/auth/login` | Pública | Valida documento y contraseña con `bcryptjs` y devuelve `{ token, usuario }` |
| `GET` | `/libros` | Pública | Lista todos los libros incluyendo sus ejemplares físicos |
| `POST` | `/libros` | JWT | Crea un nuevo libro y su ejemplar inicial |
| `GET` | `/libros/:id/ejemplares` | Pública | Lista los ejemplares físicos de un libro |
| `POST` | `/libros/:id/ejemplares` | JWT | Agrega un nuevo ejemplar físico (`codigo_inventario`) |
| `POST` | `/solicitudes` | JWT | Solicita en préstamo un ejemplar disponible |
| `GET` | `/solicitudes` | JWT | Lista todas las solicitudes con datos de usuario, ejemplar y libro |
| `PATCH` | `/solicitudes/:id/approve` | JWT | Aprueba la solicitud, pasa el ejemplar a `'prestado'` y crea el préstamo activo |
| `POST` | `/solicitudes/:id/devolver` | JWT | Registra la devolución, marca el préstamo como `'devuelto'` y libera el ejemplar |
| `GET` | `/solicitudes/mis-prestamos` | JWT | Historial de préstamos del usuario autenticado |
| `GET` | `/solicitudes/mis-solicitudes` | JWT | Historial de solicitudes del usuario autenticado |
| `POST` | `/admin/usuarios/upload-excel` | JWT | Carga masiva de usuarios desde archivo `.xlsx` (`campo archivo`) |
| `GET` | `/admin/usuarios/plantilla-excel` | Pública | Descarga un archivo Excel `.xlsx` de ejemplo listo para probar la carga masiva |
