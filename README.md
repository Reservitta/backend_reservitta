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
  - `login_view.dart`: Formulario e interfaz de inicio de sesión.
  - `home_view.dart`: Pantalla principal con la lista de restaurantes.

---

### 2. ⚡ `lib/viewmodels/` (Capa de Presentación y Estado)
- **Responsabilidad**: Maneja el estado de la vista, la lógica de validación e interactúa entre la vista y los servicios de backend.
- **Enfoque de trabajo**: **Frontend Avanzado / Lógica de Cliente**.
- **Reglas**:
  - Heredan de `ChangeNotifier` para notificar a la vista cuando los datos cambian (`notifyListeners()`).
  - Gestionan controladores de formularios (`TextEditingController`), estados de carga (`isLoading`) y mensajes de error.
  - Invocan los métodos de la capa `services` para obtener o enviar datos al backend.
- **Archivos actuales**:
  - `login_viewmodel.dart`: Controla el flujo de autenticación de usuario.
  - `home_viewmodel.dart`: Controla la transmisión de datos y el cierre de sesión.

---

### 3. 📦 `lib/models/` (Modelos de Datos / Entidades)
- **Responsabilidad**: Define la estructura de los objetos de datos del dominio de la aplicación.
- **Enfoque de trabajo**: **Backend / Fullstack**.
- **Reglas**:
  - Define clases puras Dart con sus propiedades.
  - Incluye métodos de serialización (`fromFirestore`, `toMap`, `fromJson`, `toJson`) para transformar las respuestas del backend en objetos fuertemente tipados.
- **Archivos actuales**:
  - `restaurant_model.dart`: Modelo que representa a un restaurante (`id`, `name`).

---

### 4. ⚙️ `lib/services/` (Backend Client / Capa de Datos)
- **Responsabilidad**: Encapsula las comunicaciones con servicios externos, APIs REST, Firebase Auth, Cloud Firestore u otras bases de datos.
- **Enfoque de trabajo**: **Backend**.
- **Reglas**:
  - Realiza las peticiones directas de red o consultas a la base de datos.
  - Retorna `Streams`, `Futures` o datos mapeados a `Models`.
  - Aisla la aplicación de cambios en el proveedor de backend (si en el futuro cambia Firebase por un servidor propio REST/GraphQL, solo se modifica esta carpeta).
- **Archivos actuales**:
  - `auth_service.dart`: Métodos de inicio de sesión, cierre de sesión y stream del estado de autenticación.
  - `restaurant_service.dart`: Consultas a la colección de restaurantes en Firestore.

---

### 5. 🚀 `lib/main.dart` (Punto de Entrada y Enrutamiento)
- **Responsabilidad**:
  - Inicializa las configuraciones globales (Firebase bindings, temas de color).
  - Define el `MaterialApp` de la aplicación.
  - Determina la vista inicial según el estado del usuario (ej: Si está autenticado redirige a `HomeView`, de lo contrario a `LoginView`).

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