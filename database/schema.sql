--
-- PostgreSQL database dump
--

\restrict oqHw9ziBveJFAAkwJqnMBkBpffnFh0kzxrg84ERqhvi7Kod3IbiLJWdDnjifv1w

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

-- Started on 2026-08-27 22:05:45

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 1099 (class 1247 OID 19828)
-- Name: tipo_empleado_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tipo_empleado_enum AS ENUM (
    'medico',
    'enfermero',
    'administrativo',
    'auxiliar',
    'otro'
);


--
-- TOC entry 1096 (class 1247 OID 19818)
-- Name: tipo_especialidad_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tipo_especialidad_enum AS ENUM (
    'medica',
    'enfermeria',
    'apoyo',
    'administrativa'
);


--
-- TOC entry 338 (class 1255 OID 19976)
-- Name: f_valida_empleado_medico(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.f_valida_empleado_medico() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id   integer;
    v_tipo varchar(20);
BEGIN
    v_id := COALESCE((to_jsonb(NEW) ->> 'id_empleado')::integer,
                     (to_jsonb(NEW) ->> 'id_medico')::integer);
    IF v_id IS NULL THEN RETURN NEW; END IF;
    SELECT tipo_empleado INTO v_tipo FROM tp_empleados WHERE id_empleado = v_id;
    IF LOWER(v_tipo) IS DISTINCT FROM 'medico' THEN
        RAISE EXCEPTION 'El empleado % no puede atender citas/horarios (tipo=%)', v_id, v_tipo;
    END IF;
    RETURN NEW;
END $$;


--
-- TOC entry 337 (class 1255 OID 20014)
-- Name: fhorarios_disponibles(integer, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fhorarios_disponibles(pid_especialidad integer, pfech_cita date DEFAULT CURRENT_DATE) RETURNS TABLE(id_especialidad integer, especialidad text, id_medico integer, medico text, id_horario integer, dia_semana text, turno text, hora_inicio time without time zone, hora_fin time without time zone, fichas_disponibles integer)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- TOC entry 316 (class 1255 OID 19808)
-- Name: fn_bloquear_soap_finalizado(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_bloquear_soap_finalizado() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.esta_bloqueado = TRUE THEN
        RAISE EXCEPTION 'Excepción Médico-Legal: No se permite la alteración de un expediente clínico firmado y cerrado (R.M. 0090/2008).';
    END IF;

    IF NEW.esta_bloqueado = TRUE AND (OLD.esta_bloqueado = FALSE OR OLD.esta_bloqueado IS NULL) THEN
        NEW.fecha_bloqueo := CURRENT_TIMESTAMP;
        NEW.firma_digital_sello := md5(NEW.id::text || NEW.analisis_cie10 || NEW.medico_id::text || CURRENT_TIMESTAMP::text);
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 335 (class 1255 OID 19816)
-- Name: pa_finalizar_atencion_medica(bigint, character varying, bigint, text); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pa_finalizar_atencion_medica(IN p_atencion_id bigint, IN p_destino character varying, IN p_medico_cierre_id bigint, IN p_resumen_alta text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_paciente_id BIGINT;
    v_trazabilidad_id VARCHAR(64);
    v_payload_g1 JSONB;
    v_payload_g4 JSONB;
    v_historia_soap_id BIGINT;
BEGIN
    SELECT paciente_id, id_trazabilidad INTO v_paciente_id, v_trazabilidad_id
    FROM ta_atenciones_medicas WHERE id = p_atencion_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Error: El ID de atención médica proporcionado no existe en el sistema.';
    END IF;

    SELECT id INTO v_historia_soap_id FROM ta_historias_clinicas_soap
    WHERE atencion_id = p_atencion_id AND esta_bloqueado = TRUE
    ORDER BY fecha_creacion DESC LIMIT 1;

    INSERT INTO ta_cierres_atenciones (atencion_id, destino, resumen_alta, medico_cierre_id)
    VALUES (p_atencion_id, p_destino, p_resumen_alta, p_medico_cierre_id);

    UPDATE ta_atenciones_medicas
    SET estado = 'Finalizado', fecha_cierre = CURRENT_TIMESTAMP
    WHERE id = p_atencion_id;

    SELECT jsonb_build_object(
        'id_trazabilidad', v_trazabilidad_id,
        'paciente_id', v_paciente_id,
        'atencion_id', p_atencion_id,
        'medico_cierre_id', p_medico_cierre_id,
        'servicios_prestados', (
            SELECT jsonb_agg(jsonb_build_object('item', nombre_medicamento, 'cantidad', cantidad))
            FROM ta_prescripciones WHERE historia_soap_id = v_historia_soap_id
        )
    ) INTO v_payload_g1;

    INSERT INTO ta_cola_mensajes (servicio_destino, endpoint, payload_json, id_trazabilidad)
    VALUES ('G1_FACTURACION', '/api/v1/facturas/recibir-cargo', v_payload_g1, v_trazabilidad_id);

    SELECT jsonb_build_object(
        'id_trazabilidad', v_trazabilidad_id,
        'receta_id', v_historia_soap_id,
        'medicamentos', (
            SELECT jsonb_agg(jsonb_build_object('medicamento_id', medicamento_id, 'cantidad', cantidad))
            FROM ta_prescripciones WHERE historia_soap_id = v_historia_soap_id
        )
    ) INTO v_payload_g4;

    INSERT INTO ta_cola_mensajes (servicio_destino, endpoint, payload_json, id_trazabilidad)
    VALUES ('G4_FARMACIA', '/api/v1/inventario/descontar', v_payload_g4, v_trazabilidad_id);

    COMMIT;
END;
$$;


--
-- TOC entry 323 (class 1255 OID 19815)
-- Name: pa_registrar_derivacion(bigint, character varying, character varying, text, bigint); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pa_registrar_derivacion(IN p_atencion_id bigint, IN p_form_301 character varying, IN p_destino character varying, IN p_motivo text, IN p_medico_id bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO ta_derivaciones_externas (
        atencion_id, formulario_301_nro, establecimiento_destino,
        motivo_derivación, medico_derivador_id
    ) VALUES (
        p_atencion_id, p_form_301, p_destino, p_motivo, p_medico_id
    );

    UPDATE ta_atenciones_medicas
    SET estado = 'Finalizado', fecha_cierre = CURRENT_TIMESTAMP
    WHERE id = p_atencion_id;

    COMMIT;
END;
$$;


--
-- TOC entry 319 (class 1255 OID 19811)
-- Name: pa_registrar_nota_soap(bigint, bigint, text, text, character varying, text, text, boolean); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pa_registrar_nota_soap(IN p_atencion_id bigint, IN p_medico_id bigint, IN p_subjetivo text, IN p_objetivo text, IN p_analisis_cie10 character varying, IN p_diagnostico text, IN p_plan text, IN p_bloquear boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO ta_historias_clinicas_soap (
        atencion_id, medico_id, subjetivo, objetivo,
        analisis_cie10, diagnostico_descripcion, plan_tratamiento, esta_bloqueado
    ) VALUES (
        p_atencion_id, p_medico_id, p_subjetivo, p_objetivo,
        p_analisis_cie10, p_diagnostico, p_plan, p_bloquear
    );

    UPDATE ta_atenciones_medicas
    SET estado = 'Atención'
    WHERE id = p_atencion_id AND estado != 'Finalizado';

    COMMIT;
END;
$$;


--
-- TOC entry 321 (class 1255 OID 19813)
-- Name: pa_registrar_orden_examen(bigint, character varying, text); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pa_registrar_orden_examen(IN p_historia_soap_id bigint, IN p_tipo_examen character varying, IN p_indicaciones text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO ta_ordenes_examenes (
        historia_soap_id, tipo_examen, indicaciones
    ) VALUES (
        p_historia_soap_id, p_tipo_examen, p_indicaciones
    );

    COMMIT;
END;
$$;


--
-- TOC entry 320 (class 1255 OID 19812)
-- Name: pa_registrar_prescripcion(bigint, bigint, character varying, text, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pa_registrar_prescripcion(IN p_historia_soap_id bigint, IN p_medicamento_id bigint, IN p_nombre_medicamento character varying, IN p_dosis text, IN p_cantidad integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO ta_prescripciones (
        historia_soap_id, medicamento_id, nombre_medicamento, dosis_instrucciones, cantidad
    ) VALUES (
        p_historia_soap_id, p_medicamento_id, p_nombre_medicamento, p_dosis, p_cantidad
    );

    COMMIT;
END;
$$;


--
-- TOC entry 322 (class 1255 OID 19814)
-- Name: pa_registrar_procedimiento_quirurgico(bigint, character varying, bigint, bigint, timestamp with time zone, timestamp with time zone, text); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pa_registrar_procedimiento_quirurgico(IN p_atencion_id bigint, IN p_nombre character varying, IN p_cirujano_id bigint, IN p_anestesiologo_id bigint, IN p_inicio timestamp with time zone, IN p_fin timestamp with time zone, IN p_obs text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO ta_procedimientos_quirurgicos (
        atencion_id, nombre_procedimiento, cirujano_id, anestesiologo_id,
        fecha_hora_inicio, fecha_hora_fin, observaciones_quirurgicas
    ) VALUES (
        p_atencion_id, p_nombre, p_cirujano_id, p_anestesiologo_id,
        p_inicio, p_fin, p_obs
    );

    UPDATE ta_atenciones_medicas
    SET estado = 'Observación'
    WHERE id = p_atencion_id;

    COMMIT;
END;
$$;


--
-- TOC entry 318 (class 1255 OID 19810)
-- Name: pa_registrar_triaje(bigint, bigint, integer, integer, integer, integer, integer, numeric, integer, integer, character varying, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pa_registrar_triaje(IN p_atencion_id bigint, IN p_enfermero_id bigint, IN p_sistolica integer, IN p_diastolica integer, IN p_fc integer, IN p_fr integer, IN p_so2 integer, IN p_temp numeric, IN p_glasgow integer, IN p_dolor integer, IN p_prioridad character varying, IN p_espera integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO ta_triajes (
        atencion_id, enfermero_id, presion_sistolica, presion_diastolica,
        frecuencia_cardiaca, frecuencia_respiratoria, saturacion_oxigeno,
        temperatura, escala_glasgow, nivel_dolor, prioridad_color, tiempo_espera_max_min
    ) VALUES (
        p_atencion_id, p_enfermero_id, p_sistolica, p_diastolica,
        p_fc, p_fr, p_so2, p_temp, p_glasgow, p_dolor, p_prioridad, p_espera
    );

    UPDATE ta_atenciones_medicas
    SET estado = 'Triaje'
    WHERE id = p_atencion_id;

    COMMIT;
END;
$$;


--
-- TOC entry 336 (class 1255 OID 19978)
-- Name: pficha(integer, integer, integer, character varying, integer, integer, integer, date, time without time zone, character, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pficha(IN oper integer, IN pid_ficha integer, IN pid_persona integer, IN pci character varying, IN pid_especialidad integer, IN pid_medico integer, IN pid_horario integer, IN pfech_cita date, IN phora_cita time without time zone, IN pestado character, IN pusuario character varying, IN pobservacion character varying, OUT resultado json)
    LANGUAGE plpgsql
    AS $$
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
          FROM tc_horario h
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
          FROM tc_ficha
         WHERE id_horario = pid_horario AND fech_cita = pfech_cita AND estado <> 'X';

        IF v_ocupadas >= v_nro_fichas THEN
            RAISE EXCEPTION 'No hay fichas disponibles para ese horario (cupo %)', v_nro_fichas;
        END IF;

        -- 6) Determinar si el paciente es asegurado (existe su CI en tasegurado)
        SELECT t.ci INTO v_ci_aseg
          FROM tp_asegurado t
         WHERE t.ci = pci AND t.estado = TRUE;

        IF v_ci_aseg IS NOT NULL THEN
            v_tipo := 'A';
        ELSE
            v_tipo := 'P';
        END IF;

        -- 7) Numero de ficha consecutivo del dia
        SELECT COALESCE(MAX(nro_ficha), 0) + 1 INTO v_nro_ficha
          FROM tc_ficha
         WHERE fech_cita = pfech_cita;

        -- 8) Insertar la ficha
        INSERT INTO tc_ficha (nro_ficha, id_persona, ci_paciente, tipo_paciente, id_asegurado,
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
        UPDATE tc_ficha SET estado = pestado WHERE id_ficha = pid_ficha;
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
$$;


--
-- TOC entry 317 (class 1255 OID 20038)
-- Name: pficha(integer, integer, integer, character varying, integer, integer, integer, date, time without time zone, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pficha(IN oper integer, IN pid_ficha integer, IN pid_persona integer, IN pci character varying, IN pid_especialidad integer, IN pid_medico integer, IN pid_horario integer, IN pfech_cita date, IN phora_cita time without time zone, IN pestado character varying, IN pusuario character varying, IN pobservacion character varying, OUT resultado json)
    LANGUAGE plpgsql
    AS $$
DECLARE
    filas          INT;
    v_id_ficha     INT;
    v_nro_ficha    INT;
    v_tipo         VARCHAR(11);
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
          FROM tc_horario h
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
          FROM tc_ficha
         WHERE id_horario = pid_horario AND fech_cita = pfech_cita AND estado <> 'Cancelada';

        IF v_ocupadas >= v_nro_fichas THEN
            RAISE EXCEPTION 'No hay fichas disponibles para ese horario (cupo %)', v_nro_fichas;
        END IF;

        -- 6) Determinar si el paciente es asegurado (existe su CI en tasegurado)
        SELECT t.ci INTO v_ci_aseg
          FROM tp_asegurado t
         WHERE t.ci = pci AND t.estado = TRUE;

        IF v_ci_aseg IS NOT NULL THEN
            v_tipo := 'Asegurado';
        ELSE
            v_tipo := 'Particular';
        END IF;

        -- 7) Numero de ficha consecutivo del dia
        SELECT COALESCE(MAX(nro_ficha), 0) + 1 INTO v_nro_ficha
          FROM tc_ficha
         WHERE fech_cita = pfech_cita;

        -- 8) Insertar la ficha
        INSERT INTO tc_ficha (nro_ficha, id_persona, ci_paciente, tipo_paciente, id_asegurado,
                            id_medico, id_especialidad, id_horario, fech_cita, hora_cita,
                            estado, observacion, usuario_reg)
        VALUES (v_nro_ficha, pid_persona, pci, v_tipo, v_ci_aseg,
                pid_medico, pid_especialidad, pid_horario, pfech_cita, phora_cita,
                'Registrada', pobservacion, pusuario)
        RETURNING id_ficha INTO v_id_ficha;

        resultado := json_build_object(
            'success',       TRUE,
            'id_ficha',      v_id_ficha,
            'nro_ficha',     v_nro_ficha,
            'tipo_paciente', v_tipo,
            'message',       'Ficha registrada correctamente'
        );

    ELSIF oper = 2 THEN
        UPDATE tc_ficha SET estado = pestado WHERE id_ficha = pid_ficha;
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
$$;


--
-- TOC entry 339 (class 1255 OID 19975)
-- Name: trg_valida_horario(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_valida_horario() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_inicio TIME;
    v_fin    TIME;
BEGIN
    SELECT t.hora_inicio, t.hora_fin
      INTO v_inicio, v_fin
      FROM tp_turnos t
     WHERE t.id_turno = NEW.id_turno;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Turno inexistente: %', NEW.id_turno;
    END IF;

    IF NEW.hora_inicio < v_inicio OR NEW.hora_fin > v_fin THEN
        RAISE EXCEPTION 'El horario %-% no corresponde al turno % (% - %)',
            NEW.hora_inicio, NEW.hora_fin, NEW.id_turno, v_inicio, v_fin;
    END IF;

    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 287 (class 1259 OID 19560)
-- Name: ta_atenciones_medicas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ta_atenciones_medicas (
    id bigint NOT NULL,
    medico_id bigint NOT NULL,
    id_trazabilidad character varying(64) NOT NULL,
    tipo_ingreso character varying(20) NOT NULL,
    estado character varying(20) DEFAULT 'Admisión'::character varying NOT NULL,
    fecha_apertura timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_cierre timestamp with time zone,
    paciente_id bigint NOT NULL,
    CONSTRAINT ta_atenciones_medicas_estado_check CHECK (((estado)::text = ANY ((ARRAY['Admisión'::character varying, 'Triaje'::character varying, 'Atención'::character varying, 'Observación'::character varying, 'Finalizado'::character varying])::text[]))),
    CONSTRAINT ta_atenciones_medicas_tipo_ingreso_check CHECK (((tipo_ingreso)::text = ANY ((ARRAY['Urgencias'::character varying, 'Consulta_Externa'::character varying])::text[])))
);


--
-- TOC entry 286 (class 1259 OID 19559)
-- Name: ta_atenciones_medicas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ta_atenciones_medicas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5606 (class 0 OID 0)
-- Dependencies: 286
-- Name: ta_atenciones_medicas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ta_atenciones_medicas_id_seq OWNED BY public.ta_atenciones_medicas.id;


--
-- TOC entry 305 (class 1259 OID 19766)
-- Name: ta_cierres_atenciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ta_cierres_atenciones (
    id bigint NOT NULL,
    destino character varying(25) NOT NULL,
    resumen_alta text NOT NULL,
    medico_cierre_id bigint NOT NULL,
    fecha_cierre timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    atencion_id bigint NOT NULL,
    CONSTRAINT ta_cierres_atenciones_destino_check CHECK (((destino)::text = ANY ((ARRAY['Alta'::character varying, 'Internación'::character varying, 'Observación'::character varying, 'Referencia_Externa'::character varying])::text[])))
);


--
-- TOC entry 304 (class 1259 OID 19765)
-- Name: ta_cierres_atenciones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ta_cierres_atenciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5607 (class 0 OID 0)
-- Dependencies: 304
-- Name: ta_cierres_atenciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ta_cierres_atenciones_id_seq OWNED BY public.ta_cierres_atenciones.id;


--
-- TOC entry 307 (class 1259 OID 19789)
-- Name: ta_cola_mensajes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ta_cola_mensajes (
    id bigint NOT NULL,
    servicio_destino character varying(30) NOT NULL,
    endpoint character varying(100) NOT NULL,
    payload_json jsonb NOT NULL,
    id_trazabilidad character varying(64) NOT NULL,
    estado_envio character varying(15) DEFAULT 'Pendiente'::character varying NOT NULL,
    intentos integer DEFAULT 0,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    ultimo_intento timestamp with time zone,
    CONSTRAINT ta_cola_mensajes_estado_envio_check CHECK (((estado_envio)::text = ANY ((ARRAY['Pendiente'::character varying, 'Enviado'::character varying, 'Fallido'::character varying])::text[]))),
    CONSTRAINT ta_cola_mensajes_servicio_destino_check CHECK (((servicio_destino)::text = ANY ((ARRAY['G1_FACTURACION'::character varying, 'G4_FARMACIA'::character varying])::text[])))
);


--
-- TOC entry 306 (class 1259 OID 19788)
-- Name: ta_cola_mensajes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ta_cola_mensajes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5608 (class 0 OID 0)
-- Dependencies: 306
-- Name: ta_cola_mensajes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ta_cola_mensajes_id_seq OWNED BY public.ta_cola_mensajes.id;


--
-- TOC entry 303 (class 1259 OID 19743)
-- Name: ta_derivaciones_externas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ta_derivaciones_externas (
    id bigint NOT NULL,
    formulario_301_nro character varying(20) NOT NULL,
    establecimiento_destino character varying(100) NOT NULL,
    "motivo_derivación" text NOT NULL,
    medico_derivador_id bigint NOT NULL,
    fecha_derivacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    atencion_id bigint NOT NULL
);


--
-- TOC entry 302 (class 1259 OID 19742)
-- Name: ta_derivaciones_externas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ta_derivaciones_externas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5609 (class 0 OID 0)
-- Dependencies: 302
-- Name: ta_derivaciones_externas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ta_derivaciones_externas_id_seq OWNED BY public.ta_derivaciones_externas.id;


--
-- TOC entry 291 (class 1259 OID 19619)
-- Name: ta_historias_clinicas_soap; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ta_historias_clinicas_soap (
    id bigint NOT NULL,
    medico_id bigint NOT NULL,
    subjetivo text NOT NULL,
    objetivo text NOT NULL,
    analisis_cie10 character varying(15) NOT NULL,
    diagnostico_descripcion text NOT NULL,
    plan_tratamiento text NOT NULL,
    esta_bloqueado boolean DEFAULT false,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_bloqueo timestamp with time zone,
    firma_digital_sello character varying(64),
    atencion_id bigint NOT NULL
);


--
-- TOC entry 290 (class 1259 OID 19618)
-- Name: ta_historias_clinicas_soap_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ta_historias_clinicas_soap_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5610 (class 0 OID 0)
-- Dependencies: 290
-- Name: ta_historias_clinicas_soap_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ta_historias_clinicas_soap_id_seq OWNED BY public.ta_historias_clinicas_soap.id;


--
-- TOC entry 295 (class 1259 OID 19665)
-- Name: ta_ordenes_examenes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ta_ordenes_examenes (
    id bigint NOT NULL,
    tipo_examen character varying(50) NOT NULL,
    indicaciones text NOT NULL,
    estado character varying(20) DEFAULT 'Solicitado'::character varying NOT NULL,
    fecha_solicitud timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    historia_soap_id bigint NOT NULL,
    CONSTRAINT ta_ordenes_examenes_estado_check CHECK (((estado)::text = ANY ((ARRAY['Solicitado'::character varying, 'En_Proceso'::character varying, 'Realizado'::character varying, 'Cancelado'::character varying])::text[])))
);


--
-- TOC entry 294 (class 1259 OID 19664)
-- Name: ta_ordenes_examenes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ta_ordenes_examenes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5611 (class 0 OID 0)
-- Dependencies: 294
-- Name: ta_ordenes_examenes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ta_ordenes_examenes_id_seq OWNED BY public.ta_ordenes_examenes.id;


--
-- TOC entry 285 (class 1259 OID 19541)
-- Name: ta_pacientes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ta_pacientes (
    id bigint NOT NULL,
    ci character varying(15) NOT NULL,
    nombre character varying(50) NOT NULL,
    apellidos character varying(80) NOT NULL,
    fecha_nacimiento date NOT NULL,
    genero character(1),
    tipo_seguro character varying(25) DEFAULT 'Particular'::character varying NOT NULL,
    telefono character varying(15),
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ta_pacientes_genero_check CHECK ((genero = ANY (ARRAY['M'::bpchar, 'F'::bpchar, 'O'::bpchar]))),
    CONSTRAINT ta_pacientes_tipo_seguro_check CHECK (((tipo_seguro)::text = ANY ((ARRAY['SUS'::character varying, 'Caja_Salud'::character varying, 'Particular'::character varying, 'Convenio'::character varying])::text[])))
);


--
-- TOC entry 284 (class 1259 OID 19540)
-- Name: ta_pacientes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ta_pacientes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5612 (class 0 OID 0)
-- Dependencies: 284
-- Name: ta_pacientes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ta_pacientes_id_seq OWNED BY public.ta_pacientes.id;


--
-- TOC entry 293 (class 1259 OID 19643)
-- Name: ta_prescripciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ta_prescripciones (
    id bigint NOT NULL,
    medicamento_id bigint NOT NULL,
    nombre_medicamento character varying(100) NOT NULL,
    dosis_instrucciones text NOT NULL,
    cantidad integer NOT NULL,
    fecha_prescripcion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    historia_soap_id bigint NOT NULL,
    CONSTRAINT ta_prescripciones_cantidad_check CHECK ((cantidad > 0))
);


--
-- TOC entry 292 (class 1259 OID 19642)
-- Name: ta_prescripciones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ta_prescripciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5613 (class 0 OID 0)
-- Dependencies: 292
-- Name: ta_prescripciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ta_prescripciones_id_seq OWNED BY public.ta_prescripciones.id;


--
-- TOC entry 299 (class 1259 OID 19709)
-- Name: ta_procedimiento_insumos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ta_procedimiento_insumos (
    id bigint NOT NULL,
    insumo_id bigint NOT NULL,
    nombre_insumo character varying(100) NOT NULL,
    cantidad_utilizada integer NOT NULL,
    procedimiento_id bigint NOT NULL,
    CONSTRAINT ta_procedimiento_insumos_cantidad_utilizada_check CHECK ((cantidad_utilizada > 0))
);


--
-- TOC entry 298 (class 1259 OID 19708)
-- Name: ta_procedimiento_insumos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ta_procedimiento_insumos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5614 (class 0 OID 0)
-- Dependencies: 298
-- Name: ta_procedimiento_insumos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ta_procedimiento_insumos_id_seq OWNED BY public.ta_procedimiento_insumos.id;


--
-- TOC entry 301 (class 1259 OID 19727)
-- Name: ta_procedimiento_personal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ta_procedimiento_personal (
    id bigint NOT NULL,
    personal_id bigint NOT NULL,
    rol character varying(50) NOT NULL,
    procedimiento_id bigint NOT NULL
);


--
-- TOC entry 300 (class 1259 OID 19726)
-- Name: ta_procedimiento_personal_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ta_procedimiento_personal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5615 (class 0 OID 0)
-- Dependencies: 300
-- Name: ta_procedimiento_personal_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ta_procedimiento_personal_id_seq OWNED BY public.ta_procedimiento_personal.id;


--
-- TOC entry 297 (class 1259 OID 19687)
-- Name: ta_procedimientos_quirurgicos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ta_procedimientos_quirurgicos (
    id bigint NOT NULL,
    nombre_procedimiento character varying(150) NOT NULL,
    cirujano_id bigint NOT NULL,
    anestesiologo_id bigint NOT NULL,
    fecha_hora_inicio timestamp with time zone NOT NULL,
    fecha_hora_fin timestamp with time zone NOT NULL,
    observaciones_quirurgicas text,
    atencion_id bigint NOT NULL,
    CONSTRAINT ta_procedimientos_quirurgicos_check CHECK ((fecha_hora_fin > fecha_hora_inicio))
);


--
-- TOC entry 296 (class 1259 OID 19686)
-- Name: ta_procedimientos_quirurgicos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ta_procedimientos_quirurgicos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5616 (class 0 OID 0)
-- Dependencies: 296
-- Name: ta_procedimientos_quirurgicos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ta_procedimientos_quirurgicos_id_seq OWNED BY public.ta_procedimientos_quirurgicos.id;


--
-- TOC entry 289 (class 1259 OID 19582)
-- Name: ta_triajes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ta_triajes (
    id bigint NOT NULL,
    enfermero_id bigint NOT NULL,
    presion_sistolica integer NOT NULL,
    presion_diastolica integer NOT NULL,
    frecuencia_cardiaca integer NOT NULL,
    frecuencia_respiratoria integer NOT NULL,
    saturacion_oxigeno integer NOT NULL,
    temperatura numeric(4,2) NOT NULL,
    escala_glasgow integer NOT NULL,
    nivel_dolor integer NOT NULL,
    prioridad_color character varying(10) NOT NULL,
    tiempo_espera_max_min integer NOT NULL,
    fecha_evaluacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    atencion_id bigint NOT NULL,
    CONSTRAINT ta_triajes_escala_glasgow_check CHECK (((escala_glasgow >= 3) AND (escala_glasgow <= 15))),
    CONSTRAINT ta_triajes_frecuencia_cardiaca_check CHECK (((frecuencia_cardiaca >= 30) AND (frecuencia_cardiaca <= 220))),
    CONSTRAINT ta_triajes_frecuencia_respiratoria_check CHECK (((frecuencia_respiratoria >= 8) AND (frecuencia_respiratoria <= 60))),
    CONSTRAINT ta_triajes_nivel_dolor_check CHECK (((nivel_dolor >= 0) AND (nivel_dolor <= 10))),
    CONSTRAINT ta_triajes_presion_diastolica_check CHECK (((presion_diastolica >= 20) AND (presion_diastolica <= 180))),
    CONSTRAINT ta_triajes_presion_sistolica_check CHECK (((presion_sistolica >= 40) AND (presion_sistolica <= 280))),
    CONSTRAINT ta_triajes_prioridad_color_check CHECK (((prioridad_color)::text = ANY ((ARRAY['Rojo'::character varying, 'Naranja'::character varying, 'Amarillo'::character varying, 'Verde'::character varying])::text[]))),
    CONSTRAINT ta_triajes_saturacion_oxigeno_check CHECK (((saturacion_oxigeno >= 30) AND (saturacion_oxigeno <= 100))),
    CONSTRAINT ta_triajes_temperatura_check CHECK (((temperatura >= 34.0) AND (temperatura <= 43.0)))
);


--
-- TOC entry 288 (class 1259 OID 19581)
-- Name: ta_triajes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ta_triajes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5617 (class 0 OID 0)
-- Dependencies: 288
-- Name: ta_triajes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ta_triajes_id_seq OWNED BY public.ta_triajes.id;


--
-- TOC entry 310 (class 1259 OID 19855)
-- Name: tc_aseguradora; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tc_aseguradora (
    id_aseguradora integer NOT NULL,
    nombre character varying(80) NOT NULL,
    nit character varying(20) DEFAULT ''::character varying NOT NULL,
    telefono character varying(20) DEFAULT ''::character varying NOT NULL,
    direccion character varying(150) DEFAULT ''::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


--
-- TOC entry 314 (class 1259 OID 19921)
-- Name: tc_ficha; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tc_ficha (
    id_ficha integer NOT NULL,
    nro_ficha integer NOT NULL,
    id_persona integer NOT NULL,
    ci_paciente character varying(15) NOT NULL,
    tipo_paciente character varying(11) DEFAULT 'Particular'::character varying NOT NULL,
    id_asegurado character varying(15),
    id_medico integer NOT NULL,
    id_especialidad integer NOT NULL,
    id_horario integer NOT NULL,
    id_servicio integer,
    fech_cita date NOT NULL,
    hora_cita time without time zone NOT NULL,
    estado character varying(11) DEFAULT 'Registrada'::character varying NOT NULL,
    observacion character varying(200) DEFAULT ''::character varying NOT NULL,
    fech_reg timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    usuario_reg character varying(15) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT tc_ficha_estado_check CHECK (((estado)::text = ANY ((ARRAY['Registrada'::character varying, 'Confirmada'::character varying, 'Atendida'::character varying, 'No asistio'::character varying, 'Cancelada'::character varying])::text[]))),
    CONSTRAINT tc_ficha_tipo_paciente_check CHECK (((tipo_paciente)::text = ANY ((ARRAY['Asegurado'::character varying, 'Particular'::character varying])::text[])))
);


--
-- TOC entry 313 (class 1259 OID 19920)
-- Name: tc_ficha_id_ficha_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tc_ficha ALTER COLUMN id_ficha ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tc_ficha_id_ficha_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 312 (class 1259 OID 19893)
-- Name: tc_horario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tc_horario (
    id_horario integer NOT NULL,
    id_empleado integer NOT NULL,
    dia_semana smallint NOT NULL,
    id_turno integer NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    nro_fichas integer DEFAULT 5 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT tc_horario_dia_semana_check CHECK (((dia_semana >= 1) AND (dia_semana <= 7))),
    CONSTRAINT tc_horario_nro_fichas_check CHECK ((nro_fichas >= 0))
);


--
-- TOC entry 309 (class 1259 OID 19840)
-- Name: tc_servicios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tc_servicios (
    id_servicio integer NOT NULL,
    nombre_servicio character varying(60) NOT NULL,
    descripcion text DEFAULT ''::text NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


--
-- TOC entry 308 (class 1259 OID 19839)
-- Name: tc_servicios_id_servicio_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tc_servicios ALTER COLUMN id_servicio ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tc_servicios_id_servicio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 243 (class 1259 OID 19133)
-- Name: td_detalle_factura; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.td_detalle_factura (
    id_detalle integer NOT NULL,
    id_factura integer NOT NULL,
    id_servicio integer NOT NULL,
    cantidad integer DEFAULT 1 NOT NULL,
    precio_unitario numeric(10,2) NOT NULL,
    subtotal numeric(10,2) NOT NULL,
    CONSTRAINT chk_cantidades_detalle CHECK (((cantidad > 0) AND (precio_unitario >= (0)::numeric) AND (subtotal >= (0)::numeric)))
);


--
-- TOC entry 242 (class 1259 OID 19132)
-- Name: td_detalle_factura_id_detalle_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.td_detalle_factura ALTER COLUMN id_detalle ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.td_detalle_factura_id_detalle_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 239 (class 1259 OID 19095)
-- Name: td_factura; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.td_factura (
    id_factura integer NOT NULL,
    id_paciente integer NOT NULL,
    id_usuario integer NOT NULL,
    nro_factura character varying(50) NOT NULL,
    nit_cliente character varying(20) NOT NULL,
    razon_social character varying(150) NOT NULL,
    fecha_emision date DEFAULT CURRENT_TIMESTAMP,
    monto_total numeric(10,2) DEFAULT 0.00 NOT NULL,
    metodo_pago character varying(50) NOT NULL,
    CONSTRAINT chk_metodo_pago CHECK (((metodo_pago)::text = ANY ((ARRAY['EFECTIVO'::character varying, 'TARJETA'::character varying, 'TRANSFERENCIA'::character varying, 'SEGURO'::character varying])::text[]))),
    CONSTRAINT chk_monto_total CHECK ((monto_total >= (0)::numeric))
);


--
-- TOC entry 238 (class 1259 OID 19094)
-- Name: td_factura_id_factura_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.td_factura ALTER COLUMN id_factura ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.td_factura_id_factura_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 241 (class 1259 OID 19120)
-- Name: td_servicios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.td_servicios (
    id_servicio integer NOT NULL,
    codigo_servicio character varying(50) NOT NULL,
    nombre_servicio character varying(100) NOT NULL,
    descripcion character varying(255),
    tipo_servicio character varying(50),
    precio_base numeric(10,2) NOT NULL,
    CONSTRAINT chk_precio_base CHECK ((precio_base >= (0)::numeric))
);


--
-- TOC entry 240 (class 1259 OID 19119)
-- Name: td_servicios_id_servicio_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.td_servicios ALTER COLUMN id_servicio ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.td_servicios_id_servicio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 263 (class 1259 OID 19327)
-- Name: tf_categorias_producto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tf_categorias_producto (
    id_categoria integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(255),
    activo boolean DEFAULT true NOT NULL
);


--
-- TOC entry 5618 (class 0 OID 0)
-- Dependencies: 263
-- Name: TABLE tf_categorias_producto; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tf_categorias_producto IS 'Tabla propia - Clasificación de medicamentos e insumos.';


--
-- TOC entry 262 (class 1259 OID 19326)
-- Name: tf_categorias_producto_id_categoria_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tf_categorias_producto ALTER COLUMN id_categoria ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tf_categorias_producto_id_categoria_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 269 (class 1259 OID 19373)
-- Name: tf_compras; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tf_compras (
    id_compra integer NOT NULL,
    id_proveedor integer NOT NULL,
    id_usuario integer NOT NULL,
    numero_documento character varying(50),
    fecha_compra date NOT NULL,
    total numeric(12,2) DEFAULT 0 NOT NULL,
    estado character varying(20) DEFAULT 'REGISTRADA'::character varying NOT NULL
);


--
-- TOC entry 5619 (class 0 OID 0)
-- Dependencies: 269
-- Name: TABLE tf_compras; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tf_compras IS 'Tabla propia - Cabecera de compras o entradas.';


--
-- TOC entry 5620 (class 0 OID 0)
-- Dependencies: 269
-- Name: COLUMN tf_compras.estado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tf_compras.estado IS 'REGISTRADA o ANULADA';


--
-- TOC entry 268 (class 1259 OID 19372)
-- Name: tf_compras_id_compra_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tf_compras ALTER COLUMN id_compra ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tf_compras_id_compra_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 279 (class 1259 OID 19437)
-- Name: tf_consumos_internos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tf_consumos_internos (
    id_consumo integer NOT NULL,
    id_solicitud_insumo integer NOT NULL,
    id_usuario integer NOT NULL,
    fecha_consumo date NOT NULL,
    estado character varying(20) DEFAULT 'REGISTRADO'::character varying NOT NULL,
    observacion character varying(255)
);


--
-- TOC entry 5621 (class 0 OID 0)
-- Dependencies: 279
-- Name: TABLE tf_consumos_internos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tf_consumos_internos IS 'Tabla propia - Registra la entrega de medicamentos o insumos solicitados internamente.';


--
-- TOC entry 5622 (class 0 OID 0)
-- Dependencies: 279
-- Name: COLUMN tf_consumos_internos.estado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tf_consumos_internos.estado IS 'REGISTRADO o ANULADO';


--
-- TOC entry 278 (class 1259 OID 19436)
-- Name: tf_consumos_internos_id_consumo_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tf_consumos_internos ALTER COLUMN id_consumo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tf_consumos_internos_id_consumo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 271 (class 1259 OID 19387)
-- Name: tf_detalles_compra; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tf_detalles_compra (
    id_detalle_compra integer NOT NULL,
    id_compra integer NOT NULL,
    id_lote integer NOT NULL,
    cantidad numeric(12,2) NOT NULL,
    costo_unitario numeric(12,2) NOT NULL,
    subtotal numeric(12,2) NOT NULL
);


--
-- TOC entry 5623 (class 0 OID 0)
-- Dependencies: 271
-- Name: TABLE tf_detalles_compra; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tf_detalles_compra IS 'Tabla propia - Detalle de lotes recibidos en cada compra.';


--
-- TOC entry 270 (class 1259 OID 19386)
-- Name: tf_detalles_compra_id_detalle_compra_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tf_detalles_compra ALTER COLUMN id_detalle_compra ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tf_detalles_compra_id_detalle_compra_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 281 (class 1259 OID 19449)
-- Name: tf_detalles_consumo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tf_detalles_consumo (
    id_detalle_consumo integer NOT NULL,
    id_consumo integer NOT NULL,
    id_detalle_solicitud_consumo integer NOT NULL,
    id_lote integer NOT NULL,
    cantidad_entregada numeric(12,2) NOT NULL
);


--
-- TOC entry 5624 (class 0 OID 0)
-- Dependencies: 281
-- Name: TABLE tf_detalles_consumo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tf_detalles_consumo IS 'Tabla propia - Productos y lotes entregados en consumo interno.';


--
-- TOC entry 280 (class 1259 OID 19448)
-- Name: tf_detalles_consumo_id_detalle_consumo_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tf_detalles_consumo ALTER COLUMN id_detalle_consumo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tf_detalles_consumo_id_detalle_consumo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 277 (class 1259 OID 19425)
-- Name: tf_detalles_dispensacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tf_detalles_dispensacion (
    id_detalle_dispensacion integer NOT NULL,
    id_dispensacion integer NOT NULL,
    id_detalle_receta integer NOT NULL,
    id_detalle_comprobante integer NOT NULL,
    id_lote integer NOT NULL,
    cantidad_entregada numeric(12,2) NOT NULL
);


--
-- TOC entry 5625 (class 0 OID 0)
-- Dependencies: 277
-- Name: TABLE tf_detalles_dispensacion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tf_detalles_dispensacion IS 'Tabla propia - Registra medicamento, autorización, lote y cantidad entregada.';


--
-- TOC entry 276 (class 1259 OID 19424)
-- Name: tf_detalles_dispensacion_id_detalle_dispensacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tf_detalles_dispensacion ALTER COLUMN id_detalle_dispensacion ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tf_detalles_dispensacion_id_detalle_dispensacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 275 (class 1259 OID 19412)
-- Name: tf_dispensaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tf_dispensaciones (
    id_dispensacion integer NOT NULL,
    id_receta integer NOT NULL,
    id_factura integer NOT NULL,
    id_usuario integer NOT NULL,
    fecha_dispensacion date NOT NULL,
    estado character varying(20) DEFAULT 'ENTREGADA'::character varying NOT NULL,
    observacion character varying(255)
);


--
-- TOC entry 5626 (class 0 OID 0)
-- Dependencies: 275
-- Name: TABLE tf_dispensaciones; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tf_dispensaciones IS 'Tabla propia - Registra la dispensación de medicamentos prescritos y autorizados.';


--
-- TOC entry 5627 (class 0 OID 0)
-- Dependencies: 275
-- Name: COLUMN tf_dispensaciones.estado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tf_dispensaciones.estado IS 'ENTREGADA, PARCIAL o ANULADA';


--
-- TOC entry 274 (class 1259 OID 19411)
-- Name: tf_dispensaciones_id_dispensacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tf_dispensaciones ALTER COLUMN id_dispensacion ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tf_dispensaciones_id_dispensacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 273 (class 1259 OID 19399)
-- Name: tf_lotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tf_lotes (
    id_lote integer NOT NULL,
    id_producto integer NOT NULL,
    numero_lote character varying(50) NOT NULL,
    fecha_vencimiento date,
    stock_actual numeric(12,2) DEFAULT 0 NOT NULL,
    estado character varying(20) DEFAULT 'DISPONIBLE'::character varying NOT NULL
);


--
-- TOC entry 5628 (class 0 OID 0)
-- Dependencies: 273
-- Name: TABLE tf_lotes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tf_lotes IS 'Tabla propia - Control de lotes, vencimientos y stock.';


--
-- TOC entry 5629 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN tf_lotes.estado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tf_lotes.estado IS 'DISPONIBLE, AGOTADO o VENCIDO';


--
-- TOC entry 272 (class 1259 OID 19398)
-- Name: tf_lotes_id_lote_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tf_lotes ALTER COLUMN id_lote ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tf_lotes_id_lote_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 283 (class 1259 OID 19460)
-- Name: tf_movimientos_inventario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tf_movimientos_inventario (
    id_movimiento integer NOT NULL,
    id_lote integer NOT NULL,
    id_usuario integer NOT NULL,
    id_detalle_compra integer,
    id_detalle_dispensacion integer,
    id_detalle_consumo integer,
    tipo_movimiento character varying(20) NOT NULL,
    cantidad numeric(12,2) NOT NULL,
    fecha_movimiento date NOT NULL,
    motivo character varying(200)
);


--
-- TOC entry 5630 (class 0 OID 0)
-- Dependencies: 283
-- Name: TABLE tf_movimientos_inventario; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tf_movimientos_inventario IS 'Tabla propia - Kardex de entradas, salidas y ajustes.';


--
-- TOC entry 5631 (class 0 OID 0)
-- Dependencies: 283
-- Name: COLUMN tf_movimientos_inventario.tipo_movimiento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tf_movimientos_inventario.tipo_movimiento IS 'ENTRADA, SALIDA o AJUSTE';


--
-- TOC entry 282 (class 1259 OID 19459)
-- Name: tf_movimientos_inventario_id_movimiento_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tf_movimientos_inventario ALTER COLUMN id_movimiento ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tf_movimientos_inventario_id_movimiento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 265 (class 1259 OID 19339)
-- Name: tf_productos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tf_productos (
    id_producto integer NOT NULL,
    id_categoria integer NOT NULL,
    codigo character varying(30) NOT NULL,
    nombre character varying(150) NOT NULL,
    tipo_producto character varying(20) NOT NULL,
    principio_activo character varying(150),
    concentracion character varying(50),
    presentacion character varying(100),
    unidad_medida character varying(30) NOT NULL,
    stock_minimo numeric(12,2) DEFAULT 0 NOT NULL,
    requiere_receta boolean DEFAULT false NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


--
-- TOC entry 5632 (class 0 OID 0)
-- Dependencies: 265
-- Name: TABLE tf_productos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tf_productos IS 'Tabla propia - Catálogo general de medicamentos e insumos.';


--
-- TOC entry 5633 (class 0 OID 0)
-- Dependencies: 265
-- Name: COLUMN tf_productos.tipo_producto; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tf_productos.tipo_producto IS 'MEDICAMENTO o INSUMO';


--
-- TOC entry 264 (class 1259 OID 19338)
-- Name: tf_productos_id_producto_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tf_productos ALTER COLUMN id_producto ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tf_productos_id_producto_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 267 (class 1259 OID 19361)
-- Name: tf_proveedores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tf_proveedores (
    id_proveedor integer NOT NULL,
    razon_social character varying(150) NOT NULL,
    nit character varying(30),
    telefono character varying(30),
    correo character varying(100),
    direccion character varying(200),
    activo boolean DEFAULT true NOT NULL
);


--
-- TOC entry 5634 (class 0 OID 0)
-- Dependencies: 267
-- Name: TABLE tf_proveedores; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tf_proveedores IS 'Tabla propia - Proveedores de medicamentos e insumos.';


--
-- TOC entry 266 (class 1259 OID 19360)
-- Name: tf_proveedores_id_proveedor_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tf_proveedores ALTER COLUMN id_proveedor ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tf_proveedores_id_proveedor_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 261 (class 1259 OID 19295)
-- Name: ti_altas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ti_altas (
    id_alta bigint NOT NULL,
    id_internacion bigint NOT NULL,
    id_medico bigint NOT NULL,
    id_tipo_alta bigint NOT NULL,
    fecha_alta timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    observaciones_alta text
);


--
-- TOC entry 260 (class 1259 OID 19294)
-- Name: ti_altas_id_alta_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ti_altas_id_alta_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5635 (class 0 OID 0)
-- Dependencies: 260
-- Name: ti_altas_id_alta_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ti_altas_id_alta_seq OWNED BY public.ti_altas.id_alta;


--
-- TOC entry 257 (class 1259 OID 19256)
-- Name: ti_asignaciones_camas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ti_asignaciones_camas (
    id_asignacion bigint NOT NULL,
    id_internacion bigint NOT NULL,
    id_cama bigint NOT NULL,
    fecha_ingreso timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_salida timestamp without time zone,
    observaciones_asignacion text,
    CONSTRAINT chk_fechas_asignacion CHECK (((fecha_salida IS NULL) OR (fecha_salida >= fecha_ingreso)))
);


--
-- TOC entry 256 (class 1259 OID 19255)
-- Name: ti_asignaciones_camas_id_asignacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ti_asignaciones_camas_id_asignacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5636 (class 0 OID 0)
-- Dependencies: 256
-- Name: ti_asignaciones_camas_id_asignacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ti_asignaciones_camas_id_asignacion_seq OWNED BY public.ti_asignaciones_camas.id_asignacion;


--
-- TOC entry 253 (class 1259 OID 19209)
-- Name: ti_camas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ti_camas (
    id_cama bigint NOT NULL,
    id_habitacion bigint NOT NULL,
    estado_cama character varying(30) DEFAULT 'DISPONIBLEti_'::character varying NOT NULL,
    CONSTRAINT chk_estado_cama CHECK (((estado_cama)::text = ANY ((ARRAY['DISPONIBLE'::character varying, 'OCUPADA'::character varying, 'MANTENIMIENTO'::character varying, 'INHABILITADA'::character varying])::text[])))
);


--
-- TOC entry 252 (class 1259 OID 19208)
-- Name: ti_camas_id_cama_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ti_camas_id_cama_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5637 (class 0 OID 0)
-- Dependencies: 252
-- Name: ti_camas_id_cama_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ti_camas_id_cama_seq OWNED BY public.ti_camas.id_cama;


--
-- TOC entry 251 (class 1259 OID 19190)
-- Name: ti_habitaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ti_habitaciones (
    id_habitacion bigint NOT NULL,
    id_tipo_habitacion bigint NOT NULL,
    numero_habitacion character varying(20) NOT NULL,
    piso_habitacion integer NOT NULL,
    sector_habitacion character varying(100),
    CONSTRAINT chk_piso_habitacion CHECK ((piso_habitacion >= 0))
);


--
-- TOC entry 250 (class 1259 OID 19189)
-- Name: ti_habitaciones_id_habitacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ti_habitaciones_id_habitacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5638 (class 0 OID 0)
-- Dependencies: 250
-- Name: ti_habitaciones_id_habitacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ti_habitaciones_id_habitacion_seq OWNED BY public.ti_habitaciones.id_habitacion;


--
-- TOC entry 255 (class 1259 OID 19226)
-- Name: ti_internaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ti_internaciones (
    id_internacion bigint NOT NULL,
    id_medico bigint NOT NULL,
    id_paciente bigint NOT NULL,
    id_tipo_internacion bigint NOT NULL,
    fecha_internacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    observaciones_internacion text
);


--
-- TOC entry 254 (class 1259 OID 19225)
-- Name: ti_internaciones_id_internacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ti_internaciones_id_internacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5639 (class 0 OID 0)
-- Dependencies: 254
-- Name: ti_internaciones_id_internacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ti_internaciones_id_internacion_seq OWNED BY public.ti_internaciones.id_internacion;


--
-- TOC entry 259 (class 1259 OID 19281)
-- Name: ti_prescripciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ti_prescripciones (
    id_prescripcion bigint NOT NULL,
    id_internacion bigint NOT NULL
);


--
-- TOC entry 258 (class 1259 OID 19280)
-- Name: ti_prescripciones_id_prescripcion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ti_prescripciones_id_prescripcion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5640 (class 0 OID 0)
-- Dependencies: 258
-- Name: ti_prescripciones_id_prescripcion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ti_prescripciones_id_prescripcion_seq OWNED BY public.ti_prescripciones.id_prescripcion;


--
-- TOC entry 249 (class 1259 OID 19179)
-- Name: ti_tipos_altas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ti_tipos_altas (
    id_tipo_alta bigint NOT NULL,
    nombre_tipo_alta character varying(100) NOT NULL,
    descripcion_tipo_alta text
);


--
-- TOC entry 248 (class 1259 OID 19178)
-- Name: ti_tipos_altas_id_tipo_alta_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ti_tipos_altas_id_tipo_alta_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5641 (class 0 OID 0)
-- Dependencies: 248
-- Name: ti_tipos_altas_id_tipo_alta_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ti_tipos_altas_id_tipo_alta_seq OWNED BY public.ti_tipos_altas.id_tipo_alta;


--
-- TOC entry 245 (class 1259 OID 19157)
-- Name: ti_tipos_habitaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ti_tipos_habitaciones (
    id_tipo_habitacion bigint NOT NULL,
    nombre_tipo_habitacion character varying(100) NOT NULL,
    descripcion_tipo_habitacion text
);


--
-- TOC entry 244 (class 1259 OID 19156)
-- Name: ti_tipos_habitaciones_id_tipo_habitacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ti_tipos_habitaciones_id_tipo_habitacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5642 (class 0 OID 0)
-- Dependencies: 244
-- Name: ti_tipos_habitaciones_id_tipo_habitacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ti_tipos_habitaciones_id_tipo_habitacion_seq OWNED BY public.ti_tipos_habitaciones.id_tipo_habitacion;


--
-- TOC entry 247 (class 1259 OID 19168)
-- Name: ti_tipos_internaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ti_tipos_internaciones (
    id_tipo_internacion bigint NOT NULL,
    nombre_tipo_internacion character varying(100) NOT NULL,
    descripcion_tipo_internacion text
);


--
-- TOC entry 246 (class 1259 OID 19167)
-- Name: ti_tipos_internaciones_id_tipo_internacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ti_tipos_internaciones_id_tipo_internacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5643 (class 0 OID 0)
-- Dependencies: 246
-- Name: ti_tipos_internaciones_id_tipo_internacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ti_tipos_internaciones_id_tipo_internacion_seq OWNED BY public.ti_tipos_internaciones.id_tipo_internacion;


--
-- TOC entry 224 (class 1259 OID 18943)
-- Name: tp_areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tp_areas (
    id_area integer NOT NULL,
    nombre_area character varying(80) NOT NULL,
    descripcion text,
    activo boolean DEFAULT true
);


--
-- TOC entry 223 (class 1259 OID 18942)
-- Name: tp_areas_id_area_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tp_areas_id_area_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5644 (class 0 OID 0)
-- Dependencies: 223
-- Name: tp_areas_id_area_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tp_areas_id_area_seq OWNED BY public.tp_areas.id_area;


--
-- TOC entry 311 (class 1259 OID 19870)
-- Name: tp_asegurado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tp_asegurado (
    ci character varying(15) NOT NULL,
    id_aseguradora integer NOT NULL,
    nombre character varying(50) NOT NULL,
    paterno character varying(30) DEFAULT ''::character varying NOT NULL,
    materno character varying(30) DEFAULT ''::character varying NOT NULL,
    nro_poliza character varying(30) DEFAULT ''::character varying NOT NULL,
    fech_nac date,
    fech_afiliacion date DEFAULT CURRENT_DATE NOT NULL,
    estado boolean DEFAULT true NOT NULL
);


--
-- TOC entry 232 (class 1259 OID 19025)
-- Name: tp_empleado_especialidades; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tp_empleado_especialidades (
    id_relacion integer NOT NULL,
    id_empleado integer NOT NULL,
    id_especialidad integer NOT NULL,
    fecha_asignacion date DEFAULT now(),
    observaciones text
);


--
-- TOC entry 231 (class 1259 OID 19024)
-- Name: tp_empleado_especialidades_id_relacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tp_empleado_especialidades_id_relacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5645 (class 0 OID 0)
-- Dependencies: 231
-- Name: tp_empleado_especialidades_id_relacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tp_empleado_especialidades_id_relacion_seq OWNED BY public.tp_empleado_especialidades.id_relacion;


--
-- TOC entry 230 (class 1259 OID 18999)
-- Name: tp_empleados; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tp_empleados (
    id_empleado integer NOT NULL,
    id_persona integer NOT NULL,
    id_area integer,
    tipo_empleado character varying(20) NOT NULL,
    fecha_contratacion date NOT NULL,
    fecha_terminacion date,
    id_turno integer NOT NULL,
    sueldo_base numeric(10,2),
    activo boolean DEFAULT true,
    nmp character varying(20) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT tp_empleados_tipo_empleado_check CHECK (((tipo_empleado)::text = ANY ((ARRAY['Medico'::character varying, 'Enfermero'::character varying, 'Administrativo'::character varying, 'Auxiliar'::character varying, 'Otro'::character varying])::text[])))
);


--
-- TOC entry 229 (class 1259 OID 18998)
-- Name: tp_empleados_id_empleado_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tp_empleados_id_empleado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5646 (class 0 OID 0)
-- Dependencies: 229
-- Name: tp_empleados_id_empleado_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tp_empleados_id_empleado_seq OWNED BY public.tp_empleados.id_empleado;


--
-- TOC entry 222 (class 1259 OID 18927)
-- Name: tp_especialidades; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tp_especialidades (
    id_especialidad integer NOT NULL,
    nombre_especialidad character varying(80) NOT NULL,
    tipo character varying(20) NOT NULL,
    descripcion text,
    activo boolean DEFAULT true,
    CONSTRAINT tp_especialidades_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['Medica'::character varying, 'Enfermeria'::character varying, 'Apoyo'::character varying, 'Administrativa'::character varying])::text[])))
);


--
-- TOC entry 221 (class 1259 OID 18926)
-- Name: tp_especialidades_id_especialidad_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tp_especialidades_id_especialidad_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5647 (class 0 OID 0)
-- Dependencies: 221
-- Name: tp_especialidades_id_especialidad_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tp_especialidades_id_especialidad_seq OWNED BY public.tp_especialidades.id_especialidad;


--
-- TOC entry 228 (class 1259 OID 18977)
-- Name: tp_pacientes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tp_pacientes (
    id_paciente integer NOT NULL,
    id_persona integer NOT NULL,
    aseguradora_nombre character varying(100),
    aseguradora_codigo character varying(20),
    aseguradora_empresa character varying(100),
    numero_poliza character varying(50),
    tipo_afiliacion character varying(20) NOT NULL,
    contacto_emergencia_nombre character varying(100),
    contacto_emergencia_telefono character varying(20),
    alergias_conocidas text,
    observaciones text,
    fecha_registro timestamp without time zone DEFAULT now(),
    activo boolean DEFAULT true,
    CONSTRAINT tp_pacientes_tipo_afiliacion_check CHECK (((tipo_afiliacion)::text = ANY ((ARRAY['Particular'::character varying, 'Asegurado'::character varying])::text[])))
);


--
-- TOC entry 227 (class 1259 OID 18976)
-- Name: tp_pacientes_id_paciente_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tp_pacientes_id_paciente_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5648 (class 0 OID 0)
-- Dependencies: 227
-- Name: tp_pacientes_id_paciente_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tp_pacientes_id_paciente_seq OWNED BY public.tp_pacientes.id_paciente;


--
-- TOC entry 226 (class 1259 OID 18957)
-- Name: tp_personas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tp_personas (
    id_persona integer NOT NULL,
    ci character varying(20) NOT NULL,
    nombres character varying(100) NOT NULL,
    apellidos character varying(100) NOT NULL,
    fecha_nacimiento date NOT NULL,
    genero character(1) NOT NULL,
    telefono character varying(20),
    email character varying(100),
    direccion text,
    foto_url character varying(255),
    fecha_creacion timestamp without time zone DEFAULT now(),
    activo boolean DEFAULT true,
    CONSTRAINT tp_personas_genero_check CHECK ((genero = ANY (ARRAY['M'::bpchar, 'F'::bpchar, 'O'::bpchar])))
);


--
-- TOC entry 225 (class 1259 OID 18956)
-- Name: tp_personas_id_persona_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tp_personas_id_persona_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5649 (class 0 OID 0)
-- Dependencies: 225
-- Name: tp_personas_id_persona_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tp_personas_id_persona_seq OWNED BY public.tp_personas.id_persona;


--
-- TOC entry 220 (class 1259 OID 18913)
-- Name: tp_turnos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tp_turnos (
    id_turno integer NOT NULL,
    nombre_turno character varying(30) NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    activo boolean DEFAULT true
);


--
-- TOC entry 219 (class 1259 OID 18912)
-- Name: tp_turnos_id_turno_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tp_turnos_id_turno_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5650 (class 0 OID 0)
-- Dependencies: 219
-- Name: tp_turnos_id_turno_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tp_turnos_id_turno_seq OWNED BY public.tp_turnos.id_turno;


--
-- TOC entry 234 (class 1259 OID 19050)
-- Name: ts_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ts_roles (
    id_rol integer NOT NULL,
    nombre_rol character varying(50) NOT NULL,
    descripcion character varying(255),
    estado_rol boolean DEFAULT true
);


--
-- TOC entry 233 (class 1259 OID 19049)
-- Name: ts_roles_id_rol_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.ts_roles ALTER COLUMN id_rol ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.ts_roles_id_rol_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 237 (class 1259 OID 19076)
-- Name: ts_roles_usuarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ts_roles_usuarios (
    id_usuario integer NOT NULL,
    id_rol integer NOT NULL,
    fecha_asignacion date DEFAULT CURRENT_TIMESTAMP
);


--
-- TOC entry 236 (class 1259 OID 19061)
-- Name: ts_usuarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ts_usuarios (
    id_usuario integer NOT NULL,
    id_personal integer NOT NULL,
    username character varying(50) NOT NULL,
    password_hash character varying(255) NOT NULL,
    estado_cuenta character varying(20) DEFAULT 'ACTIVO'::character varying,
    CONSTRAINT chk_estado_cuenta CHECK (((estado_cuenta)::text = ANY ((ARRAY['ACTIVO'::character varying, 'INACTIVO'::character varying, 'BLOQUEADO'::character varying])::text[])))
);


--
-- TOC entry 235 (class 1259 OID 19060)
-- Name: ts_usuarios_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.ts_usuarios ALTER COLUMN id_usuario ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.ts_usuarios_id_usuario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 315 (class 1259 OID 20033)
-- Name: v_fichas_dia; Type: VIEW; Schema: public; Owner: -
--

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


--
-- TOC entry 5170 (class 2604 OID 19563)
-- Name: ta_atenciones_medicas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_atenciones_medicas ALTER COLUMN id SET DEFAULT nextval('public.ta_atenciones_medicas_id_seq'::regclass);


--
-- TOC entry 5188 (class 2604 OID 19769)
-- Name: ta_cierres_atenciones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_cierres_atenciones ALTER COLUMN id SET DEFAULT nextval('public.ta_cierres_atenciones_id_seq'::regclass);


--
-- TOC entry 5190 (class 2604 OID 19792)
-- Name: ta_cola_mensajes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_cola_mensajes ALTER COLUMN id SET DEFAULT nextval('public.ta_cola_mensajes_id_seq'::regclass);


--
-- TOC entry 5186 (class 2604 OID 19746)
-- Name: ta_derivaciones_externas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_derivaciones_externas ALTER COLUMN id SET DEFAULT nextval('public.ta_derivaciones_externas_id_seq'::regclass);


--
-- TOC entry 5175 (class 2604 OID 19622)
-- Name: ta_historias_clinicas_soap id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_historias_clinicas_soap ALTER COLUMN id SET DEFAULT nextval('public.ta_historias_clinicas_soap_id_seq'::regclass);


--
-- TOC entry 5180 (class 2604 OID 19668)
-- Name: ta_ordenes_examenes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_ordenes_examenes ALTER COLUMN id SET DEFAULT nextval('public.ta_ordenes_examenes_id_seq'::regclass);


--
-- TOC entry 5167 (class 2604 OID 19544)
-- Name: ta_pacientes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_pacientes ALTER COLUMN id SET DEFAULT nextval('public.ta_pacientes_id_seq'::regclass);


--
-- TOC entry 5178 (class 2604 OID 19646)
-- Name: ta_prescripciones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_prescripciones ALTER COLUMN id SET DEFAULT nextval('public.ta_prescripciones_id_seq'::regclass);


--
-- TOC entry 5184 (class 2604 OID 19712)
-- Name: ta_procedimiento_insumos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_procedimiento_insumos ALTER COLUMN id SET DEFAULT nextval('public.ta_procedimiento_insumos_id_seq'::regclass);


--
-- TOC entry 5185 (class 2604 OID 19730)
-- Name: ta_procedimiento_personal id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_procedimiento_personal ALTER COLUMN id SET DEFAULT nextval('public.ta_procedimiento_personal_id_seq'::regclass);


--
-- TOC entry 5183 (class 2604 OID 19690)
-- Name: ta_procedimientos_quirurgicos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_procedimientos_quirurgicos ALTER COLUMN id SET DEFAULT nextval('public.ta_procedimientos_quirurgicos_id_seq'::regclass);


--
-- TOC entry 5173 (class 2604 OID 19585)
-- Name: ta_triajes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_triajes ALTER COLUMN id SET DEFAULT nextval('public.ta_triajes_id_seq'::regclass);


--
-- TOC entry 5154 (class 2604 OID 19298)
-- Name: ti_altas id_alta; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_altas ALTER COLUMN id_alta SET DEFAULT nextval('public.ti_altas_id_alta_seq'::regclass);


--
-- TOC entry 5151 (class 2604 OID 19259)
-- Name: ti_asignaciones_camas id_asignacion; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_asignaciones_camas ALTER COLUMN id_asignacion SET DEFAULT nextval('public.ti_asignaciones_camas_id_asignacion_seq'::regclass);


--
-- TOC entry 5147 (class 2604 OID 19212)
-- Name: ti_camas id_cama; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_camas ALTER COLUMN id_cama SET DEFAULT nextval('public.ti_camas_id_cama_seq'::regclass);


--
-- TOC entry 5146 (class 2604 OID 19193)
-- Name: ti_habitaciones id_habitacion; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_habitaciones ALTER COLUMN id_habitacion SET DEFAULT nextval('public.ti_habitaciones_id_habitacion_seq'::regclass);


--
-- TOC entry 5149 (class 2604 OID 19229)
-- Name: ti_internaciones id_internacion; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_internaciones ALTER COLUMN id_internacion SET DEFAULT nextval('public.ti_internaciones_id_internacion_seq'::regclass);


--
-- TOC entry 5153 (class 2604 OID 19284)
-- Name: ti_prescripciones id_prescripcion; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_prescripciones ALTER COLUMN id_prescripcion SET DEFAULT nextval('public.ti_prescripciones_id_prescripcion_seq'::regclass);


--
-- TOC entry 5145 (class 2604 OID 19182)
-- Name: ti_tipos_altas id_tipo_alta; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_tipos_altas ALTER COLUMN id_tipo_alta SET DEFAULT nextval('public.ti_tipos_altas_id_tipo_alta_seq'::regclass);


--
-- TOC entry 5143 (class 2604 OID 19160)
-- Name: ti_tipos_habitaciones id_tipo_habitacion; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_tipos_habitaciones ALTER COLUMN id_tipo_habitacion SET DEFAULT nextval('public.ti_tipos_habitaciones_id_tipo_habitacion_seq'::regclass);


--
-- TOC entry 5144 (class 2604 OID 19171)
-- Name: ti_tipos_internaciones id_tipo_internacion; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_tipos_internaciones ALTER COLUMN id_tipo_internacion SET DEFAULT nextval('public.ti_tipos_internaciones_id_tipo_internacion_seq'::regclass);


--
-- TOC entry 5124 (class 2604 OID 18946)
-- Name: tp_areas id_area; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_areas ALTER COLUMN id_area SET DEFAULT nextval('public.tp_areas_id_area_seq'::regclass);


--
-- TOC entry 5135 (class 2604 OID 19028)
-- Name: tp_empleado_especialidades id_relacion; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_empleado_especialidades ALTER COLUMN id_relacion SET DEFAULT nextval('public.tp_empleado_especialidades_id_relacion_seq'::regclass);


--
-- TOC entry 5132 (class 2604 OID 19002)
-- Name: tp_empleados id_empleado; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_empleados ALTER COLUMN id_empleado SET DEFAULT nextval('public.tp_empleados_id_empleado_seq'::regclass);


--
-- TOC entry 5122 (class 2604 OID 18930)
-- Name: tp_especialidades id_especialidad; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_especialidades ALTER COLUMN id_especialidad SET DEFAULT nextval('public.tp_especialidades_id_especialidad_seq'::regclass);


--
-- TOC entry 5129 (class 2604 OID 18980)
-- Name: tp_pacientes id_paciente; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_pacientes ALTER COLUMN id_paciente SET DEFAULT nextval('public.tp_pacientes_id_paciente_seq'::regclass);


--
-- TOC entry 5126 (class 2604 OID 18960)
-- Name: tp_personas id_persona; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_personas ALTER COLUMN id_persona SET DEFAULT nextval('public.tp_personas_id_persona_seq'::regclass);


--
-- TOC entry 5120 (class 2604 OID 18916)
-- Name: tp_turnos id_turno; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_turnos ALTER COLUMN id_turno SET DEFAULT nextval('public.tp_turnos_id_turno_seq'::regclass);


--
-- TOC entry 5355 (class 2606 OID 19575)
-- Name: ta_atenciones_medicas ta_atenciones_medicas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_atenciones_medicas
    ADD CONSTRAINT ta_atenciones_medicas_pkey PRIMARY KEY (id);


--
-- TOC entry 5377 (class 2606 OID 19782)
-- Name: ta_cierres_atenciones ta_cierres_atenciones_atencion_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_cierres_atenciones
    ADD CONSTRAINT ta_cierres_atenciones_atencion_id_key UNIQUE (atencion_id);


--
-- TOC entry 5379 (class 2606 OID 19780)
-- Name: ta_cierres_atenciones ta_cierres_atenciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_cierres_atenciones
    ADD CONSTRAINT ta_cierres_atenciones_pkey PRIMARY KEY (id);


--
-- TOC entry 5381 (class 2606 OID 19807)
-- Name: ta_cola_mensajes ta_cola_mensajes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_cola_mensajes
    ADD CONSTRAINT ta_cola_mensajes_pkey PRIMARY KEY (id);


--
-- TOC entry 5373 (class 2606 OID 19759)
-- Name: ta_derivaciones_externas ta_derivaciones_externas_formulario_301_nro_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_derivaciones_externas
    ADD CONSTRAINT ta_derivaciones_externas_formulario_301_nro_key UNIQUE (formulario_301_nro);


--
-- TOC entry 5375 (class 2606 OID 19757)
-- Name: ta_derivaciones_externas ta_derivaciones_externas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_derivaciones_externas
    ADD CONSTRAINT ta_derivaciones_externas_pkey PRIMARY KEY (id);


--
-- TOC entry 5361 (class 2606 OID 19636)
-- Name: ta_historias_clinicas_soap ta_historias_clinicas_soap_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_historias_clinicas_soap
    ADD CONSTRAINT ta_historias_clinicas_soap_pkey PRIMARY KEY (id);


--
-- TOC entry 5365 (class 2606 OID 19680)
-- Name: ta_ordenes_examenes ta_ordenes_examenes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_ordenes_examenes
    ADD CONSTRAINT ta_ordenes_examenes_pkey PRIMARY KEY (id);


--
-- TOC entry 5351 (class 2606 OID 19558)
-- Name: ta_pacientes ta_pacientes_ci_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_pacientes
    ADD CONSTRAINT ta_pacientes_ci_key UNIQUE (ci);


--
-- TOC entry 5353 (class 2606 OID 19556)
-- Name: ta_pacientes ta_pacientes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_pacientes
    ADD CONSTRAINT ta_pacientes_pkey PRIMARY KEY (id);


--
-- TOC entry 5363 (class 2606 OID 19658)
-- Name: ta_prescripciones ta_prescripciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_prescripciones
    ADD CONSTRAINT ta_prescripciones_pkey PRIMARY KEY (id);


--
-- TOC entry 5369 (class 2606 OID 19720)
-- Name: ta_procedimiento_insumos ta_procedimiento_insumos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_procedimiento_insumos
    ADD CONSTRAINT ta_procedimiento_insumos_pkey PRIMARY KEY (id);


--
-- TOC entry 5371 (class 2606 OID 19736)
-- Name: ta_procedimiento_personal ta_procedimiento_personal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_procedimiento_personal
    ADD CONSTRAINT ta_procedimiento_personal_pkey PRIMARY KEY (id);


--
-- TOC entry 5367 (class 2606 OID 19702)
-- Name: ta_procedimientos_quirurgicos ta_procedimientos_quirurgicos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_procedimientos_quirurgicos
    ADD CONSTRAINT ta_procedimientos_quirurgicos_pkey PRIMARY KEY (id);


--
-- TOC entry 5357 (class 2606 OID 19612)
-- Name: ta_triajes ta_triajes_atencion_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_triajes
    ADD CONSTRAINT ta_triajes_atencion_id_key UNIQUE (atencion_id);


--
-- TOC entry 5359 (class 2606 OID 19610)
-- Name: ta_triajes ta_triajes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_triajes
    ADD CONSTRAINT ta_triajes_pkey PRIMARY KEY (id);


--
-- TOC entry 5387 (class 2606 OID 19869)
-- Name: tc_aseguradora tc_aseguradora_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tc_aseguradora
    ADD CONSTRAINT tc_aseguradora_pkey PRIMARY KEY (id_aseguradora);


--
-- TOC entry 5396 (class 2606 OID 19946)
-- Name: tc_ficha tc_ficha_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tc_ficha
    ADD CONSTRAINT tc_ficha_pkey PRIMARY KEY (id_ficha);


--
-- TOC entry 5392 (class 2606 OID 19909)
-- Name: tc_horario tc_horario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tc_horario
    ADD CONSTRAINT tc_horario_pkey PRIMARY KEY (id_horario);


--
-- TOC entry 5383 (class 2606 OID 19854)
-- Name: tc_servicios tc_servicios_nombre_servicio_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tc_servicios
    ADD CONSTRAINT tc_servicios_nombre_servicio_key UNIQUE (nombre_servicio);


--
-- TOC entry 5385 (class 2606 OID 19852)
-- Name: tc_servicios tc_servicios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tc_servicios
    ADD CONSTRAINT tc_servicios_pkey PRIMARY KEY (id_servicio);


--
-- TOC entry 5297 (class 2606 OID 19145)
-- Name: td_detalle_factura td_detalle_factura_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.td_detalle_factura
    ADD CONSTRAINT td_detalle_factura_pkey PRIMARY KEY (id_detalle);


--
-- TOC entry 5289 (class 2606 OID 19113)
-- Name: td_factura td_factura_nro_factura_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.td_factura
    ADD CONSTRAINT td_factura_nro_factura_key UNIQUE (nro_factura);


--
-- TOC entry 5291 (class 2606 OID 19111)
-- Name: td_factura td_factura_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.td_factura
    ADD CONSTRAINT td_factura_pkey PRIMARY KEY (id_factura);


--
-- TOC entry 5293 (class 2606 OID 19131)
-- Name: td_servicios td_servicios_codigo_servicio_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.td_servicios
    ADD CONSTRAINT td_servicios_codigo_servicio_key UNIQUE (codigo_servicio);


--
-- TOC entry 5295 (class 2606 OID 19129)
-- Name: td_servicios td_servicios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.td_servicios
    ADD CONSTRAINT td_servicios_pkey PRIMARY KEY (id_servicio);


--
-- TOC entry 5321 (class 2606 OID 19337)
-- Name: tf_categorias_producto tf_categorias_producto_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_categorias_producto
    ADD CONSTRAINT tf_categorias_producto_nombre_key UNIQUE (nombre);


--
-- TOC entry 5323 (class 2606 OID 19335)
-- Name: tf_categorias_producto tf_categorias_producto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_categorias_producto
    ADD CONSTRAINT tf_categorias_producto_pkey PRIMARY KEY (id_categoria);


--
-- TOC entry 5331 (class 2606 OID 19385)
-- Name: tf_compras tf_compras_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_compras
    ADD CONSTRAINT tf_compras_pkey PRIMARY KEY (id_compra);


--
-- TOC entry 5343 (class 2606 OID 19447)
-- Name: tf_consumos_internos tf_consumos_internos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_consumos_internos
    ADD CONSTRAINT tf_consumos_internos_pkey PRIMARY KEY (id_consumo);


--
-- TOC entry 5333 (class 2606 OID 19397)
-- Name: tf_detalles_compra tf_detalles_compra_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_detalles_compra
    ADD CONSTRAINT tf_detalles_compra_pkey PRIMARY KEY (id_detalle_compra);


--
-- TOC entry 5345 (class 2606 OID 19458)
-- Name: tf_detalles_consumo tf_detalles_consumo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_detalles_consumo
    ADD CONSTRAINT tf_detalles_consumo_pkey PRIMARY KEY (id_detalle_consumo);


--
-- TOC entry 5341 (class 2606 OID 19435)
-- Name: tf_detalles_dispensacion tf_detalles_dispensacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_detalles_dispensacion
    ADD CONSTRAINT tf_detalles_dispensacion_pkey PRIMARY KEY (id_detalle_dispensacion);


--
-- TOC entry 5339 (class 2606 OID 19423)
-- Name: tf_dispensaciones tf_dispensaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_dispensaciones
    ADD CONSTRAINT tf_dispensaciones_pkey PRIMARY KEY (id_dispensacion);


--
-- TOC entry 5337 (class 2606 OID 19410)
-- Name: tf_lotes tf_lotes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_lotes
    ADD CONSTRAINT tf_lotes_pkey PRIMARY KEY (id_lote);


--
-- TOC entry 5349 (class 2606 OID 19470)
-- Name: tf_movimientos_inventario tf_movimientos_inventario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_movimientos_inventario
    ADD CONSTRAINT tf_movimientos_inventario_pkey PRIMARY KEY (id_movimiento);


--
-- TOC entry 5325 (class 2606 OID 19359)
-- Name: tf_productos tf_productos_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_productos
    ADD CONSTRAINT tf_productos_codigo_key UNIQUE (codigo);


--
-- TOC entry 5327 (class 2606 OID 19357)
-- Name: tf_productos tf_productos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_productos
    ADD CONSTRAINT tf_productos_pkey PRIMARY KEY (id_producto);


--
-- TOC entry 5329 (class 2606 OID 19371)
-- Name: tf_proveedores tf_proveedores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_proveedores
    ADD CONSTRAINT tf_proveedores_pkey PRIMARY KEY (id_proveedor);


--
-- TOC entry 5317 (class 2606 OID 19308)
-- Name: ti_altas ti_altas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_altas
    ADD CONSTRAINT ti_altas_pkey PRIMARY KEY (id_alta);


--
-- TOC entry 5313 (class 2606 OID 19269)
-- Name: ti_asignaciones_camas ti_asignaciones_camas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_asignaciones_camas
    ADD CONSTRAINT ti_asignaciones_camas_pkey PRIMARY KEY (id_asignacion);


--
-- TOC entry 5309 (class 2606 OID 19219)
-- Name: ti_camas ti_camas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_camas
    ADD CONSTRAINT ti_camas_pkey PRIMARY KEY (id_cama);


--
-- TOC entry 5305 (class 2606 OID 19200)
-- Name: ti_habitaciones ti_habitaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_habitaciones
    ADD CONSTRAINT ti_habitaciones_pkey PRIMARY KEY (id_habitacion);


--
-- TOC entry 5311 (class 2606 OID 19239)
-- Name: ti_internaciones ti_internaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_internaciones
    ADD CONSTRAINT ti_internaciones_pkey PRIMARY KEY (id_internacion);


--
-- TOC entry 5315 (class 2606 OID 19288)
-- Name: ti_prescripciones ti_prescripciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_prescripciones
    ADD CONSTRAINT ti_prescripciones_pkey PRIMARY KEY (id_prescripcion);


--
-- TOC entry 5303 (class 2606 OID 19188)
-- Name: ti_tipos_altas ti_tipos_altas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_tipos_altas
    ADD CONSTRAINT ti_tipos_altas_pkey PRIMARY KEY (id_tipo_alta);


--
-- TOC entry 5299 (class 2606 OID 19166)
-- Name: ti_tipos_habitaciones ti_tipos_habitaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_tipos_habitaciones
    ADD CONSTRAINT ti_tipos_habitaciones_pkey PRIMARY KEY (id_tipo_habitacion);


--
-- TOC entry 5301 (class 2606 OID 19177)
-- Name: ti_tipos_internaciones ti_tipos_internaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_tipos_internaciones
    ADD CONSTRAINT ti_tipos_internaciones_pkey PRIMARY KEY (id_tipo_internacion);


--
-- TOC entry 5257 (class 2606 OID 18955)
-- Name: tp_areas tp_areas_nombre_area_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_areas
    ADD CONSTRAINT tp_areas_nombre_area_key UNIQUE (nombre_area);


--
-- TOC entry 5259 (class 2606 OID 18953)
-- Name: tp_areas tp_areas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_areas
    ADD CONSTRAINT tp_areas_pkey PRIMARY KEY (id_area);


--
-- TOC entry 5389 (class 2606 OID 19887)
-- Name: tp_asegurado tp_asegurado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_asegurado
    ADD CONSTRAINT tp_asegurado_pkey PRIMARY KEY (ci);


--
-- TOC entry 5273 (class 2606 OID 19038)
-- Name: tp_empleado_especialidades tp_empleado_especialidades_id_empleado_id_especialidad_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_empleado_especialidades
    ADD CONSTRAINT tp_empleado_especialidades_id_empleado_id_especialidad_key UNIQUE (id_empleado, id_especialidad);


--
-- TOC entry 5275 (class 2606 OID 19036)
-- Name: tp_empleado_especialidades tp_empleado_especialidades_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_empleado_especialidades
    ADD CONSTRAINT tp_empleado_especialidades_pkey PRIMARY KEY (id_relacion);


--
-- TOC entry 5269 (class 2606 OID 19013)
-- Name: tp_empleados tp_empleados_id_persona_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_empleados
    ADD CONSTRAINT tp_empleados_id_persona_key UNIQUE (id_persona);


--
-- TOC entry 5271 (class 2606 OID 19011)
-- Name: tp_empleados tp_empleados_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_empleados
    ADD CONSTRAINT tp_empleados_pkey PRIMARY KEY (id_empleado);


--
-- TOC entry 5253 (class 2606 OID 18941)
-- Name: tp_especialidades tp_especialidades_nombre_especialidad_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_especialidades
    ADD CONSTRAINT tp_especialidades_nombre_especialidad_key UNIQUE (nombre_especialidad);


--
-- TOC entry 5255 (class 2606 OID 18939)
-- Name: tp_especialidades tp_especialidades_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_especialidades
    ADD CONSTRAINT tp_especialidades_pkey PRIMARY KEY (id_especialidad);


--
-- TOC entry 5265 (class 2606 OID 18992)
-- Name: tp_pacientes tp_pacientes_id_persona_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_pacientes
    ADD CONSTRAINT tp_pacientes_id_persona_key UNIQUE (id_persona);


--
-- TOC entry 5267 (class 2606 OID 18990)
-- Name: tp_pacientes tp_pacientes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_pacientes
    ADD CONSTRAINT tp_pacientes_pkey PRIMARY KEY (id_paciente);


--
-- TOC entry 5261 (class 2606 OID 18975)
-- Name: tp_personas tp_personas_ci_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_personas
    ADD CONSTRAINT tp_personas_ci_key UNIQUE (ci);


--
-- TOC entry 5263 (class 2606 OID 18973)
-- Name: tp_personas tp_personas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_personas
    ADD CONSTRAINT tp_personas_pkey PRIMARY KEY (id_persona);


--
-- TOC entry 5249 (class 2606 OID 18925)
-- Name: tp_turnos tp_turnos_nombre_turno_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_turnos
    ADD CONSTRAINT tp_turnos_nombre_turno_key UNIQUE (nombre_turno);


--
-- TOC entry 5251 (class 2606 OID 18923)
-- Name: tp_turnos tp_turnos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_turnos
    ADD CONSTRAINT tp_turnos_pkey PRIMARY KEY (id_turno);


--
-- TOC entry 5277 (class 2606 OID 19059)
-- Name: ts_roles ts_roles_nombre_rol_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ts_roles
    ADD CONSTRAINT ts_roles_nombre_rol_key UNIQUE (nombre_rol);


--
-- TOC entry 5279 (class 2606 OID 19057)
-- Name: ts_roles ts_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ts_roles
    ADD CONSTRAINT ts_roles_pkey PRIMARY KEY (id_rol);


--
-- TOC entry 5287 (class 2606 OID 19083)
-- Name: ts_roles_usuarios ts_roles_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ts_roles_usuarios
    ADD CONSTRAINT ts_roles_usuarios_pkey PRIMARY KEY (id_usuario, id_rol);


--
-- TOC entry 5281 (class 2606 OID 19073)
-- Name: ts_usuarios ts_usuarios_id_personal_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ts_usuarios
    ADD CONSTRAINT ts_usuarios_id_personal_key UNIQUE (id_personal);


--
-- TOC entry 5283 (class 2606 OID 19071)
-- Name: ts_usuarios ts_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ts_usuarios
    ADD CONSTRAINT ts_usuarios_pkey PRIMARY KEY (id_usuario);


--
-- TOC entry 5285 (class 2606 OID 19075)
-- Name: ts_usuarios ts_usuarios_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ts_usuarios
    ADD CONSTRAINT ts_usuarios_username_key UNIQUE (username);


--
-- TOC entry 5319 (class 2606 OID 19310)
-- Name: ti_altas uq_alta_internacion; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_altas
    ADD CONSTRAINT uq_alta_internacion UNIQUE (id_internacion);


--
-- TOC entry 5307 (class 2606 OID 19202)
-- Name: ti_habitaciones uq_numero_habitacion; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_habitaciones
    ADD CONSTRAINT uq_numero_habitacion UNIQUE (numero_habitacion);


--
-- TOC entry 5393 (class 1259 OID 19973)
-- Name: idx_ficha_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ficha_fecha ON public.tc_ficha USING btree (fech_cita);


--
-- TOC entry 5394 (class 1259 OID 19974)
-- Name: idx_ficha_horario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ficha_horario ON public.tc_ficha USING btree (id_horario, fech_cita);


--
-- TOC entry 5390 (class 1259 OID 19972)
-- Name: idx_horario_id_empleado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_horario_id_empleado ON public.tc_horario USING btree (id_empleado);


--
-- TOC entry 5334 (class 1259 OID 19472)
-- Name: tf_lotes_fecha_vencimiento_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tf_lotes_fecha_vencimiento_idx ON public.tf_lotes USING btree (fecha_vencimiento);


--
-- TOC entry 5335 (class 1259 OID 19471)
-- Name: tf_lotes_id_producto_numero_lote_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tf_lotes_id_producto_numero_lote_idx ON public.tf_lotes USING btree (id_producto, numero_lote);


--
-- TOC entry 5346 (class 1259 OID 19473)
-- Name: tf_movimientos_inventario_fecha_movimiento_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tf_movimientos_inventario_fecha_movimiento_idx ON public.tf_movimientos_inventario USING btree (fecha_movimiento);


--
-- TOC entry 5347 (class 1259 OID 19474)
-- Name: tf_movimientos_inventario_id_lote_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tf_movimientos_inventario_id_lote_idx ON public.tf_movimientos_inventario USING btree (id_lote);


--
-- TOC entry 5449 (class 2620 OID 19809)
-- Name: ta_historias_clinicas_soap tga_bloquear_soap_finalizado; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tga_bloquear_soap_finalizado BEFORE DELETE OR UPDATE ON public.ta_historias_clinicas_soap FOR EACH ROW EXECUTE FUNCTION public.fn_bloquear_soap_finalizado();


--
-- TOC entry 5452 (class 2620 OID 19982)
-- Name: tc_ficha trg_ficha_solo_medico; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ficha_solo_medico BEFORE INSERT OR UPDATE OF id_medico ON public.tc_ficha FOR EACH ROW EXECUTE FUNCTION public.f_valida_empleado_medico();


--
-- TOC entry 5450 (class 2620 OID 19981)
-- Name: tc_horario trg_horario_solo_medico; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_horario_solo_medico BEFORE INSERT OR UPDATE OF id_empleado ON public.tc_horario FOR EACH ROW EXECUTE FUNCTION public.f_valida_empleado_medico();


--
-- TOC entry 5451 (class 2620 OID 19980)
-- Name: tc_horario trg_valida_horario; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_valida_horario BEFORE INSERT OR UPDATE OF hora_inicio, hora_fin, id_turno ON public.tc_horario FOR EACH ROW EXECUTE FUNCTION public.trg_valida_horario();


--
-- TOC entry 5415 (class 2606 OID 19316)
-- Name: ti_altas fk_alta_doctor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_altas
    ADD CONSTRAINT fk_alta_doctor FOREIGN KEY (id_medico) REFERENCES public.tp_personas(id_persona);


--
-- TOC entry 5416 (class 2606 OID 19311)
-- Name: ti_altas fk_alta_internacion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_altas
    ADD CONSTRAINT fk_alta_internacion FOREIGN KEY (id_internacion) REFERENCES public.ti_internaciones(id_internacion);


--
-- TOC entry 5417 (class 2606 OID 19321)
-- Name: ti_altas fk_alta_tipo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_altas
    ADD CONSTRAINT fk_alta_tipo FOREIGN KEY (id_tipo_alta) REFERENCES public.ti_tipos_altas(id_tipo_alta);


--
-- TOC entry 5412 (class 2606 OID 19275)
-- Name: ti_asignaciones_camas fk_asignacion_cama; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_asignaciones_camas
    ADD CONSTRAINT fk_asignacion_cama FOREIGN KEY (id_cama) REFERENCES public.ti_camas(id_cama);


--
-- TOC entry 5413 (class 2606 OID 19270)
-- Name: ti_asignaciones_camas fk_asignacion_internacion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_asignaciones_camas
    ADD CONSTRAINT fk_asignacion_internacion FOREIGN KEY (id_internacion) REFERENCES public.ti_internaciones(id_internacion);


--
-- TOC entry 5408 (class 2606 OID 19220)
-- Name: ti_camas fk_cama_habitacion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_camas
    ADD CONSTRAINT fk_cama_habitacion FOREIGN KEY (id_habitacion) REFERENCES public.ti_habitaciones(id_habitacion);


--
-- TOC entry 5407 (class 2606 OID 19203)
-- Name: ti_habitaciones fk_habitacion_tipo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_habitaciones
    ADD CONSTRAINT fk_habitacion_tipo FOREIGN KEY (id_tipo_habitacion) REFERENCES public.ti_tipos_habitaciones(id_tipo_habitacion);


--
-- TOC entry 5409 (class 2606 OID 19240)
-- Name: ti_internaciones fk_internacion_doctor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_internaciones
    ADD CONSTRAINT fk_internacion_doctor FOREIGN KEY (id_medico) REFERENCES public.tp_personas(id_persona);


--
-- TOC entry 5410 (class 2606 OID 19245)
-- Name: ti_internaciones fk_internacion_paciente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_internaciones
    ADD CONSTRAINT fk_internacion_paciente FOREIGN KEY (id_paciente) REFERENCES public.tp_personas(id_persona);


--
-- TOC entry 5411 (class 2606 OID 19250)
-- Name: ti_internaciones fk_internacion_tipo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_internaciones
    ADD CONSTRAINT fk_internacion_tipo FOREIGN KEY (id_tipo_internacion) REFERENCES public.ti_tipos_internaciones(id_tipo_internacion);


--
-- TOC entry 5414 (class 2606 OID 19289)
-- Name: ti_prescripciones fk_prescripcion_internacion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ti_prescripciones
    ADD CONSTRAINT fk_prescripcion_internacion FOREIGN KEY (id_internacion) REFERENCES public.ti_internaciones(id_internacion);


--
-- TOC entry 5431 (class 2606 OID 19576)
-- Name: ta_atenciones_medicas ta_atenciones_medicas_paciente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_atenciones_medicas
    ADD CONSTRAINT ta_atenciones_medicas_paciente_id_fkey FOREIGN KEY (paciente_id) REFERENCES public.ta_pacientes(id) ON DELETE RESTRICT;


--
-- TOC entry 5440 (class 2606 OID 19783)
-- Name: ta_cierres_atenciones ta_cierres_atenciones_atencion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_cierres_atenciones
    ADD CONSTRAINT ta_cierres_atenciones_atencion_id_fkey FOREIGN KEY (atencion_id) REFERENCES public.ta_atenciones_medicas(id) ON DELETE RESTRICT;


--
-- TOC entry 5439 (class 2606 OID 19760)
-- Name: ta_derivaciones_externas ta_derivaciones_externas_atencion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_derivaciones_externas
    ADD CONSTRAINT ta_derivaciones_externas_atencion_id_fkey FOREIGN KEY (atencion_id) REFERENCES public.ta_atenciones_medicas(id) ON DELETE RESTRICT;


--
-- TOC entry 5433 (class 2606 OID 19637)
-- Name: ta_historias_clinicas_soap ta_historias_clinicas_soap_atencion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_historias_clinicas_soap
    ADD CONSTRAINT ta_historias_clinicas_soap_atencion_id_fkey FOREIGN KEY (atencion_id) REFERENCES public.ta_atenciones_medicas(id) ON DELETE RESTRICT;


--
-- TOC entry 5435 (class 2606 OID 19681)
-- Name: ta_ordenes_examenes ta_ordenes_examenes_historia_soap_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_ordenes_examenes
    ADD CONSTRAINT ta_ordenes_examenes_historia_soap_id_fkey FOREIGN KEY (historia_soap_id) REFERENCES public.ta_historias_clinicas_soap(id) ON DELETE CASCADE;


--
-- TOC entry 5434 (class 2606 OID 19659)
-- Name: ta_prescripciones ta_prescripciones_historia_soap_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_prescripciones
    ADD CONSTRAINT ta_prescripciones_historia_soap_id_fkey FOREIGN KEY (historia_soap_id) REFERENCES public.ta_historias_clinicas_soap(id) ON DELETE CASCADE;


--
-- TOC entry 5437 (class 2606 OID 19721)
-- Name: ta_procedimiento_insumos ta_procedimiento_insumos_procedimiento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_procedimiento_insumos
    ADD CONSTRAINT ta_procedimiento_insumos_procedimiento_id_fkey FOREIGN KEY (procedimiento_id) REFERENCES public.ta_procedimientos_quirurgicos(id) ON DELETE CASCADE;


--
-- TOC entry 5438 (class 2606 OID 19737)
-- Name: ta_procedimiento_personal ta_procedimiento_personal_procedimiento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_procedimiento_personal
    ADD CONSTRAINT ta_procedimiento_personal_procedimiento_id_fkey FOREIGN KEY (procedimiento_id) REFERENCES public.ta_procedimientos_quirurgicos(id) ON DELETE CASCADE;


--
-- TOC entry 5436 (class 2606 OID 19703)
-- Name: ta_procedimientos_quirurgicos ta_procedimientos_quirurgicos_atencion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_procedimientos_quirurgicos
    ADD CONSTRAINT ta_procedimientos_quirurgicos_atencion_id_fkey FOREIGN KEY (atencion_id) REFERENCES public.ta_atenciones_medicas(id) ON DELETE RESTRICT;


--
-- TOC entry 5432 (class 2606 OID 19613)
-- Name: ta_triajes ta_triajes_atencion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ta_triajes
    ADD CONSTRAINT ta_triajes_atencion_id_fkey FOREIGN KEY (atencion_id) REFERENCES public.ta_atenciones_medicas(id) ON DELETE CASCADE;


--
-- TOC entry 5444 (class 2606 OID 19947)
-- Name: tc_ficha tc_ficha_id_asegurado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tc_ficha
    ADD CONSTRAINT tc_ficha_id_asegurado_fkey FOREIGN KEY (id_asegurado) REFERENCES public.tp_asegurado(ci);


--
-- TOC entry 5445 (class 2606 OID 19957)
-- Name: tc_ficha tc_ficha_id_especialidad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tc_ficha
    ADD CONSTRAINT tc_ficha_id_especialidad_fkey FOREIGN KEY (id_especialidad) REFERENCES public.tp_especialidades(id_especialidad);


--
-- TOC entry 5446 (class 2606 OID 19962)
-- Name: tc_ficha tc_ficha_id_horario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tc_ficha
    ADD CONSTRAINT tc_ficha_id_horario_fkey FOREIGN KEY (id_horario) REFERENCES public.tc_horario(id_horario);


--
-- TOC entry 5447 (class 2606 OID 19952)
-- Name: tc_ficha tc_ficha_id_medico_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tc_ficha
    ADD CONSTRAINT tc_ficha_id_medico_fkey FOREIGN KEY (id_medico) REFERENCES public.tp_empleados(id_empleado);


--
-- TOC entry 5448 (class 2606 OID 19967)
-- Name: tc_ficha tc_ficha_id_servicio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tc_ficha
    ADD CONSTRAINT tc_ficha_id_servicio_fkey FOREIGN KEY (id_servicio) REFERENCES public.tc_servicios(id_servicio);


--
-- TOC entry 5442 (class 2606 OID 19910)
-- Name: tc_horario tc_horario_id_empleado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tc_horario
    ADD CONSTRAINT tc_horario_id_empleado_fkey FOREIGN KEY (id_empleado) REFERENCES public.tp_empleados(id_empleado);


--
-- TOC entry 5443 (class 2606 OID 19915)
-- Name: tc_horario tc_horario_id_turno_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tc_horario
    ADD CONSTRAINT tc_horario_id_turno_fkey FOREIGN KEY (id_turno) REFERENCES public.tp_turnos(id_turno);


--
-- TOC entry 5405 (class 2606 OID 19146)
-- Name: td_detalle_factura td_detalle_factura_id_factura_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.td_detalle_factura
    ADD CONSTRAINT td_detalle_factura_id_factura_fkey FOREIGN KEY (id_factura) REFERENCES public.td_factura(id_factura) ON DELETE CASCADE;


--
-- TOC entry 5406 (class 2606 OID 19151)
-- Name: td_detalle_factura td_detalle_factura_id_servicio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.td_detalle_factura
    ADD CONSTRAINT td_detalle_factura_id_servicio_fkey FOREIGN KEY (id_servicio) REFERENCES public.td_servicios(id_servicio);


--
-- TOC entry 5404 (class 2606 OID 19114)
-- Name: td_factura td_factura_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.td_factura
    ADD CONSTRAINT td_factura_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.ts_usuarios(id_usuario);


--
-- TOC entry 5419 (class 2606 OID 19480)
-- Name: tf_compras tf_compras_id_proveedor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_compras
    ADD CONSTRAINT tf_compras_id_proveedor_fkey FOREIGN KEY (id_proveedor) REFERENCES public.tf_proveedores(id_proveedor) DEFERRABLE;


--
-- TOC entry 5420 (class 2606 OID 19485)
-- Name: tf_detalles_compra tf_detalles_compra_id_compra_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_detalles_compra
    ADD CONSTRAINT tf_detalles_compra_id_compra_fkey FOREIGN KEY (id_compra) REFERENCES public.tf_compras(id_compra) DEFERRABLE;


--
-- TOC entry 5421 (class 2606 OID 19490)
-- Name: tf_detalles_compra tf_detalles_compra_id_lote_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_detalles_compra
    ADD CONSTRAINT tf_detalles_compra_id_lote_fkey FOREIGN KEY (id_lote) REFERENCES public.tf_lotes(id_lote) DEFERRABLE;


--
-- TOC entry 5425 (class 2606 OID 19510)
-- Name: tf_detalles_consumo tf_detalles_consumo_id_consumo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_detalles_consumo
    ADD CONSTRAINT tf_detalles_consumo_id_consumo_fkey FOREIGN KEY (id_consumo) REFERENCES public.tf_consumos_internos(id_consumo) DEFERRABLE;


--
-- TOC entry 5426 (class 2606 OID 19515)
-- Name: tf_detalles_consumo tf_detalles_consumo_id_lote_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_detalles_consumo
    ADD CONSTRAINT tf_detalles_consumo_id_lote_fkey FOREIGN KEY (id_lote) REFERENCES public.tf_lotes(id_lote) DEFERRABLE;


--
-- TOC entry 5423 (class 2606 OID 19500)
-- Name: tf_detalles_dispensacion tf_detalles_dispensacion_id_dispensacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_detalles_dispensacion
    ADD CONSTRAINT tf_detalles_dispensacion_id_dispensacion_fkey FOREIGN KEY (id_dispensacion) REFERENCES public.tf_dispensaciones(id_dispensacion) DEFERRABLE;


--
-- TOC entry 5424 (class 2606 OID 19505)
-- Name: tf_detalles_dispensacion tf_detalles_dispensacion_id_lote_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_detalles_dispensacion
    ADD CONSTRAINT tf_detalles_dispensacion_id_lote_fkey FOREIGN KEY (id_lote) REFERENCES public.tf_lotes(id_lote) DEFERRABLE;


--
-- TOC entry 5422 (class 2606 OID 19495)
-- Name: tf_lotes tf_lotes_id_producto_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_lotes
    ADD CONSTRAINT tf_lotes_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.tf_productos(id_producto) DEFERRABLE;


--
-- TOC entry 5427 (class 2606 OID 19525)
-- Name: tf_movimientos_inventario tf_movimientos_inventario_id_detalle_compra_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_movimientos_inventario
    ADD CONSTRAINT tf_movimientos_inventario_id_detalle_compra_fkey FOREIGN KEY (id_detalle_compra) REFERENCES public.tf_detalles_compra(id_detalle_compra) DEFERRABLE;


--
-- TOC entry 5428 (class 2606 OID 19535)
-- Name: tf_movimientos_inventario tf_movimientos_inventario_id_detalle_consumo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_movimientos_inventario
    ADD CONSTRAINT tf_movimientos_inventario_id_detalle_consumo_fkey FOREIGN KEY (id_detalle_consumo) REFERENCES public.tf_detalles_consumo(id_detalle_consumo) DEFERRABLE;


--
-- TOC entry 5429 (class 2606 OID 19530)
-- Name: tf_movimientos_inventario tf_movimientos_inventario_id_detalle_dispensacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_movimientos_inventario
    ADD CONSTRAINT tf_movimientos_inventario_id_detalle_dispensacion_fkey FOREIGN KEY (id_detalle_dispensacion) REFERENCES public.tf_detalles_dispensacion(id_detalle_dispensacion) DEFERRABLE;


--
-- TOC entry 5430 (class 2606 OID 19520)
-- Name: tf_movimientos_inventario tf_movimientos_inventario_id_lote_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_movimientos_inventario
    ADD CONSTRAINT tf_movimientos_inventario_id_lote_fkey FOREIGN KEY (id_lote) REFERENCES public.tf_lotes(id_lote) DEFERRABLE;


--
-- TOC entry 5418 (class 2606 OID 19475)
-- Name: tf_productos tf_productos_id_categoria_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tf_productos
    ADD CONSTRAINT tf_productos_id_categoria_fkey FOREIGN KEY (id_categoria) REFERENCES public.tf_categorias_producto(id_categoria) DEFERRABLE;


--
-- TOC entry 5441 (class 2606 OID 19888)
-- Name: tp_asegurado tp_asegurado_id_aseguradora_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_asegurado
    ADD CONSTRAINT tp_asegurado_id_aseguradora_fkey FOREIGN KEY (id_aseguradora) REFERENCES public.tc_aseguradora(id_aseguradora);


--
-- TOC entry 5400 (class 2606 OID 19039)
-- Name: tp_empleado_especialidades tp_empleado_especialidades_id_empleado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_empleado_especialidades
    ADD CONSTRAINT tp_empleado_especialidades_id_empleado_fkey FOREIGN KEY (id_empleado) REFERENCES public.tp_empleados(id_empleado);


--
-- TOC entry 5401 (class 2606 OID 19044)
-- Name: tp_empleado_especialidades tp_empleado_especialidades_id_especialidad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_empleado_especialidades
    ADD CONSTRAINT tp_empleado_especialidades_id_especialidad_fkey FOREIGN KEY (id_especialidad) REFERENCES public.tp_especialidades(id_especialidad);


--
-- TOC entry 5398 (class 2606 OID 19019)
-- Name: tp_empleados tp_empleados_id_area_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_empleados
    ADD CONSTRAINT tp_empleados_id_area_fkey FOREIGN KEY (id_area) REFERENCES public.tp_areas(id_area);


--
-- TOC entry 5399 (class 2606 OID 19014)
-- Name: tp_empleados tp_empleados_id_persona_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_empleados
    ADD CONSTRAINT tp_empleados_id_persona_fkey FOREIGN KEY (id_persona) REFERENCES public.tp_personas(id_persona);


--
-- TOC entry 5397 (class 2606 OID 18993)
-- Name: tp_pacientes tp_pacientes_id_persona_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tp_pacientes
    ADD CONSTRAINT tp_pacientes_id_persona_fkey FOREIGN KEY (id_persona) REFERENCES public.tp_personas(id_persona);


--
-- TOC entry 5402 (class 2606 OID 19089)
-- Name: ts_roles_usuarios ts_roles_usuarios_id_rol_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ts_roles_usuarios
    ADD CONSTRAINT ts_roles_usuarios_id_rol_fkey FOREIGN KEY (id_rol) REFERENCES public.ts_roles(id_rol) ON DELETE CASCADE;


--
-- TOC entry 5403 (class 2606 OID 19084)
-- Name: ts_roles_usuarios ts_roles_usuarios_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ts_roles_usuarios
    ADD CONSTRAINT ts_roles_usuarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.ts_usuarios(id_usuario) ON DELETE CASCADE;


-- Completed on 2026-08-27 22:05:46

--
-- PostgreSQL database dump complete
--

\unrestrict oqHw9ziBveJFAAkwJqnMBkBpffnFh0kzxrg84ERqhvi7Kod3IbiLJWdDnjifv1w

