-- =====================================================================
-- DATOS INICIALES: Hospital_Prototipo_Citas
-- =====================================================================

-- Turnos laborales
INSERT INTO tturno (id_turno, descripcion, hora_inicio, hora_fin, cruza_medianoche) VALUES
(1, 'Manana',  '08:00', '12:00', false),
(2, 'Tarde',   '14:00', '18:00', false),
(3, 'Noche',   '19:00', '07:00', true);

-- Areas organizacionales
INSERT INTO tareas (nombre_area, descripcion) VALUES
('Consulta Externa', 'Atencion ambulatoria a pacientes'),
('Emergencia', 'Atencion de emergencias 24h'),
('Laboratorio', 'Analisis clinicos y diagnostico'),
('Imagenologia', 'Estudios por imagen (rayos X, ecografia)'),
('Admin Hospitalaria', 'Gestion administrativa del hospital');

-- Servicios hospitalarios
INSERT INTO tservicios (nombre_servicio, descripcion) VALUES
('Consulta General', 'Consulta medica general'),
('Consulta Especializada', 'Consulta con especialista'),
('Control Prenatal', 'Seguimiento de embarazo'),
('Examen de Laboratorio', 'Toma y procesamiento de muestras'),
('Radiografia', 'Estudio de imagen por rayos X'),
('Ecografia', 'Estudio de imagen por ultrasonido');

-- Especialidades medicas
INSERT INTO tespecialidad (id_especialidad, nombre_especialidad, tipo, descripcion) VALUES
(1, 'Medicina General',     'medica',         'Atencion primaria de salud'),
(2, 'Cardiologia',          'medica',         'Enfermedades del corazon'),
(3, 'Pediatria',            'medica',         'Atencion de ninos y adolescentes'),
(4, 'Ginecologia',          'medica',         'Salud de la mujer'),
(5, 'Traumatologia',        'medica',         'Huesos, articulaciones y musculos'),
(6, 'Enfermeria General',   'enfermeria',     'Cuidados de enfermeria'),
(7, 'Laboratorio Clinico',  'apoyo',          'Analisis clinicos'),
(8, 'Rayos X',              'apoyo',          'Imagenologia diagnostica');

-- Aseguradoras
INSERT INTO taseguradora (id_aseguradora, nombre, nit, telefono, direccion) VALUES
(1, 'SEGUROS UNIVERSAL',     '1023456789', '8001234', 'Av. Principal 1234'),
(2, 'ASEGURADORA DEL ESTADO','1098765432', '8005678', 'C. Comercio 567'),
(3, 'LA VITALICIA',          '1056789012', '8009012', 'Blvd. del Sur 890');

-- Personas (medicos, administrativos, pacientes de ejemplo)
INSERT INTO tpersonas (ci, nombre, apellidos, fecha_nacimiento, genero, telefono, email) VALUES
-- Medicos
('1234567',  'Carlos',   'Mendoza Lopez',    '1980-05-15', 'M', '70123456', 'cmendoza@hospital.com'),
('2345678',  'Maria',    'Garcia Fernandez',  '1985-08-22', 'F', '70234567', 'mgarcia@hospital.com'),
('3456789',  'Roberto',  'Sanchez Perez',     '1978-03-10', 'M', '70345678', 'rsanchez@hospital.com'),
('4567890',  'Ana',      'Torres Vargas',     '1990-11-28', 'F', '70456789', 'atorres@hospital.com'),
('5678901',  'Luis',     'Rivera Morales',    '1982-07-03', 'M', '70567890', 'lrivera@hospital.com'),
-- Pacientes
('9001234',  'Pedro',    'Lopez Garcia',      '1995-02-14', 'M', '79012345', 'plopez@gmail.com'),
('9002345',  'Laura',    'Martinez Rojas',    '1988-06-20', 'F', '79023456', 'lmartinez@gmail.com'),
('9003456',  'Jorge',    'Hernandez Cruz',    '1975-12-01', 'M', '79034567', 'jhernandez@gmail.com'),
('9004567',  'Sofia',    'Diaz Flores',       '2000-09-15', 'F', '79045678', 'sdiaz@gmail.com'),
('9005678',  'Miguel',   'Castro Aguilar',    '1968-04-25', 'M', '79056789', 'mcastro@gmail.com');

