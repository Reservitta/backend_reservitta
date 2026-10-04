# 📱 Reservitta App - Arquitectura MVVM

Este proyecto utiliza el patrón de arquitectura **MVVM (Model - View - ViewModel)**. 

Para los miembros del equipo acostumbrados a separar el trabajo entre **Frontend** y **Backend**, esta guía detalla la responsabilidad de cada carpeta y cómo se distribuyen las tareas dentro de la estructura del proyecto.

---

## 🗺️ Mapa de Responsabilidades (Frontend vs Backend)

```text
       ┌────────────────────────────────────────────────────────┐
       │                   FRONTEND (UI)                        │
       │                   lib/views/                           │
       └───────────────────────────┬────────────────────────────┘
                                   │  (Escucha estado / Llama acciones)
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │               CAPA INTERMEDIA (ViewModel)              │
       │                 lib/viewmodels/                        │
       └───────────────────────────┬────────────────────────────┘
                                   │  (Consume servicios y modelos)
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │                   BACKEND (Data Layer)                 │
       │           lib/services/    &    lib/models/            │
       └────────────────────────────────────────────────────────┘
```

---

## 📁 Estructura de Carpetas en `lib/`

### 1. 🎨 `lib/views/` (Frontend / Interfaz de Usuario)
- **Responsabilidad**: Contiene todas las pantallas, widgets y elementos visuales con los que interactúa el usuario.
- **Enfoque de trabajo**: **Frontend**.
- **Reglas**:
  - NO debe contener lógica de negocio ni llamadas directas a servicios externos o base de datos (Firebase).
  - Solo construye layouts, botones, formularios e inputs.
  - Escucha cambios de los `ViewModels` (usando `ListenableBuilder` o `StreamBuilder`) para redibujar la UI.
- **Archivos actuales**:
  - `landing_view.dart`: Entrada pública de la aplicación.
  - `auth_modal_dialog.dart`: Formularios de inicio de sesión, registro y recuperación.
  - `authenticated_user_gate.dart`: Selecciona la pantalla según perfil y rol.
  - `home_view.dart`: Pantalla de administración del restaurante.

---

### 2. ⚡ `lib/viewmodels/` (Capa de Presentación y Estado)
- **Responsabilidad**: Maneja el estado de la vista, la lógica de validación e interactúa entre la vista y los servicios de backend.
- **Enfoque de trabajo**: **Frontend Avanzado / Lógica de Cliente**.
- **Reglas**:
  - Heredan de `ChangeNotifier` para notificar a la vista cuando los datos cambian (`notifyListeners()`).
  - Gestionan controladores de formularios (`TextEditingController`), estados de carga (`isLoading`) y mensajes de error.
  - Invocan los métodos de la capa `services` para obtener o enviar datos al backend.
- **Archivos actuales**:
  - `auth_modal_viewmodel.dart`: Estado del flujo de autenticación público.
  - `home_viewmodel.dart`: Carga el perfil del administrador y datos del restaurante.

---

### 3. 📦 `lib/models/` (Modelos de Datos / Entidades)
- **Responsabilidad**: Define la estructura de los objetos de datos del dominio de la aplicación.
- **Enfoque de trabajo**: **Backend / Fullstack**.
- **Reglas**:
  - Define clases puras Dart con sus propiedades.
  - Incluye métodos de serialización (`fromFirestore`, `toMap`, `fromJson`, `toJson`) para transformar las respuestas del backend en objetos fuertemente tipados.
- **Archivos actuales**:
  - `restaurant_model.dart`: Modelo que representa a un restaurante (`id`, `name`).
  - `user_model.dart`: Perfil de usuario de Reservitta y rol de la aplicación.

---

### 4. ⚙️ `lib/services/` (Backend Client / Capa de Datos)
- **Responsabilidad**: Encapsula las comunicaciones con servicios externos, APIs REST, Firebase Auth, Cloud Firestore u otras bases de datos.
- **Enfoque de trabajo**: **Backend**.
- **Reglas**:
  - Realiza las peticiones directas de red o consultas a la base de datos.
  - Retorna `Streams`, `Futures` o datos mapeados a `Models`.
  - Aisla la aplicación de cambios en el proveedor de backend (si en el futuro cambia Firebase por un servidor propio REST/GraphQL, solo se modifica esta carpeta).
