CREATE OR REPLACE FUNCTION public.f_valida_empleado_medico()
RETURNS trigger LANGUAGE plpgsql AS $$
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