-- Empleados (medicos)
INSERT INTO templeados (id_persona, id_area, tipo_empleado, fecha_contratacion, id_turno, nmp) VALUES
(1, 1, 'medico', '2015-03-01', 1, 'NMP-1001'),
(2, 1, 'medico', '2018-07-15', 1, 'NMP-1002'),
(3, 1, 'medico', '2012-01-10', 2, 'NMP-1003'),
(4, 1, 'medico', '2020-02-20', 2, 'NMP-1004'),
(5, 2, 'medico', '2016-09-05', 3, 'NMP-1005');

-- Especialidades por medico
INSERT INTO templeado_especialidades (id_empleado, id_especialidad) VALUES
(1, 1),  -- Carlos -> Medicina General
(2, 2),  -- Maria -> Cardiologia
(3, 3),  -- Roberto -> Pediatria
(4, 4),  -- Ana -> Ginecologia
(5, 5),  -- Luis -> Traumatologia
(1, 6);  -- Carlos -> Enfermeria General (doble especialidad)

-- Horarios de atencion (lunes a viernes)
-- Carlos (medico 1): Lunes a Viernes Manana
INSERT INTO thorario (id_horario, id_empleado, dia_semana, id_turno, hora_inicio, hora_fin, nro_fichas) VALUES
(1, 1, 1, 1, '08:00', '12:00', 10),  -- Carlos Lunes Manana
(2, 1, 2, 1, '08:00', '12:00', 10),  -- Carlos Martes Manana
(3, 1, 3, 1, '08:00', '12:00', 10),  -- Carlos Miercoles Manana
(4, 1, 4, 1, '08:00', '12:00', 10),  -- Carlos Jueves Manana
(5, 1, 5, 1, '08:00', '12:00', 10);  -- Carlos Viernes Manana

-- Maria (medico 2): Lunes y Miercoles Manana
INSERT INTO thorario (id_horario, id_empleado, dia_semana, id_turno, hora_inicio, hora_fin, nro_fichas) VALUES
(6, 2, 1, 1, '08:00', '12:00', 8),   -- Maria Lunes Manana
(7, 2, 3, 1, '08:00', '12:00', 8);   -- Maria Miercoles Manana

-- Roberto (medico 3): Martes y Jueves Tarde
INSERT INTO thorario (id_horario, id_empleado, dia_semana, id_turno, hora_inicio, hora_fin, nro_fichas) VALUES
(8, 3, 2, 2, '14:00', '18:00', 12),  -- Roberto Martes Tarde
(9, 3, 4, 2, '14:00', '18:00', 12);  -- Roberto Jueves Tarde

-- Ana (medico 4): Lunes, Miercoles y Viernes Tarde
INSERT INTO thorario (id_horario, id_empleado, dia_semana, id_turno, hora_inicio, hora_fin, nro_fichas) VALUES
(10, 4, 1, 2, '14:00', '18:00', 8),  -- Ana Lunes Tarde
(11, 4, 3, 2, '14:00', '18:00', 8),  -- Ana Miercoles Tarde
(12, 4, 5, 2, '14:00', '18:00', 8);  -- Ana Viernes Tarde

-- Luis (medico 5): Lunes a Viernes Noche (emergencia)
INSERT INTO thorario (id_horario, id_empleado, dia_semana, id_turno, hora_inicio, hora_fin, nro_fichas) VALUES
(13, 5, 1, 3, '19:00', '07:00', 15), -- Luis Lunes Noche
(14, 5, 2, 3, '19:00', '07:00', 15), -- Luis Martes Noche
(15, 5, 3, 3, '19:00', '07:00', 15), -- Luis Miercoles Noche
(16, 5, 4, 3, '19:00', '07:00', 15), -- Luis Jueves Noche
(17, 5, 5, 3, '19:00', '07:00', 15); -- Luis Viernes Noche