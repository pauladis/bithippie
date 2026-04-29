-- Laboratory Experiment Tracking System
-- Seed data for PostgreSQL 15
--
-- This data exercises:
-- - projects with multiple researchers
-- - project-specific and experiment-specific researcher roles
-- - versioned experiments
-- - experiment graph relationships
-- - sample reuse across experiments
-- - sample lineage / splitting
-- - storage condition history
-- - measurement definitions and allowed categorical values
-- - numeric, categorical, and text measurements
-- - measurement provenance and correction/versioning

BEGIN;

-- =========================
-- RESEARCHERS
-- =========================

INSERT INTO researchers (id, name, email, phone, lab_role, contact_details) VALUES
  (1, 'Dr. Maya Patel', 'maya.patel@example-lab.org', '+1-555-0101', 'principal_investigator', '{"office":"B-214","preferred_contact":"email"}'::jsonb),
  (2, 'Dr. Lucas Chen', 'lucas.chen@example-lab.org', '+1-555-0102', 'senior_researcher', '{"office":"B-218","preferred_contact":"email"}'::jsonb),
  (3, 'Ana Rodriguez', 'ana.rodriguez@example-lab.org', '+1-555-0103', 'lab_technician', '{"bench":"Wet Lab 3","preferred_contact":"phone"}'::jsonb),
  (4, 'Priya Nair', 'priya.nair@example-lab.org', '+1-555-0104', 'graduate_student', '{"program":"Molecular Biology","preferred_contact":"email"}'::jsonb),
  (5, 'Noah Williams', 'noah.williams@example-lab.org', '+1-555-0105', 'data_scientist', '{"team":"Bioinformatics","preferred_contact":"email"}'::jsonb);

-- =========================
-- PROJECTS
-- =========================

INSERT INTO projects (id, title, description, status) VALUES
  (1, 'Glucose Response Biomarker Study', 'Investigates biomarker behavior under different glucose exposure conditions.', 'active'),
  (2, 'Soil Microbiome Recovery Study', 'Tracks microbial recovery in soil samples after controlled remediation.', 'planning');

INSERT INTO researchers_projects (researcher_id, project_id, role) VALUES
  (1, 1, 'principal_investigator'),
  (2, 1, 'co_investigator'),
  (3, 1, 'lab_technician'),
  (4, 1, 'graduate_researcher'),
  (5, 1, 'data_analyst'),
  (1, 2, 'advisor'),
  (2, 2, 'principal_investigator'),
  (5, 2, 'data_analyst');

-- =========================
-- EXPERIMENTS
-- =========================
-- Experiment 1 is intentionally versioned to demonstrate non-destructive updates.

INSERT INTO experiments (
  id,
  version,
  is_current,
  project_id,
  title,
  hypothesis,
  start_date,
  end_date,
  status,
  approved_by_researcher_id,
  approved_at,
  completed_by_researcher_id,
  completed_at
) VALUES
  (
    1,
    1,
    FALSE,
    1,
    'Baseline glucose assay',
    'Baseline glucose concentration is stable across prepared aliquots.',
    '2026-03-01 09:00:00+00',
    '2026-03-01 16:00:00+00',
    'completed',
    1,
    '2026-02-28 14:00:00+00',
    3,
    '2026-03-01 16:30:00+00'
  ),
  (
    1,
    2,
    TRUE,
    1,
    'Baseline glucose assay',
    'Baseline glucose concentration remains stable across prepared aliquots after protocol clarification.',
    '2026-03-01 09:00:00+00',
    '2026-03-01 16:00:00+00',
    'completed',
    1,
    '2026-02-28 14:00:00+00',
    3,
    '2026-03-01 16:30:00+00'
  ),
  (
    2,
    1,
    TRUE,
    1,
    'Replicate glucose assay',
    'A replicated assay should produce glucose measurements within expected tolerance.',
    '2026-03-03 09:00:00+00',
    '2026-03-03 17:00:00+00',
    'completed',
    1,
    '2026-03-02 11:00:00+00',
    3,
    '2026-03-03 17:20:00+00'
  ),
  (
    3,
    1,
    TRUE,
    1,
    'Temperature stress assay',
    'Elevated storage temperature changes sample viability outcome.',
    '2026-03-05 08:30:00+00',
    NULL,
    'active',
    1,
    '2026-03-04 10:00:00+00',
    NULL,
    NULL
  ),
  (
    4,
    1,
    TRUE,
    2,
    'Soil baseline microbial observation',
    'Baseline microbial activity varies by storage condition.',
    '2026-04-02 10:00:00+00',
    NULL,
    'planning',
    NULL,
    NULL,
    NULL,
    NULL
  );

