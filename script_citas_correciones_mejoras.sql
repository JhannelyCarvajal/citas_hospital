-- =====================================================================
-- SCRIPT  ·  citas medicas (bd_hospital)
-- Aplica: 1) cambio de esquema  +  2) datos de prueba (asegurados)
-- Ejecutar UNA vez contra una BD con el dump del proyecto.
-- =====================================================================

BEGIN;

-- La vista depende de tc_ficha.tipo_paciente; se recrea al final.
DROP VIEW IF EXISTS public.v_fichas_dia;

-- Ampliar tipo de paciente (antes varchar(11)) para permitir
-- "Asegurado vencido".
ALTER TABLE tc_ficha ALTER COLUMN tipo_paciente TYPE varchar(30);

-- CHECK con los 3 valores posibles.c
ALTER TABLE tc_ficha DROP CONSTRAINT IF EXISTS tc_ficha_tipo_paciente_check;
ALTER TABLE tc_ficha ADD CONSTRAINT tc_ficha_tipo_paciente_check
  CHECK (tipo_paciente::text = ANY (ARRAY['Asegurado','Asegurado vencido','Particular']::text[]));

-- Nueva columna: vencimiento de la poliza (NULL = sin vencimiento / indefinido).
ALTER TABLE tp_asegurado ADD COLUMN IF NOT EXISTS fech_fin date;

-- Recrear la vista (misma definicion que tenia).
CREATE VIEW public.v_fichas_dia AS
 SELECT f.id_ficha,
    f.nro_ficha,
    f.id_persona,
    f.ci_paciente,
    f.tipo_paciente,
    f.tipo_paciente AS tipo_desc,
        CASE
            WHEN (a.ci IS NOT NULL) THEN (((((a.nombre)::text || ' '::text) || (a.paterno)::text) || ' '::text) || (a.materno)::text)
            ELSE (f.ci_paciente)::text
        END AS paciente,
    e.nombre_especialidad AS especialidad,
    (((mp.nombres)::text || ' '::text) || (mp.apellidos)::text) AS medico,
    s.nombre_servicio AS servicio,
    f.fech_cita,
    f.hora_cita,
    f.estado,
    f.estado AS estado_desc,
    f.observacion,
    f.fech_reg,
    f.usuario_reg
   FROM (((((public.tc_ficha f
     JOIN public.tp_especialidades e ON ((e.id_especialidad = f.id_especialidad)))
     JOIN public.tp_empleados em ON ((em.id_empleado = f.id_medico)))
     JOIN public.tp_personas mp ON ((mp.id_persona = em.id_persona)))
     LEFT JOIN public.tc_servicios s ON ((s.id_servicio = f.id_servicio)))
     LEFT JOIN public.tp_asegurado a ON (((a.ci)::text = (f.id_asegurado)::text)));


-- ---------------------------------------------------------------------
-- LIMPIEZA

-- ---------------------------------------------------------------------
-- Borra fichas donde 'paciente' es un medico (doctor-paciente).
DELETE FROM public.tc_ficha
WHERE id_persona IN (SELECT id_persona FROM public.tp_empleados WHERE LOWER(tipo_empleado) = 'medico');
-- Borra fichas con paciente inexistente
DELETE FROM public.tc_ficha
WHERE id_persona NOT IN (SELECT id_persona FROM public.tp_personas);
-- Borra el asegurado de prueba que pertenecia al doctor Carlos Mendoza (CI 1234567).
DELETE FROM public.tp_asegurado WHERE ci = '1234567';

COMMIT;