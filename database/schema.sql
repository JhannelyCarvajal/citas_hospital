-- =====================================================================
-- DISENO DE BASE DE DATOS: Hospital_Prototipo_Citas
-- Sistema de gestion de citas medicas (PostgreSQL 18 / PostgREST)
-- ---------------------------------------------------------------------
-- Contenido:
--   1. Tipos ENUM
--   2. Tablas maestras      (tturno, tareas, tservicios, tespecialidad,
--                            taseguradora)
--   3. Personas y empleados (tpersonas, templeados,
--                            templeado_especialidades)
--   4. Operacion            (tasegurado, thorario, tficha)
--   5. Indices
--   6. Funciones
--   7. Triggers
--   8. Vista
-- =====================================================================


-- =====================================================================
-- 1. TIPOS ENUM
-- =====================================================================

CREATE TYPE tipo_especialidad_enum AS ENUM (
    'medica',
    'enfermeria',
    'apoyo',
    'administrativa'
);

CREATE TYPE tipo_empleado_enum AS ENUM (
    'medico',
    'enfermero',
    'administrativo',
    'auxiliar',
    'otro'
);


-- =====================================================================
-- 2. TABLAS MAESTRAS
-- =====================================================================

-- Turnos laborales / de atencion ---------------------------------------
CREATE TABLE tturno (
    id_turno         integer NOT NULL PRIMARY KEY,
    descripcion      varchar(15)  NOT NULL,
    hora_inicio      time WITHOUT TIME ZONE NOT NULL,
    hora_fin         time WITHOUT TIME ZONE NOT NULL,
    cruza_medianoche boolean NOT NULL DEFAULT false,
    activo           boolean NOT NULL DEFAULT true
);

-- Areas organizacionales ------------------------------------------------
CREATE TABLE tareas (
    id_area     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_area varchar(60) NOT NULL UNIQUE,
    descripcion text        NOT NULL DEFAULT '',
    activo      boolean     NOT NULL DEFAULT true
);

-- Servicios hospitalarios (se asignan en cada cita) ---------------------
CREATE TABLE tservicios (
    id_servicio     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_servicio varchar(60) NOT NULL UNIQUE,
    descripcion     text        NOT NULL DEFAULT '',
    activo          boolean     NOT NULL DEFAULT true
);

-- Especialidades medicas -------------------------------------------------
CREATE TABLE tespecialidad (
    id_especialidad    integer NOT NULL PRIMARY KEY,
    nombre_especialidad varchar(60) NOT NULL,
    tipo               tipo_especialidad_enum NOT NULL DEFAULT 'medica',
    descripcion        text   NOT NULL DEFAULT '',
    activo             boolean NOT NULL DEFAULT true
);

-- Aseguradoras ------------------------------------------------------------
CREATE TABLE taseguradora (
    id_aseguradora integer NOT NULL PRIMARY KEY,
    nombre         varchar(80)  NOT NULL,
    nit            varchar(20)  NOT NULL DEFAULT '',
    telefono       varchar(20)  NOT NULL DEFAULT '',
    direccion      varchar(150) NOT NULL DEFAULT '',
    activo         boolean      NOT NULL DEFAULT true
);


-- =====================================================================
-- 3. PERSONAS Y EMPLEADOS
-- =====================================================================

-- Persona base (empleados; extensible a pacientes) ----------------------
CREATE TABLE tpersonas (
    id_persona       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ci               varchar(20) NOT NULL UNIQUE,
    nombre           varchar(80) NOT NULL,
    apellidos        varchar(80) NOT NULL DEFAULT '',
    fecha_nacimiento date,
    genero           char(1) CHECK (genero IS NULL OR genero IN ('F','M')),
    telefono         varchar(20)  NOT NULL DEFAULT '',
    email            varchar(100) NOT NULL DEFAULT '',
    direccion        text,
    foto_url         varchar(255),
    fecha_creacion   timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activo           boolean   NOT NULL DEFAULT true
);

