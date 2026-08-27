-- Seed data for real table names

-- Turnos
INSERT INTO tp_turnos (id_turno, nombre_turno, hora_inicio, hora_fin) VALUES
(1, 'Manana',  '08:00', '12:00'),
(2, 'Tarde',   '14:00', '18:00'),
(3, 'Noche',   '19:00', '07:00');

-- Areas
INSERT INTO tp_areas (nombre_area, descripcion) VALUES
('Consulta Externa', 'Atencion ambulatoria a pacientes'),
('Emergencia', 'Atencion de emergencias 24h'),
('Laboratorio', 'Analisis clinicos y diagnostico'),
('Imagenologia', 'Estudios por imagen (rayos X, ecografia)'),
('Admin Hospitalaria', 'Gestion administrativa del hospital');

-- Servicios
INSERT INTO tc_servicios (nombre_servicio, descripcion) VALUES
('Consulta General', 'Consulta medica general'),
('Consulta Especializada', 'Consulta con especialista'),
('Control Prenatal', 'Seguimiento de embarazo'),
('Examen de Laboratorio', 'Toma y procesamiento de muestras'),
('Radiografia', 'Estudio de imagen por rayos X'),
('Ecografia', 'Estudio de imagen por ultrasonido');

-- Especialidades
INSERT INTO tp_especialidades (id_especialidad, nombre_especialidad, tipo, descripcion) VALUES
(1, 'Medicina General',     'Medica',         'Atencion primaria de salud'),
(2, 'Cardiologia',          'Medica',         'Enfermedades del corazon'),
(3, 'Pediatria',            'Medica',         'Atencion de ninos y adolescentes'),
(4, 'Ginecologia',          'Medica',         'Salud de la mujer'),
(5, 'Traumatologia',        'Medica',         'Huesos, articulaciones y musculos'),
(6, 'Enfermeria General',   'Enfermeria',     'Cuidados de enfermeria'),
(7, 'Laboratorio Clinico',  'Apoyo',          'Analisis clinicos'),
(8, 'Rayos X',              'Apoyo',          'Imagenologia diagnostica');

-- Personas (medicos y pacientes)
INSERT INTO tp_personas (ci, nombres, apellidos, fecha_nacimiento, genero, telefono, email) VALUES
('1234567',  'Carlos',   'Mendoza Lopez',    '1980-05-15', 'M', '70123456', 'cmendoza@hospital.com'),
('2345678',  'Maria',    'Garcia Fernandez',  '1985-08-22', 'F', '70234567', 'mgarcia@hospital.com'),
('3456789',  'Roberto',  'Sanchez Perez',     '1978-03-10', 'M', '70345678', 'rsanchez@hospital.com'),
('4567890',  'Ana',      'Torres Vargas',     '1990-11-28', 'F', '70456789', 'atorres@hospital.com'),
('5678901',  'Luis',     'Rivera Morales',    '1982-07-03', 'M', '70567890', 'lrivera@hospital.com'),
('9001234',  'Pedro',    'Lopez Garcia',      '1995-02-14', 'M', '79012345', 'plopez@gmail.com'),
('9002345',  'Laura',    'Martinez Rojas',    '1988-06-20', 'F', '79023456', 'lmartinez@gmail.com'),
('9003456',  'Jorge',    'Hernandez Cruz',    '1975-12-01', 'M', '79034567', 'jhernandez@gmail.com'),
('9004567',  'Sofia',    'Diaz Flores',       '2000-09-15', 'F', '79045678', 'sdiaz@gmail.com'),
('9005678',  'Miguel',   'Castro Aguilar',    '1968-04-25', 'M', '79056789', 'mcastro@gmail.com');

-- Empleados (medicos)
INSERT INTO tp_empleados (id_persona, id_area, tipo_empleado, fecha_contratacion, id_turno, sueldo_base, nmp) VALUES
(1, 1, 'Medico', '2015-03-01', 1, 5000, 'NMP-1001'),
(2, 1, 'Medico', '2018-07-15', 1, 5000, 'NMP-1002'),
(3, 1, 'Medico', '2012-01-10', 2, 5000, 'NMP-1003'),
(4, 1, 'Medico', '2020-02-20', 2, 5000, 'NMP-1004'),
(5, 2, 'Medico', '2016-09-05', 3, 5000, 'NMP-1005');

-- Especialidades por medico
INSERT INTO tp_empleado_especialidades (id_empleado, id_especialidad) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 4),
(5, 5),
(1, 6);

-- Horarios de atencion (lunes a viernes)
INSERT INTO tc_horario (id_horario, id_empleado, dia_semana, id_turno, hora_inicio, hora_fin, nro_fichas) VALUES
(1, 1, 1, 1, '08:00', '12:00', 10),
(2, 1, 2, 1, '08:00', '12:00', 10),
(3, 1, 3, 1, '08:00', '12:00', 10),
(4, 1, 4, 1, '08:00', '12:00', 10),
(5, 1, 5, 1, '08:00', '12:00', 10),
(6, 2, 1, 1, '08:00', '12:00', 8),
(7, 2, 3, 1, '08:00', '12:00', 8),
(8, 3, 2, 2, '14:00', '18:00', 12),
(9, 3, 4, 2, '14:00', '18:00', 12),
(10, 4, 1, 2, '14:00', '18:00', 8),
(11, 4, 3, 2, '14:00', '18:00', 8),
(12, 4, 5, 2, '14:00', '18:00', 8),
(13, 5, 1, 3, '19:00', '07:00', 15),
(14, 5, 2, 3, '19:00', '07:00', 15),
(15, 5, 3, 3, '19:00', '07:00', 15),
(16, 5, 4, 3, '19:00', '07:00', 15),
(17, 5, 5, 3, '19:00', '07:00', 15);
