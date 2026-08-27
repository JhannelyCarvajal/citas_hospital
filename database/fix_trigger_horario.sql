CREATE OR REPLACE FUNCTION public.trg_valida_horario()
RETURNS trigger LANGUAGE plpgsql AS $function$
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
$function$;
