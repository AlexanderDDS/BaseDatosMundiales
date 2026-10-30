\pset pager off

SET client_encoding = 'UTF8';

BEGIN;
\echo 'Creando el esquema para la BD de mundiales'

CREATE SCHEMA IF NOT EXISTS ddbb;

\echo 'Creando tablas temporales'

CREATE TABLE IF NOT EXISTS ddbb.Mundial_temporal(
    Year TEXT,
    Country TEXT NOT NULL,
    Winner TEXT,
    RunnersUp TEXT,
    Third TEXT,
    Fourth TEXT,
    GoalsScored TEXT,
    QualifiedTeams TEXT,
    MatchesPlayed TEXT,
    Attendance TEXT
);


CREATE TABLE IF NOT EXISTS ddbb.Partido_temporal(
    Year TEXT,
    Datetime TEXT,
    Stage TEXT,
    Stadium TEXT NOT NULL,
    City TEXT,
    Home_Team_Name TEXT,
    Home_Team_Goals TEXT,
    Away_Team_Goals TEXT,
    Away_Team_Name TEXT,
    Win_conditions TEXT,
    Attendance TEXT,
    Half_time_Home_Goals TEXT,
    Half_time_Away_Goals TEXT,
    Referee TEXT,
    Assistant1 TEXT,
    Assistant2 TEXT,
    RoundID TEXT,
    MatchID TEXT,
    Home_Team_Initials TEXT,
    Away_Team_Initials TEXT
);

CREATE TABLE IF NOT EXISTS ddbb.Jugador_temporal(
    RoundID TEXT,
    MatchID TEXT,
    TeamInitials TEXT,
    CoachName TEXT,
    Lineup TEXT,
    ShirtNumber TEXT,
    PlayerName TEXT, 
    Position TEXT,
    Event TEXT
);


\echo 'Cargando datos en tablas temporales'

\COPY ddbb.Jugador_temporal FROM 'WorldCupPlayers.csv' WITH (FORMAT CSV, DELIMITER ',', HEADER);
\COPY ddbb.Mundial_temporal FROM 'WorldCups.csv' WITH (FORMAT CSV, DELIMITER ',', HEADER);
\COPY ddbb.Partido_temporal FROM 'WorldCupMatches.csv' WITH (FORMAT CSV, DELIMITER ',', HEADER);

\echo 'Creando tablas finales'

CREATE TABLE IF NOT EXISTS ddbb.Mundial (
    anio INT NOT NULL,
    pais TEXT NOT NULL,
    asistencia INT,
    CONSTRAINT Mundial_pk PRIMARY KEY (anio)
);


CREATE TABLE IF NOT EXISTS ddbb.Equipo (
    iniciales TEXT NOT NULL,
    nombre TEXT NOT NULL,
    CONSTRAINT Equipo_pk PRIMARY KEY (iniciales)
);

CREATE TABLE IF NOT EXISTS ddbb.Partido (
    fecha_hora TIMESTAMP,
    estadio TEXT NOT NULL,
    etapa TEXT NOT NULL,
    ciudad TEXT NOT NULL,
    asistencia INT,
    arbitro TEXT NOT NULL,
    anio_mundial INT NOT NULL,
    iniciales_equipo_local TEXT NOT NULL,
    iniciales_equipo_visitante TEXT NOT NULL,
    CONSTRAINT Partido_pk PRIMARY KEY (fecha_hora, estadio),
    CONSTRAINT Mundial_fk FOREIGN KEY (anio_mundial) REFERENCES ddbb.Mundial (anio) MATCH FULL
    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT Equipo_local_fk FOREIGN KEY (iniciales_equipo_local) REFERENCES ddbb.Equipo (iniciales) MATCH FULL
    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT Equipo_visitante_fk FOREIGN KEY (iniciales_equipo_visitante) REFERENCES ddbb.Equipo (iniciales) MATCH FULL
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS ddbb.Jugador (
    nombre TEXT NOT NULL,
    iniciales_equipo TEXT NOT NULL,
    CONSTRAINT Jugador_pk PRIMARY KEY (nombre),
    CONSTRAINT Equipo_fk FOREIGN KEY (iniciales_equipo) REFERENCES ddbb.Equipo (iniciales) MATCH FULL
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS ddbb.Juega (
    nombre_jugador TEXT NOT NULL,
    fecha_hora_partido TIMESTAMP NOT NULL,
    estadio_partido TEXT NOT NULL,
    num_camiseta INT NOT NULL,
    suplente_titular TEXT NOT NULL,
    posicion TEXT,
    CONSTRAINT Jugador_fk FOREIGN KEY (nombre_jugador) REFERENCES ddbb.Jugador (nombre) MATCH FULL
    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT Partido_fk FOREIGN KEY (fecha_hora_partido, estadio_partido) REFERENCES ddbb.Partido (fecha_hora, estadio) MATCH FULL
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS ddbb.ProtagonizaEvento (
    nombre_jugador TEXT NOT NULL,
    fecha_hora_partido TIMESTAMP NOT NULL,
    estadio_partido TEXT NOT NULL,
    tipo TEXT NOT NULL,
    minuto INT NOT NULL,
    CONSTRAINT Jugador_fk FOREIGN KEY (nombre_jugador) REFERENCES ddbb.Jugador (nombre) MATCH FULL
    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT Partido_fk FOREIGN KEY (fecha_hora_partido, estadio_partido) REFERENCES ddbb.Partido (fecha_hora, estadio) MATCH FULL
    ON DELETE RESTRICT ON UPDATE CASCADE
);

\echo 'Pasando los datos a tablas finales (por ahora solo lo hemos hecho para Mundial)'

INSERT INTO ddbb.Mundial (
    anio,
    pais,
    asistencia
)
SELECT
    TRIM(Year)::INT,
    Country,
    REPLACE(TRIM(Attendance), '.', '')::INT
FROM ddbb.Mundial_temporal;

ROLLBACK;