-- Empleados del hospital (medicos, enfermeros, administrativos...) ------
CREATE TABLE templeados (
    id_empleado        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_persona         integer NOT NULL UNIQUE REFERENCES tpersonas(id_persona),
    id_area            integer REFERENCES tareas(id_area),
    tipo_empleado      tipo_empleado_enum NOT NULL,
    fecha_contratacion date,
    fecha_terminacion  date,
    id_turno           integer REFERENCES tturno(id_turno),
    sueldo_base        numeric(10,2) NOT NULL DEFAULT 0,
    -- Matricula profesional (aplica a medicos)
    nmp                varchar(20) NOT NULL DEFAULT '',
    activo             boolean NOT NULL DEFAULT true,
    CONSTRAINT templeados_sueldo_check CHECK (sueldo_base >= 0),
    CONSTRAINT templeados_fechas_check
        CHECK (fecha_terminacion IS NULL OR fecha_contratacion IS NULL
               OR fecha_terminacion >= fecha_contratacion)
);

-- Especialidades por empleado (relacion N:M) ------------------------------
CREATE TABLE templeado_especialidades (
    id_relacion      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_empleado      integer NOT NULL REFERENCES templeados(id_empleado) ON DELETE CASCADE,
    id_especialidad  integer NOT NULL REFERENCES tespecialidad(id_especialidad),
    fecha_asignacion date NOT NULL DEFAULT CURRENT_DATE,
    observaciones    text NOT NULL DEFAULT '',
    CONSTRAINT templeado_especialidades_unica UNIQUE (id_empleado, id_especialidad)
);


-- =====================================================================
-- 4. OPERACION
-- =====================================================================

-- Pacientes asegurados ----------------------------------------------------
CREATE TABLE tasegurado (
    ci              varchar(15) NOT NULL PRIMARY KEY,
    id_aseguradora  integer NOT NULL REFERENCES taseguradora(id_aseguradora),
    nombre          varchar(50) NOT NULL,
    paterno         varchar(30) NOT NULL DEFAULT '',
    materno         varchar(30) NOT NULL DEFAULT '',
    nro_poliza      varchar(30) NOT NULL DEFAULT '',
    fech_nac        date,
    fech_afiliacion date    NOT NULL DEFAULT CURRENT_DATE,
    estado          boolean NOT NULL DEFAULT true
);

-- Horarios de atencion por empleado medico --------------------------------
CREATE TABLE thorario (
    id_horario  integer NOT NULL PRIMARY KEY,
    id_empleado integer NOT NULL REFERENCES templeados(id_empleado),
    dia_semana  smallint NOT NULL,
    id_turno    integer  NOT NULL REFERENCES tturno(id_turno),
    hora_inicio time WITHOUT TIME ZONE NOT NULL,
    hora_fin    time WITHOUT TIME ZONE NOT NULL,
    nro_fichas  integer NOT NULL DEFAULT 5,
    activo      boolean NOT NULL DEFAULT true,
    CONSTRAINT thorario_dia_semana_check  CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT thorario_nro_fichas_check  CHECK (nro_fichas >= 0)
);

-- Fichas de cita -------------------------------------------------------------
CREATE TABLE tficha (
    id_ficha        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nro_ficha       integer NOT NULL,
    id_persona      integer NOT NULL,
    ci_paciente     varchar(15) NOT NULL,
    tipo_paciente   char(1)     NOT NULL DEFAULT 'P',
    id_asegurado    varchar(15) REFERENCES tasegurado(ci),
    id_medico       integer NOT NULL REFERENCES templeados(id_empleado),
    id_especialidad integer NOT NULL REFERENCES tespecialidad(id_especialidad),
    id_horario      integer NOT NULL REFERENCES thorario(id_horario),
    id_servicio     integer REFERENCES tservicios(id_servicio),
    fech_cita       date NOT NULL,
    hora_cita       time WITHOUT TIME ZONE NOT NULL,
    -- Estado: R=Registrada C=Confirmada A=Atendida N=No asistio X=Cancelada
    estado          char(1) NOT NULL DEFAULT 'R',
    observacion     varchar(200) NOT NULL DEFAULT '',
    fech_reg        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_reg     varchar(15) NOT NULL DEFAULT '',
    CONSTRAINT tficha_tipo_paciente_check
        CHECK (tipo_paciente IN ('A','P')),   -- A=Asegurado P=Particular
    CONSTRAINT tficha_estado_check
        CHECK (estado IN ('R','C','A','N','X'))
);


-- =====================================================================
-- 5. INDICES
-- =====================================================================

