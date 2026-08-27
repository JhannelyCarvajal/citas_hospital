DROP FUNCTION IF EXISTS public.fhorarios_disponibles(integer, date);

CREATE OR REPLACE FUNCTION public.fhorarios_disponibles(pid_especialidad integer, pfech_cita date DEFAULT CURRENT_DATE)
RETURNS TABLE(
    id_especialidad integer,
    especialidad text,
    id_medico integer,
    medico text,
    id_horario integer,
    dia_semana text,
    turno text,
    hora_inicio time without time zone,
    hora_fin time without time zone,
    fichas_disponibles integer
) LANGUAGE plpgsql AS $function$
BEGIN
    RETURN QUERY
    SELECT e.id_especialidad,
           e.nombre_especialidad::TEXT,
           em.id_empleado,
           (p.nombres || ' ' || p.apellidos)::TEXT,
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
           t.nombre_turno::TEXT,
           h.hora_inicio,
           h.hora_fin,
           (h.nro_fichas - (
                SELECT COUNT(*) FROM tc_ficha f
                 WHERE f.id_horario = h.id_horario
                   AND f.fech_cita  = pfech_cita
                   AND f.estado <> 'X'))::INTEGER
      FROM tc_horario h
      JOIN tp_empleados em ON em.id_empleado = h.id_empleado AND em.activo = TRUE
      JOIN tp_personas p   ON p.id_persona = em.id_persona
      JOIN tp_empleado_especialidades re ON re.id_empleado = em.id_empleado
      JOIN tp_especialidades e ON e.id_especialidad = re.id_especialidad
      JOIN tp_turnos t ON t.id_turno = h.id_turno
     WHERE e.id_especialidad = pid_especialidad
       AND h.activo = TRUE
       AND h.dia_semana = EXTRACT(ISODOW FROM pfech_cita)::SMALLINT
       AND h.nro_fichas > (
            SELECT COUNT(*) FROM tc_ficha f
             WHERE f.id_horario = h.id_horario
               AND f.fech_cita  = pfech_cita
               AND f.estado <> 'X')
     ORDER BY t.id_turno, h.hora_inicio;
END;
$function$;