- **Archivos actuales**:
  - `auth_service.dart`: Registro, validación de perfil, inicio y cierre de sesión.
  - `restaurant_service.dart`: Consultas a la colección de restaurantes en Firestore.
  - `database_init_service.dart`: Datos de demostración, inicializados bajo acción explícita.

---

### 5. 🚀 `lib/main.dart` (Punto de Entrada y Enrutamiento)
- **Responsabilidad**:
  - Inicializa las configuraciones globales (Firebase bindings, temas de color).
  - Define el `MaterialApp` de la aplicación.
  - Escucha el estado de Authentication y entrega el usuario autenticado al control de acceso por perfil.

### Organización y pruebas
- El proyecto usa organización por capas: vistas en `lib/views/`, estado/UI en `lib/viewmodels/`, acceso a datos en `lib/services/`, modelos en `lib/models/` y validaciones compartidas en `lib/utils/`.
- Mantén cada archivo en su capa correspondiente y usa nombres específicos de dominio para que los archivos relacionados queden juntos sin introducir carpetas por feature duplicadas.
- Las pruebas reflejan esa estructura bajo `test/`; por ejemplo, las validaciones de `lib/utils/` van en `test/utils/`.
- `LoginView` y `RegisterAdminView` son pantallas heredadas sin conexión con el flujo de entrada actual. El flujo activo parte de `LandingView` y usa `AuthModalDialog`/`AuthModalViewModel`; evita agregar nuevas funciones a ambas rutas en paralelo.

---

## 🛠️ Guía de Trabajo para el Equipo

### Si desarrollas **Frontend**:
1. Trabajas principalmente en **`lib/views/`**.
2. Cuando necesites un dato o acción (ej: clic en un botón), lo invocas desde el **`ViewModel`** correspondiente.
3. No importes librerías como `cloud_firestore` o `firebase_auth` en las vistas.

### Si desarrollas **Backend / Integraciones**:
1. Trabajas en **`lib/services/`** para conectar Firebase o APIs externas.
2. Defines o actualizas las estructuras en **`lib/models/`**.
3. Expones los métodos necesarios (`Future` / `Stream`) para que los devs de Frontend o ViewModel los consuman sin preocuparse por la implementación técnica de la base de datos.

---

## 📋 Pasos para agregar una nueva funcionalidad (Ejemplo: Crear una Reserva)

1. **Backend**: Crear/actualizar el modelo `ReservationModel` en `lib/models/reservation_model.dart`.
2. **Backend**: Crear el servicio `ReservationService` en `lib/services/reservation_service.dart` con los métodos CRUD.
3. **Front/Lógica**: Crear el ViewModel `ReservationViewModel` en `lib/viewmodels/reservation_viewmodel.dart` para manejar el estado del formulario de reserva.
4. **Frontend**: Crear la pantalla `ReservationView` en `lib/views/reservation_view.dart` usando los campos del ViewModel.

---

## Registro de cuentas y Firebase

- Firebase Authentication guarda las credenciales de acceso de las cuentas de la aplicación. Que una cuenta aparezca en **Authentication → Users** no la convierte en miembro ni administrador del proyecto Firebase; esos permisos se gestionan por separado en IAM y Firebase Console.
- El perfil de cada cuenta de Reservitta se guarda en Firestore en `users/{UID}`, con `rol: 'admin'` o `rol: 'visitante'`.
- El registro de administrador también crea el documento borrador del restaurante. El perfil y el borrador se escriben en un único batch de Firestore; si Firestore rechaza la operación, la app intenta eliminar la cuenta de acceso recién creada e informa si no pudo hacerlo.
- El registro depende de las reglas de Firestore desplegadas en Firebase Console. Publica y verifica las reglas de `firestore.rules` antes de probar registros; los cambios en el archivo local no se publican automáticamente.