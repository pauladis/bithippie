# Laboratory Experiment Tracking System

PostgreSQL data model for tracking laboratory researchers, projects, experiments, samples, and measurements.

The goal of this design is to replace spreadsheet-based tracking with a relational schema that supports scientific traceability, experiment lineage, sample reuse, sample derivation, high-volume measurements, and future extensibility.

## How to Run

This project uses Docker and Docker Compose to run PostgreSQL using the `postgres:15-alpine` image

### Prerequisites

- Docker
- Docker Compose

### Start the database

Run the database with one command:

```bash
docker-compose up -d && docker-compose exec postgres psql -U postgres -d bithippie_db -P expanded=on
```

This will:

- pull the PostgreSQL 15 Alpine image if it is not already available;
- create and start the PostgreSQL container;
- initialize the configured database;
- expose PostgreSQL on `localhost:5432`.
- run both migrations files

### Verify the container

```bash
docker-compose ps
```

You should see the `bithippie_postgres` container with status `Up`.

### Connect to PostgreSQL

Using `psql` inside the container:

```bash
docker-compose exec postgres psql -U postgres -d bithippie_db
```

Connection settings:

yeah, I know that this should be in the .env

```text
Host: localhost
Port: 5432
User: postgres
Password: postgres
Database: bithippie_db
```

### Common commands

View logs:

```bash
docker-compose logs -f postgres
```

Stop the container:

```bash
docker-compose down
```

Stop the container and remove persisted database data:

```bash
docker-compose down -v
```

Reset everything and start again:

```bash
docker-compose down -v
docker system prune
docker-compose up -d
```

### Environment variables

PostgreSQL credentials are configured in `.env.docker`:

- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB`

### Initialization scripts

SQL initialization scripts should live in the `init-scripts/` directory. The current schema file should be copied or mounted there so PostgreSQL can run it during the first container startup.

If the database has already been initialized, Postgres will not automatically rerun initialization scripts against the existing volume. Use this command to recreate the database from scratch:

```bash
docker-compose down -v
docker-compose up -d
```

## Design Overview

The schema models the main entities described in the challenge:

- researchers who participate in lab work;
- projects that group related experiments;
- experiments with lifecycle state, version history, approval/completion metadata, and graph-based dependencies;
- samples with unique lab identifiers, lifecycle state, expiry dates, reuse across experiments, and sample lineage;
- measurements with numeric, categorical, and text value shapes;
- measurement provenance, including who recorded a measurement and which device was used.

## Main Technical Decisions

### 1. Selective normalization

Core domain entities are normalized into separate tables:

- `researchers`
- `projects`
- `experiments`
- `samples`
- `measurements`
- `measurement_definitions`
- relationship tables for many-to-many or graph-like relationships

I intentionally did not fully normalize every measurement value into multiple subtype tables because measurements are expected to be high-volume data, around 100K measurements per experiment.

**Tradeoff**

- Pro: normalized core entities reduce duplication and preserve data integrity.
- Pro: a single measurement table keeps common measurement queries simpler and faster.
- Con: the measurement table contains nullable columns because different measurement types use different value fields.

### 2. Measurement value model

Measurements support three value shapes:

- `numeric`: numeric value with optional free-form unit;
- `categorical`: categorical outcome, such as positive/negative or pass/fail;
- `text`: free-text observation.

The schema uses CHECK constraints to ensure that each measurement row uses the correct value column for its type.

I also added `measurement_definitions` to represent the scientific meaning of a measurement, such as `pH`, `temperature`, or `glucose concentration`. This separates the value shape from the measurement concept.

**Tradeoff**

- Pro: supports new measurement definitions without changing the measurement table.
- Pro: keeps measurements queryable without relying on JSONB for core values.
- Con: categorical allowed values are documented as metadata, but strict enforcement is left to the application layer for now.

### 3. Free-form units

Units are stored as free-form text.

This was intentional because the lab has not yet standardized units, and different techniques may use different unit conventions.

**Tradeoff**

- Pro: flexible and easy to adopt early.
- Con: values such as `mg/L`, `mg/l`, and `milligrams_per_liter` may diverge.

A future version could add a `units` reference table or enforce allowed units per measurement definition.

### 4. Experiment lineage as a graph

Experiments can be related through `experiment_relationships` instead of a single `previous_experiment_id` column.

This supports:

- follow-up experiments;
- replications;
- dependency relationships;
- parallel experiments with shared dependencies.

**Tradeoff**

- Pro: more expressive than a single parent reference.
- Con: querying full lineage requires recursive CTEs and is more complex than a simple self-reference.

### 5. Sample lineage as a graph

Samples can be derived from or split into other samples. This is modeled through `sample_relationships`.

This supports:

- parent-child sample derivation;
- splitting one sample into multiple subsamples;
- future lineage queries.

**Tradeoff**

- Pro: accurately models real sample workflows.
- Con: lineage queries are more complex than a simple `parent_sample_id` column.

### 6. Contextual sample usage

Samples are reusable across experiments, so sample usage is modeled through `experiments_samples`.

This table stores contextual fields such as:

- role in the experiment;
- quantity used;
- notes.

A sample's lifecycle status does not include `used`, because a sample can be reused across experiments. Usage history belongs in `experiments_samples`, while sample state belongs in `samples.status`.

### 7. Experiment participants

Researchers can collaborate on projects, but the researchers who conduct a specific experiment are modeled separately in `experiments_researchers`.

This allows a researcher to be:

- a project collaborator;
- an experiment participant;
- both;
- or, in some cases, an ad-hoc contributor to an experiment.

The schema does not require experiment participants to also be project-level collaborators.

**Tradeoff**

- Pro: supports external specialists or temporary lab contributors.
- Con: application logic may be needed if the lab wants stricter team membership rules.

### 8. Researcher roles

The schema tracks both:

- `researchers.lab_role`, representing the researcher's general role in the lab;
- `researchers_projects.role`, representing their role on a specific project;
- `experiments_researchers.role`, representing their role in a specific experiment.

This is because a researcher can be a principal investigator in one project, a reviewer in another, and a contributor to a specific experiment.

### 9. Versioning strategy

Experiments and measurements are versioned using:

- `id`
- `version`
- `is_current`

This avoids destructive updates and preserves historical scientific records.

Versioning is especially useful because:

- experiments may change over time;
- measurements may be corrected or recomputed;
- reproducibility requires knowing what values existed at a given point.

**Tradeoff**

- Pro: preserves history and supports auditability.
- Con: inserts for new versions require reusing the logical `id` and incrementing `version`.
- Con: strict sequential versioning and immutability are not fully enforced by the schema.

In a production system, version sequencing and immutability would be enforced through application logic or additional database triggers.

### 10. Measurement provenance

Measurements include provenance fields:

- `recorded_by_researcher_id`
- `device_id`
- `recorded_at`
- `corrected_from_measurement_id`
- `corrected_from_measurement_version`

This makes it possible to understand who recorded a measurement, when it was recorded, whether a device was involved, and whether the value was derived from a previous measurement version.

The recorder is not required to be a project or experiment participant.

**Tradeoff**

- Pro: supports operational flexibility, such as lab technicians recording data for many teams.
- Con: authorization or team-membership validation would need to happen in the application layer if required.

### 11. Soft deletion / archival

Experiments are not hard-deleted. They move through lifecycle statuses and can be archived.

This is intentional because scientific records usually need to remain available for traceability.

## Constraints Enforced in the Database

The schema enforces several integrity rules directly in Postgres:

- valid project, experiment, sample, and measurement statuses using enums;
- required unique lab sample identifiers;
- foreign keys between core entities;
- valid value columns for each measurement type;
- positive sample quantities;
- date consistency such as `end_date >= start_date` and `expiry_date >= collected_at`;
- completed experiments require completion metadata;
- each measurement sample must be linked to the same experiment through `experiments_samples`;
- at most one current version per experiment or measurement via partial unique indexes.

## Rules Intentionally Left to the Application Layer

Some rules were intentionally not enforced with triggers or complex constraints:

- categorical values should match `measurement_definition_allowed_values`;
- allowed categorical values should only be added to categorical measurement definitions;
- experiment participants should optionally be restricted to project collaborators;
- measurement recorders should optionally be restricted to the experiment or project team;
- status transition workflows, such as whether an experiment can move directly from planning to completed;
- strict sequential version increments and immutability of old versions.

These were left out to keep the schema understandable and avoid turning the database into a workflow engine.

## Indexing and Scalability

Measurements are expected to be the highest-volume table.

The schema includes indexes for common access patterns:

- measurements by experiment and recorded time;
- measurements by sample;
- measurements by definition;
- current measurement versions;
- experiment relationships;
- sample relationships.

Given the expected volume of around 100K measurements per experiment, future improvements may include:

- partitioning measurements by experiment or time;
- materialized views for common summaries;
- TimescaleDB or another time-series optimized extension;
- separate storage for raw instrument output if lab equipment integration is added later.

## Assumptions

- The database is PostgreSQL 15.
- Measurement units are free-form for now.
- Measurement values are either numeric, categorical, or text.
- Measurement definitions describe what is being measured, while measurement type describes the value shape.
- Experiments and measurements should preserve historical versions rather than being overwritten.
- Samples may be reused across experiments.
- Samples may be derived from or split into other samples.
- Samples have unique lab-facing identifiers separate from internal database IDs.
- Experiments are archived instead of hard-deleted.
- Permissions are out of scope for this version.
- Chain of custody for samples is out of scope for this version.
- Lab equipment / IoT ingestion is out of scope for this version.
- API ingestion is out of scope for this version.

## Considered but Not Chosen

### JSONB-only measurement values

I considered storing measurement values entirely in JSONB.

I chose not to do that because numeric, categorical, and text values are core queryable data. Dedicated columns make filtering, indexing, and validation easier.

### Separate measurement subtype tables

I considered separate tables such as `numeric_measurements`, `categorical_measurements`, and `text_measurements`.

I chose not to because the measurement table is expected to be high-volume, and subtype tables would make common queries more join-heavy.

### Simple parent experiment column

I considered adding `previous_experiment_id` directly to `experiments`.

I chose a relationship table because experiments may have multiple dependencies or relationship types.

### Simple parent sample column

I considered adding `parent_sample_id` directly to `samples`.

I chose a relationship table because samples may be split, derived, or related in more than one way.

### Strict database triggers for all business rules

I considered enforcing categorical allowed values, status transitions, team membership, and strict version sequencing with triggers.

I chose not to for this version because those rules are likely to evolve and are better handled by application logic until the lab confirms the exact workflow.

## Open Questions for the Lab

1. Should measurement units be standardized now, or is free-form input acceptable during the initial rollout?
2. Should categorical measurement values be strictly enforced by the database?
3. Do experiments require regulatory-grade immutability and audit logs?
4. Should experiment participants always be project collaborators?
5. Should measurement recorders always be part of the experiment team?
6. What are the most common time-series queries the lab expects to run?
7. Should samples have full chain-of-custody tracking?
8. Are sample storage conditions more complex than `storage_location`, `storage_condition`, and `expiry_date`?
9. Are approval and completion workflows simple metadata fields, or do they require multi-step review?
10. Will lab equipment integration or automated ingestion be required in a future phase?

## Summary

This design favors relational integrity for the core scientific workflow while leaving room for evolving lab practices.

The main design principle is:

> Enforce structural correctness in the database, but avoid encoding fast-changing workflow rules too early.

This gives the lab a strong foundation for tracking experiments, samples, and measurements while keeping the model understandable and extensible.
