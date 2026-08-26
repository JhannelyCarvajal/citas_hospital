# Hospital Citas - Sistema de Gestion de Citas Medicas

Sistema web para la gestion de citas medicas del Hospital Prototipo, desarrollado como parte del curso de Tecnologia Web II.

## Descripcion

Este modulo permite gestionar el ciclo de vida de las fichas de citas medicas, incluyendo:

- Registro de citas (fichas)
- Confirmacion de citas
- Atencion de pacientes
- Cancelacion de citas
- Visualizacion de horarios disponibles
- Reportes basicos

## Tecnologias Utilizadas

### Backend
- **Python 3.x**
- **FastAPI** - Framework web moderno y rapido
- **asyncpg** - Cliente asincrono para PostgreSQL
- **PostgreSQL 18** - Sistema de gestion de bases de datos

### Frontend
- **HTML5** - Estructura de paginas
- **CSS3** - Estilos y diseno responsivo
- **JavaScript (ES6+)** - Logica del cliente

### Herramientas
- **PostgREST** - API REST automatica para PostgreSQL
- **Git** - Control de versiones

## Estructura del Proyecto

```
citas/
├── backend/                    # API Backend
│   ├── main.py                 # Punto de entrada de FastAPI
│   ├── conexion.py             # Configuracion de conexion a BD
│   ├── parametros.py           # Variables de configuracion
│   ├── .env                    # Variables de entorno
│   ├── models/
│   │   └── schemas.py          # Modelos Pydantic
│   └── routes/
│       ├── citas.py            # Rutas para fichas/citas
│       └── catalogos.py        # Rutas para catalogos
├── frontend/                   # Frontend Web
│   ├── index.html              # Pagina principal
│   ├── css/
│   │   └── styles.css          # Estilos globales
│   ├── js/
│   │   ├── api.js              # Funciones API genericas
│   │   └── citas.js            # Logica de gestion de citas
│   └── pages/
│       ├── horarios.html       # Gestion de horarios
│       └── reportes.html       # Reportes
├── database/                   # Base de datos
│   ├── schema.sql              # Estructura de tablas
│   └── seed.sql                # Datos iniciales
├── config/                     # Configuracion
│   └── postgrest.conf          # Configuracion de PostgREST
├── docs/                       # Documentacion
└── README.md                   # Este archivo
```

## Prerequisitos

- Python 3.9 o superior
- PostgreSQL 14 o superior
- pip (gestor de paquetes de Python)
- Git

## Instalacion

### 1. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/hospital-citas.git
cd hospital-citas
```

### 2. Configurar Base de Datos

```bash
# Conectarse a PostgreSQL
psql -U postgres

# Crear la base de datos
CREATE DATABASE bd_hospital;

# Conectarse a la base de datos
\c bd_hospital

# Ejecutar el esquema
\i database/schema.sql

# Ejecutar datos iniciales
\i database/seed.sql
```

### 3. Configurar Backend

```bash
# Navegar al directorio backend
cd backend

# Crear entorno virtual (opcional pero recomendado)
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate  # Windows

# Instalar dependencias
pip install fastapi uvicorn asyncpg pydantic-settings python-dotenv

# Editar archivo .env con tus credenciales de BD
# DB_NAME=bd_hospital
# DB_USER=postgres
# DB_PASS=tu_password
# DB_HOST=localhost
# DB_PORT=5432

# Ejecutar el servidor
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

### 4. Configurar Frontend

Abrir `frontend/index.html` en tu navegador o usar un servidor local:

```bash
# Opcion 1: Abrir directamente en el navegador
# Windows: start frontend/index.html
# Mac: open frontend/index.html
# Linux: xdg-open frontend/index.html

# Opcion 2: Usar servidor local (recomendado)
cd frontend
python -m http.server 8080
# Abrir http://localhost:8080
```

### 5. (Opcional) Configurar PostgREST

```bash
# Descargar PostgREST desde https://postgrest.org/
# Configurar en config/postgrest.conf
# Ejecutar:
postgrest config/postgrest.conf
```

## API Endpoints

### Citas
- `GET /api/citas/fichas` - Listar fichas de citas
- `GET /api/citas/fichas/{id}` - Obtener detalle de ficha
- `POST /api/citas/fichas` - Crear nueva ficha
- `PUT /api/citas/fichas/{id}/estado` - Cambiar estado de ficha
- `GET /api/citas/horarios-disponibles/{id_especialidad}` - Horarios disponibles

### Catalogos
- `GET /api/catalogos/especialidades` - Listar especialidades
- `GET /api/catalogos/personas` - Listar personas
- `GET /api/catalogos/empleados` - Listar empleados
- `GET /api/catalogos/medicos` - Listar medicos
- `GET /api/catalogos/medicos/{id_especialidad}` - Medicos por especialidad

## Modelos de Datos Principales

### Ficha (Cita)
- `id_ficha` - Identificador unico
- `nro_ficha` - Numero consecutivo del dia
- `ci_paciente` - Cedula de identidad del paciente
- `tipo_paciente` - A (Asegurado) o P (Particular)
- `id_medico` - Medico asignado
- `id_especialidad` - Especialidad medica
- `id_horario` - Horario seleccionado
- `fech_cita` - Fecha de la cita
- `hora_cita` - Hora de la cita
- `estado` - R (Registrada), C (Confirmada), A (Atendida), N (No asistio), X (Cancelada)

## Estados de la Cita

| Estado | Descripcion |
|--------|-------------|
| R | Registrada - Cita creada pendiente de confirmacion |
| C | Confirmada - Paciente confirmo asistencia |
| A | Atendida - Cita completada |
| N | No asistio - Paciente no se presento |
| X | Cancelada - Cita cancelada |

## Contribuir

1. Forkear el repositorio
2. Crear una branch para la nueva feature (`git checkout -b feature/nueva-funcionalidad`)
3. Hacer commit de los cambios (`git commit -m 'Add nueva funcionalidad'`)
4. Push a la branch (`git push origin feature/nueva-funcionalidad`)
5. Crear un Pull Request

## Licencia

Este proyecto es para fines academicos del curso de Tecnologia Web II.

## Contacto

- Email: admin@hospital.com
- Universidad: UTEC - Tecnologia Web II