CREATE INDEX idx_temp_esp_especialidad ON templeado_especialidades(id_especialidad);
CREATE INDEX idx_thorario_id_empleado  ON thorario(id_empleado);
CREATE INDEX idx_ficha_fecha           ON tficha(fech_cita);
CREATE INDEX idx_ficha_horario         ON tficha(id_horario, fech_cita);


-- =====================================================================
-- 6. FUNCIONES
-- =====================================================================

-- Valida que las horas del horario caigan dentro del turno asignado -----
CREATE OR REPLACE FUNCTION trg_valida_horario()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_inicio TIME;
    v_fin    TIME;
    v_cruza  BOOLEAN;
BEGIN
    SELECT t.hora_inicio, t.hora_fin, t.cruza_medianoche
      INTO v_inicio, v_fin, v_cruza
      FROM tturno t
     WHERE t.id_turno = NEW.id_turno;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Turno inexistente: %', NEW.id_turno;
    END IF;

    IF NOT v_cruza THEN
        -- Turno normal (Manana / Tarde): las horas deben caer dentro de la franja
        IF NEW.hora_inicio < v_inicio OR NEW.hora_fin > v_fin THEN
            RAISE EXCEPTION 'El horario %-% no corresponde al turno % (% - %)',
                NEW.hora_inicio, NEW.hora_fin, v_inicio, v_inicio, v_fin;
        END IF;
    ELSE
        -- Turno que cruza la medianoche (Noche)
        IF NEW.hora_inicio <= NEW.hora_fin THEN
            -- no cruza medianoche: solo franja 19:00-24:00 o 00:00-07:00
            IF NEW.hora_fin > v_fin AND NEW.hora_inicio < v_inicio THEN
                RAISE EXCEPTION 'El horario %-% cae en horario de descanso',
                    NEW.hora_inicio, NEW.hora_fin;
            END IF;
        ELSE
            -- cruza medianoche
            IF NEW.hora_inicio < v_inicio OR NEW.hora_fin > v_fin THEN
                RAISE EXCEPTION 'El horario %-% excede el turno nocturno (% - %)',
                    NEW.hora_inicio, NEW.hora_fin, v_inicio, v_fin;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

-- Solo empleados de tipo medico pueden tener horarios o citas -----------
CREATE OR REPLACE FUNCTION f_valida_empleado_medico()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_id   integer;
    v_tipo tipo_empleado_enum;
BEGIN
    v_id := COALESCE((to_jsonb(NEW) ->> 'id_empleado')::integer,
                     (to_jsonb(NEW) ->> 'id_medico')::integer);
    IF v_id IS NULL THEN RETURN NEW; END IF;
    SELECT tipo_empleado INTO v_tipo FROM templeados WHERE id_empleado = v_id;
    IF v_tipo IS DISTINCT FROM 'medico' THEN
        RAISE EXCEPTION 'El empleado % no puede atender citas/horarios (tipo=%)', v_id, v_tipo;
    END IF;
    RETURN NEW;
END $$;