INSERT INTO experiments_researchers (experiment_id, experiment_version, researcher_id, role) VALUES
  (1, 2, 1, 'approver'),
  (1, 2, 3, 'operator'),
  (1, 2, 4, 'assistant'),
  (2, 1, 1, 'approver'),
  (2, 1, 3, 'operator'),
  (2, 1, 5, 'data_reviewer'),
  (3, 1, 2, 'scientific_reviewer'),
  (3, 1, 3, 'operator'),
  (3, 1, 4, 'assistant'),
  (4, 1, 2, 'principal_investigator'),
  (4, 1, 5, 'data_analyst');

INSERT INTO experiment_relationships (
  parent_experiment_id,
  parent_experiment_version,
  child_experiment_id,
  child_experiment_version,
  relationship_type,
  notes
) VALUES
  (1, 2, 2, 1, 'replicates', 'Replicate experiment based on the finalized baseline protocol.'),
  (1, 2, 3, 1, 'informs', 'Stress assay uses baseline observations as comparison point.'),
  (2, 1, 3, 1, 'depends_on', 'Temperature stress assay depends on replicate assay validation.');

-- =========================
-- SAMPLES
-- =========================

INSERT INTO samples (
  id,
  sample_identifier,
  specimen_type,
  collected_at,
  storage_location,
  status,
  expiry_date
) VALUES
  (1, 'BLOOD-2026-0001', 'blood', '2026-02-25 08:00:00+00', 'Freezer A / Rack 1 / Box 4', 'available', '2026-08-25 00:00:00+00'),
  (2, 'BLOOD-2026-0001-A', 'blood_aliquot', '2026-02-25 08:15:00+00', 'Freezer A / Rack 1 / Box 4 / Slot A1', 'available', '2026-08-25 00:00:00+00'),
  (3, 'BLOOD-2026-0001-B', 'blood_aliquot', '2026-02-25 08:20:00+00', 'Freezer A / Rack 1 / Box 4 / Slot A2', 'available', '2026-08-25 00:00:00+00'),
  (4, 'CHEM-2026-GLUCOSE-STD-01', 'chemical_compound', '2026-02-20 10:00:00+00', 'Chemical Cabinet C / Shelf 2', 'available', '2027-02-20 00:00:00+00'),
  (5, 'SOIL-2026-0101', 'soil', '2026-03-20 13:00:00+00', 'Cold Room 2 / Shelf 5', 'available', '2026-09-20 00:00:00+00'),
  (6, 'SOIL-2026-0101-A', 'soil_subsample', '2026-03-20 13:30:00+00', 'Cold Room 2 / Shelf 5 / Tray A', 'available', '2026-09-20 00:00:00+00');

INSERT INTO sample_relationships (parent_sample_id, child_sample_id, relationship_type, notes) VALUES
  (1, 2, 'split', 'Aliquot A prepared from original blood specimen.'),
  (1, 3, 'split', 'Aliquot B prepared from original blood specimen.'),
  (5, 6, 'split', 'Subsample prepared from original soil specimen for baseline analysis.');

INSERT INTO sample_storage_conditions (
  sample_id,
  recorded_at,
  storage_location,
  temperature_celsius,
  humidity_percent,
  notes
) VALUES
  (1, '2026-02-25 09:00:00+00', 'Freezer A / Rack 1 / Box 4', -80.000, NULL, 'Initial storage after collection.'),
  (2, '2026-02-25 09:15:00+00', 'Freezer A / Rack 1 / Box 4 / Slot A1', -80.000, NULL, 'Aliquot placed in storage.'),
  (3, '2026-02-25 09:20:00+00', 'Freezer A / Rack 1 / Box 4 / Slot A2', -80.000, NULL, 'Aliquot placed in storage.'),
  (3, '2026-03-05 08:00:00+00', 'Bench Incubator 1', 37.000, 42.50, 'Moved for temperature stress assay.'),
  (4, '2026-02-20 10:30:00+00', 'Chemical Cabinet C / Shelf 2', 21.500, 40.00, 'Standard received and logged.'),
  (5, '2026-03-20 14:00:00+00', 'Cold Room 2 / Shelf 5', 4.000, 35.00, 'Initial soil storage.'),
  (6, '2026-03-20 14:30:00+00', 'Cold Room 2 / Shelf 5 / Tray A', 4.000, 35.00, 'Subsample stored separately.');

