# Hospital Citas - Sistema de Gestion de Citas Medicas

Sistema web para la gestion de citas medicas del Hospital Prototipo, desarrollado como parte del curso de Tecnologia Web II.

## Descripcion

Este modulo permite gestionar el ciclo de vida de las fichas de citas medicas, incluyendo:

- Registro de citas (fichas)
- Confirmacion de citas
- Atencion de pacientes
- Cancelacion de citas
- Visualizacion de horarios disponibles
- Reportes (vista imprimible/PDF)
- Emergencias y triaje
- Catalogos (listas)

## Tecnologias Utilizadas

### Backend
- **Python 3.x**
- **FastAPI** - Framework web moderno y rapido
- **asyncpg** - Cliente asincrono para PostgreSQL
- **pydantic-settings** - Configuracion de entorno
- **PostgreSQL** - Sistema de gestion de bases de datos

### Frontend
- **HTML5** - Estructura de paginas
- **CSS3** - Estilos y diseno responsivo (SPA de una sola pagina)
- **JavaScript (ES6+)** - Logica del cliente, iconos Lucide (SVG)

## Estructura del Proyecto

```
citas/
├── main.py                    # Punto de entrada de FastAPI (SPA + API)
├── pyproject.toml             # Dependencias del proyecto
├── .env                       # Variables de entorno (NO versionar)
├── configuracion/
│   ├── conexion.py            # Pool asyncpg y dependencia get_conn
│   └── parametros.py          # Configuracion via pydantic-settings
├── entidades/                 # Modelos Pydantic (schemas de entrada/salida)
│   ├── emergencia.py
│   ├── empleado.py
│   ├── especialidad.py
│   ├── ficha.py
│   ├── horario.py
│   ├── persona.py
│   ├── servicio.py
│   └── turno.py
├── modelos/                   # Logica de acceso a datos (SQL)
│   ├── m_emergencia.py
│   ├── m_empleado.py
│   ├── m_especialidad.py
│   ├── m_ficha.py
│   ├── m_horario.py
│   ├── m_persona.py
│   ├── m_servicio.py
│   └── m_turno.py
├── rutas/                     # Endpoints de la API (APIRouter)
│   ├── r_emergencia.py
│   ├── r_empleado.py
│   ├── r_especialidad.py
│   ├── r_ficha.py
│   ├── r_horario.py
│   ├── r_persona.py
│   ├── r_servicio.py
│   └── r_turno.py
├── frontend/                  # Frontend Web (SPA)
│   ├── index.html             # Pagina principal (una sola pagina)
│   ├── css/
│   │   └── main.css           # Estilos globales
│   └── js/
│       ├── api.js             # Funciones API genericas (fetch)
│       ├── catalogos.js       # Logica de listas
│       ├── citas.js           # Logica de gestion de citas
│       ├── emergencias.js     # Logica de emergencias
│       ├── reportes.js        # Logica de reportes
│       └── ui.js              # Utilidades de UI (modales, toasts, etc.)
├── database/
│   └── schema.sql             # Estructura de tablas (dump bd_hospital)
├── config/
│   └── postgrest.conf         # Configuracion de PostgREST (opcional)
└── README.md                  # Este archivo
```

## Prerequisitos

- Python 3.10 o superior
- PostgreSQL
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
```

> Nota: el `schema.sql` es el dump completo de `bd_hospital`. Los cambios de
> base de datos de todos los modulos se gestionan en el repo compartido
> `hospital-todo-sano` (scripts SQL de correccion por modulo, p. ej.
> `citas_correcciones.sql`).

### 3. Configurar Backend

```bash
# Crear entorno virtual
python -m venv .venv
# Windows: .venv\Scripts\activate
# Mac/Linux: source .venv/bin/activate

# Instalar dependencias
pip install -e .

# Editar el archivo .env con tus credenciales de BD
# DB_NAME=bd_hospital
# DB_USER=postgres
# DB_PASS=tu_password
# DB_HOST=localhost
# DB_PORT=5432

# Ejecutar el servidor
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 4. Configurar Frontend

El frontend es una SPA servida directamente por FastAPI en la raiz (`/`).
No requiere servidor adicional: abrir `http://localhost:8000` en el navegador
tras levantar el backend.

### 5. (Opcional) Configurar PostgREST

```bash
# Descargar PostgREST desde https://postgrest.org/
# Configurar en config/postgrest.conf
# Ejecutar:
postgrest config/postgrest.conf
```

## API Endpoints

Todos los endpoints tienen prefijo `/`. La API expone CRUD para cada recurso.

### Personas
- `GET /personas/` - Listar personas
- `GET /personas/{ci}/asegurado` - Informacion de asegurado por CI
- `GET /personas/{id}` - Obtener detalle de persona
- `POST /personas/` - Crear persona
- `PUT /personas/{id}` - Actualizar persona
- `DELETE /personas/{id}` - Eliminar persona

### Fichas (Citas)
- `GET /fichas/` - Listar fichas de citas
- `GET /fichas/{id}` - Obtener detalle de ficha
- `POST /fichas/` - Crear nueva ficha (con validaciones de negocio)
- `PUT /fichas/{id}` - Actualizar ficha (cambiar estado, observacion)
- `DELETE /fichas/{id}` - Eliminar ficha

### Empleados, Especialidades, Horarios, Servicios, Turnos, Emergencias
 Cada recurso expone CRUD basico (`GET /`, `GET /{id}`, `POST /`, `PUT /{id}`, `DELETE /{id}`).

- `/empleados/`
- `/especialidades/` (+ `GET /especialidades/medicos` - medicos por especialidad)
- `/horarios/`
- `/servicios/`
- `/turnos/`
- `/emergencias/`

### Otros
- `GET /health` - Estado del servicio

## Modelo de Datos Principal

### Ficha {tc_ficha}
- `id_ficha` - Identificador unico
- `nro_ficha` - Numero consecutivo del dia
- `id_persona` - Persona (paciente) registrada
- `ci_paciente` - Cedula de identidad del paciente
- `tipo_paciente` - `Asegurado`, `Asegurado vencido` o `Particular`
- `id_asegurado` - CI del asegurado (si aplica)
- `id_medico` - Medico asignado
- `id_especialidad` - Especialidad medica
- `id_horario` - Horario seleccionado
- `id_servicio` - Servicio (opcional)
- `fech_cita` - Fecha de la cita
- `hora_cita` - Hora de la cita
- `estado` - `Registrada`, `Confirmada`, `Atendida`, `No asistio`, `Cancelada`
- `observacion`, `usuario_reg`, `fech_reg`

## Estados de la Cita

| Estado | Descripcion |
|--------|-------------|
| Registrada | Cita creada pendiente de confirmacion |
| Confirmada | Paciente confirmo asistencia |
| Atendida | Cita completada |
| No asistio | Paciente no se presento |
| Cancelada | Cita cancelada |

## Reglas de Negocio (creacion de ficha)

- La persona debe existir y tener nombre/apellido registrado.
- El CI debe corresponder a la persona seleccionada.
- Un medico no puede registrarse como paciente.
- El medico debe atender la especialidad seleccionada.
- El horario debe corresponder a la especialidad del medico.
- La fecha debe coincidir con el dia del horario y la hora con su rango.
- No se permite cita duplicada (mismo medico, fecha y hora no cancelada).
- Se respeta el limite de cupos (`nro_fichas`) del horario por dia.
- Si la poliza del asegurado esta vencida, se exige registrar como Particular.

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