-- Horarios con fichas disponibles para una especialidad y fecha ----------
CREATE OR REPLACE FUNCTION public.fhorarios_disponibles(pid_especialidad integer, pfech_cita date DEFAULT CURRENT_DATE)
 RETURNS TABLE(id_especialidad integer, especialidad text, id_medico integer, medico text, nmp text,
               id_horario integer, dia_semana text, turno text, hora_inicio time without time zone,
               hora_fin time without time zone, fichas_disponibles integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT e.id_especialidad,
           e.nombre_especialidad::TEXT,
           em.id_empleado,
           (p.nombre || ' ' || p.apellidos)::TEXT,
           em.nmp::TEXT,
           h.id_horario,
           CASE h.dia_semana
               WHEN 1 THEN 'Lunes'
               WHEN 2 THEN 'Martes'
               WHEN 3 THEN 'Miercoles'
               WHEN 4 THEN 'Jueves'
               WHEN 5 THEN 'Viernes'
               WHEN 6 THEN 'Sabado'
               WHEN 7 THEN 'Domingo'
           END::TEXT,
           t.descripcion::TEXT,
           h.hora_inicio,
           h.hora_fin,
           (h.nro_fichas - (
                SELECT COUNT(*) FROM tficha f
                 WHERE f.id_horario = h.id_horario
                   AND f.fech_cita  = pfech_cita
                   AND f.estado <> 'X'))::INTEGER
      FROM thorario h
      JOIN templeados em ON em.id_empleado = h.id_empleado AND em.activo = TRUE
      JOIN tpersonas p   ON p.id_persona = em.id_persona
      JOIN templeado_especialidades re ON re.id_empleado = em.id_empleado
      JOIN tespecialidad e ON e.id_especialidad = re.id_especialidad
      JOIN tturno t ON t.id_turno = h.id_turno
     WHERE e.id_especialidad = pid_especialidad
       AND h.activo = TRUE
       AND h.dia_semana = EXTRACT(ISODOW FROM pfech_cita)::SMALLINT
       AND h.nro_fichas > (
            SELECT COUNT(*) FROM tficha f
             WHERE f.id_horario = h.id_horario
               AND f.fech_cita  = pfech_cita
               AND f.estado <> 'X')
     ORDER BY t.id_turno, h.hora_inicio;
END;
$function$;

-- Registro y cambio de estado de fichas (RPC para PostgREST) --------------
CREATE OR REPLACE PROCEDURE public.pficha(IN oper integer, IN pid_ficha integer, IN pid_persona integer, IN pci character varying, IN pid_especialidad integer, IN pid_medico integer, IN pid_horario integer, IN pfech_cita date, IN phora_cita time without time zone, IN pestado character, IN pusuario character varying, IN pobservacion character varying, OUT resultado json)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    filas          INT;
    v_id_ficha     INT;
    v_nro_ficha    INT;
    v_tipo         CHAR(1);
    v_ci_aseg      VARCHAR(15);
    v_hora_ini     TIME;
    v_hora_fin     TIME;
    v_nro_fichas   INT;
    v_dia          SMALLINT;
    v_id_medico    INT;
    v_ocupadas     INT;
BEGIN
    IF oper = 1 THEN
        -- 1) El horario debe existir y estar activo
        SELECT h.hora_inicio, h.hora_fin, h.nro_fichas, h.dia_semana, h.id_empleado
          INTO v_hora_ini, v_hora_fin, v_nro_fichas, v_dia, v_id_medico
          FROM thorario h
         WHERE h.id_horario = pid_horario AND h.activo = TRUE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'El horario no existe o esta inactivo';
        END IF;

        -- 2) El horario debe pertenecer al medico indicado
        IF v_id_medico <> pid_medico THEN
            RAISE EXCEPTION 'El horario no pertenece al medico indicado';
        END IF;

        -- 3) El medico debe atender ese dia de la semana (1=Lunes..7=Domingo)
        IF v_dia <> EXTRACT(ISODOW FROM pfech_cita)::SMALLINT THEN
            RAISE EXCEPTION 'El medico no atiende el dia de la fecha solicitada';
        END IF;

        -- 4) La hora de la cita debe estar dentro del horario
        IF v_hora_ini < v_hora_fin THEN
            IF phora_cita < v_hora_ini OR phora_cita > v_hora_fin THEN
                RAISE EXCEPTION 'La hora % no esta dentro del horario % - %', phora_cita, v_hora_ini, v_hora_fin;
            END IF;
        ELSE
            -- horario que cruza la medianoche
            IF phora_cita < v_hora_ini AND phora_cita > v_hora_fin THEN
                RAISE EXCEPTION 'La hora % no esta dentro del horario nocturno % - %', phora_cita, v_hora_ini, v_hora_fin;
            END IF;
        END IF;

        -- 5) Verificar cupos disponibles para ese horario y fecha
        SELECT COUNT(*) INTO v_ocupadas
          FROM tficha
         WHERE id_horario = pid_horario AND fech_cita = pfech_cita AND estado <> 'X';

        IF v_ocupadas >= v_nro_fichas THEN
            RAISE EXCEPTION 'No hay fichas disponibles para ese horario (cupo %)', v_nro_fichas;
        END IF;

        -- 6) Determinar si el paciente es asegurado (existe su CI en tasegurado)
        SELECT t.ci INTO v_ci_aseg
          FROM tasegurado t
         WHERE t.ci = pci AND t.estado = TRUE;

        IF v_ci_aseg IS NOT NULL THEN
            v_tipo := 'A';
        ELSE
            v_tipo := 'P';
        END IF;

        -- 7) Numero de ficha consecutivo del dia
        SELECT COALESCE(MAX(nro_ficha), 0) + 1 INTO v_nro_ficha
          FROM tficha
         WHERE fech_cita = pfech_cita;

        -- 8) Insertar la ficha
        INSERT INTO tficha (nro_ficha, id_persona, ci_paciente, tipo_paciente, id_asegurado,
                            id_medico, id_especialidad, id_horario, fech_cita, hora_cita,
                            estado, observacion, usuario_reg)
        VALUES (v_nro_ficha, pid_persona, pci, v_tipo, v_ci_aseg,
                pid_medico, pid_especialidad, pid_horario, pfech_cita, phora_cita,
                'R', pobservacion, pusuario)
        RETURNING id_ficha INTO v_id_ficha;

        resultado := json_build_object(
            'success',       TRUE,
            'id_ficha',      v_id_ficha,
            'nro_ficha',     v_nro_ficha,
            'tipo_paciente', v_tipo,
            'message',       'Ficha registrada correctamente'
        );

    ELSIF oper = 2 THEN
        UPDATE tficha SET estado = pestado WHERE id_ficha = pid_ficha;
        GET DIAGNOSTICS filas = ROW_COUNT;

        IF filas = 0 THEN
            resultado := json_build_object('success', FALSE, 'message', 'Ficha no encontrada');
        ELSE
            resultado := json_build_object('success', TRUE, 'message', 'Estado de ficha actualizado');
        END IF;

    ELSE
        resultado := json_build_object('success', FALSE, 'message', 'Operacion no valida');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        resultado := json_build_object(
            'success', FALSE,
            'message', 'Error en la base de datos',
            'details', SQLERRM
        );