INSERT INTO experiments_samples (
  experiment_id,
  experiment_version,
  sample_id,
  role,
  quantity,
  quantity_unit,
  preparation_notes,
  notes
) VALUES
  (1, 2, 2, 'test_sample', 2.500000, 'mL', 'Thawed on ice before assay.', 'Primary aliquot for baseline assay.'),
  (1, 2, 4, 'calibration_standard', 0.500000, 'mL', 'Prepared according to vendor protocol.', 'Glucose standard used for calibration.'),
  (2, 1, 2, 'test_sample', 2.000000, 'mL', 'Second draw from aliquot A.', 'Same aliquot reused for replication.'),
  (2, 1, 4, 'calibration_standard', 0.500000, 'mL', 'Prepared according to vendor protocol.', 'Calibration standard reused.'),
  (3, 1, 3, 'test_sample', 2.000000, 'mL', 'Moved to incubator before measurement.', 'Aliquot B used for stress assay.'),
  (3, 1, 4, 'calibration_standard', 0.500000, 'mL', 'Prepared according to vendor protocol.', 'Calibration standard reused.'),
  (4, 1, 6, 'test_sample', 10.000000, 'g', 'Soil homogenized before observation.', 'Soil subsample prepared for future baseline work.');

-- =========================
-- MEASUREMENT DEFINITIONS
-- =========================

INSERT INTO measurement_definitions (id, name, value_type, description, default_unit) VALUES
  (1, 'glucose_concentration', 'numeric', 'Measured glucose concentration in sample fluid.', 'mg/L'),
  (2, 'assay_temperature', 'numeric', 'Temperature recorded during or before assay.', 'C'),
  (3, 'viability_result', 'categorical', 'Categorical viability outcome for sample or assay.', NULL),
  (4, 'visual_observation', 'text', 'Free-text observation recorded by researcher.', NULL),
  (5, 'microbial_activity_result', 'categorical', 'Qualitative microbial activity category.', NULL);

INSERT INTO measurement_definition_allowed_values (measurement_definition_id, allowed_value) VALUES
  (3, 'positive'),
  (3, 'negative'),
  (3, 'inconclusive'),
  (5, 'low'),
  (5, 'medium'),
  (5, 'high');

-- =========================
-- DEVICES
-- =========================

INSERT INTO lab_devices (id, device_identifier, name, device_type, manufacturer) VALUES
  (1, 'SPEC-UV-001', 'UV Spectrophotometer 001', 'spectrophotometer', 'Acme Scientific'),
  (2, 'TEMP-PROBE-003', 'Temperature Probe 003', 'temperature_probe', 'LabSensors Inc.'),
  (3, 'MICRO-OBS-002', 'Microscope Station 002', 'microscope', 'OptiLab');

-- =========================
-- MEASUREMENTS
-- =========================
-- Measurement 2 demonstrates correction/versioning: version 1 is superseded by version 2.