END;
$procedure$;


-- =====================================================================
-- 7. TRIGGERS
-- =====================================================================

-- Horarios: validar coherencia con el turno -------------------------------
CREATE TRIGGER trg_valida_horario
    BEFORE INSERT OR UPDATE OF hora_inicio, hora_fin, id_turno ON thorario
    FOR EACH ROW EXECUTE FUNCTION trg_valida_horario();

-- Horarios: solo medicos ---------------------------------------------------
CREATE TRIGGER trg_horario_solo_medico
    BEFORE INSERT OR UPDATE OF id_empleado ON thorario
    FOR EACH ROW EXECUTE FUNCTION f_valida_empleado_medico();

-- Fichas: solo medicos ------------------------------------------------------
CREATE TRIGGER trg_ficha_solo_medico
    BEFORE INSERT OR UPDATE OF id_medico ON tficha
    FOR EACH ROW EXECUTE FUNCTION f_valida_empleado_medico();


-- =====================================================================
-- 8. VISTA
-- =====================================================================

-- Fichas del dia con datos legibles (paciente, medico, servicio, estado) --
CREATE VIEW public.v_fichas_dia AS
 SELECT f.id_ficha,
        f.nro_ficha,
        f.id_persona,
        f.ci_paciente,
        f.tipo_paciente,
        CASE f.tipo_paciente
            WHEN 'A'::bpchar THEN 'Asegurado'::text
            ELSE 'Particular'::text
        END AS tipo_desc,
        CASE WHEN a.ci IS NOT NULL
             THEN ((a.nombre::text || ' ') || a.paterno::text) || ' ' || a.materno::text
             ELSE f.ci_paciente::text
        END AS paciente,
        e.nombre_especialidad AS especialidad,
        (((mp.nombre::text || ' ') || mp.apellidos::text)) AS medico,
        s.nombre_servicio AS servicio,
        f.fech_cita,
        f.hora_cita,
        f.estado,
        CASE f.estado
            WHEN 'R'::bpchar THEN 'Registrada'::text
            WHEN 'C'::bpchar THEN 'Confirmada'::text
            WHEN 'A'::bpchar THEN 'Atendida'::text
            WHEN 'N'::bpchar THEN 'No asistio'::text
            WHEN 'X'::bpchar THEN 'Cancelada'::text
            ELSE NULL::text
        END AS estado_desc,
        f.observacion,
        f.fech_reg,
        f.usuario_reg
   FROM tficha f
     JOIN tespecialidad e ON e.id_especialidad = f.id_especialidad
     JOIN templeados em ON em.id_empleado = f.id_medico
     JOIN tpersonas mp ON mp.id_persona = em.id_persona
     LEFT JOIN tservicios s ON s.id_servicio = f.id_servicio
     LEFT JOIN tasegurado a ON a.ci::text = f.id_asegurado::text;