INSERT INTO measurements (
  id,
  version,
  is_current,
  experiment_id,
  experiment_version,
  sample_id,
  measurement_definition_id,
  type,
  recorded_at,
  notes,
  numeric_value,
  unit,
  categorical_value,
  text_value,
  recorded_by_researcher_id,
  device_id,
  corrected_from_measurement_id,
  corrected_from_measurement_version
) VALUES
  (
    1,
    1,
    TRUE,
    1,
    2,
    2,
    1,
    'numeric',
    '2026-03-01 10:00:00+00',
    'Baseline glucose reading.',
    91.400000,
    'mg/L',
    NULL,
    NULL,
    3,
    1,
    NULL,
    NULL
  ),
  (
    2,
    1,
    FALSE,
    1,
    2,
    2,
    1,
    'numeric',
    '2026-03-01 11:00:00+00',
    'Original reading later corrected after calibration review.',
    95.900000,
    'mg/L',
    NULL,
    NULL,
    3,
    1,
    NULL,
    NULL
  ),
  (
    2,
    2,
    TRUE,
    1,
    2,
    2,
    1,
    'numeric',
    '2026-03-01 11:00:00+00',
    'Corrected glucose reading after calibration adjustment.',
    94.700000,
    'mg/L',
    NULL,
    NULL,
    3,
    1,
    2,
    1
  ),
  (
    3,
    1,
    TRUE,
    1,
    2,
    2,
    3,
    'categorical',
    '2026-03-01 15:30:00+00',
    'Viability assessed after baseline assay.',
    NULL,
    NULL,
    'positive',
    NULL,
    4,
    NULL,
    NULL,
    NULL
  ),
  (
    4,
    1,
    TRUE,
    1,
    2,
    2,
    4,
    'text',
    '2026-03-01 15:45:00+00',
    'Researcher observation.',
    NULL,
    NULL,
    NULL,
    'Sample remained clear with no visible precipitate.',
    4,
    3,
    NULL,
    NULL
  ),
  (
    5,
    1,
    TRUE,
    2,
    1,
    2,
    1,
    'numeric',
    '2026-03-03 10:15:00+00',
    'Replicate glucose reading.',
    92.100000,
    'mg/L',
    NULL,
    NULL,
    3,
    1,
    NULL,
    NULL
  ),
  (
    6,
    1,
    TRUE,
    2,
    1,
    2,
    3,
    'categorical',
    '2026-03-03 16:20:00+00',
    'Replicate viability outcome.',
    NULL,
    NULL,
    'positive',
    NULL,
    3,
    NULL,
    NULL,
    NULL
  ),
  (
    7,
    1,
    TRUE,
    3,
    1,
    3,
    2,
    'numeric',
    '2026-03-05 09:00:00+00',
    'Temperature before stress assay measurement.',
    37.200000,
    'C',
    NULL,
    NULL,
    3,
    2,
    NULL,
    NULL
  ),
  (
    8,
    1,
    TRUE,
    3,
    1,
    3,
    3,
    'categorical',
    '2026-03-05 12:30:00+00',
    'Viability after temperature stress exposure.',
    NULL,
    NULL,
    'inconclusive',
    NULL,
    4,
    NULL,
    NULL,
    NULL
  ),
  (
    9,
    1,
    TRUE,
    3,
    1,
    3,
    4,
    'text',
    '2026-03-05 13:00:00+00',
    'Visual observation after exposure.',
    NULL,
    NULL,
    NULL,
    'Slight discoloration observed after incubation.',
    4,
    3,
    NULL,
    NULL
  ),
  (
    10,
    1,
    TRUE,
    4,
    1,
    6,
    5,
    'categorical',
    '2026-04-02 11:30:00+00',
    'Preliminary qualitative activity result for soil subsample.',
    NULL,
    NULL,
    'medium',
    NULL,
    5,
    NULL,
    NULL,
    NULL
  );

-- =========================
-- RESET IDENTITY SEQUENCES
-- =========================
-- Because this seed uses explicit IDs, advance identity sequences to avoid collisions
-- when inserting new rows later.

SELECT setval(pg_get_serial_sequence('researchers', 'id'), (SELECT MAX(id) FROM researchers));
SELECT setval(pg_get_serial_sequence('projects', 'id'), (SELECT MAX(id) FROM projects));
SELECT setval(pg_get_serial_sequence('experiments', 'id'), (SELECT MAX(id) FROM experiments));
SELECT setval(pg_get_serial_sequence('samples', 'id'), (SELECT MAX(id) FROM samples));
SELECT setval(pg_get_serial_sequence('sample_storage_conditions', 'id'), (SELECT MAX(id) FROM sample_storage_conditions));
SELECT setval(pg_get_serial_sequence('measurement_definitions', 'id'), (SELECT MAX(id) FROM measurement_definitions));
SELECT setval(pg_get_serial_sequence('lab_devices', 'id'), (SELECT MAX(id) FROM lab_devices));
SELECT setval(pg_get_serial_sequence('measurements', 'id'), (SELECT MAX(id) FROM measurements));

COMMIT;
