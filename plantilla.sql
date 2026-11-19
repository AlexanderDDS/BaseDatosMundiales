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

\echo 'Pasando los datos a tablas finales'

INSERT INTO ddbb.Mundial (
    anio,
    pais,
    asistencia
)
SELECT
    TRIM(Year)::INT,
    Country,
    REPLACE(Attendance, '.', '')::INT
FROM ddbb.Mundial_temporal;

INSERT INTO ddbb.Equipo (
    iniciales,
    nombre
)
SELECT
    TRIM(Home_Team_Initials),
    TRIM(Home_Team_Name)
FROM ddbb.Partido_temporal
UNION
SELECT
    TRIM(Away_Team_Initials),
    TRIM(Away_Team_Name)
FROM ddbb.Partido_temporal;

INSERT INTO ddbb.Partido(
    fecha_hora,
    estadio,
    etapa,
    ciudad,
    asistencia,
    arbitro,
    anio_mundial,
    iniciales_equipo_local,
    iniciales_equipo_visitante
)
SELECT DISTINCT
    TO_TIMESTAMP(TRIM(Datetime), 'DD Mon YYYY - HH24:MI')::TIMESTAMP,
    TRIM(Stadium),
    TRIM(Stage),
    TRIM(City),
    REPLACE(Attendance, '.', '')::INT,
    TRIM(Referee),
    TRIM(Year)::INT,
    TRIM(Home_Team_Initials),
    TRIM(Away_Team_Initials)
FROM ddbb.Partido_temporal;

INSERT INTO ddbb.Jugador (
    nombre,
    iniciales_equipo
)
SELECT DISTINCT ON (j.PlayerName)
    j.PlayerName,
    j.TeamInitials
FROM ddbb.Jugador_temporal j
JOIN ddbb.Partido_temporal p
    ON j.MatchID = p.MatchID
ORDER BY j.PlayerName, p.Year ASC;

INSERT INTO ddbb.Juega (
    nombre_jugador,
    fecha_hora_partido,
    estadio_partido,
    num_camiseta,
    suplente_titular,
    posicion
)
SELECT DISTINCT
    TRIM(j.PlayerName),
    TO_TIMESTAMP(p.Datetime, 'DD Mon YYYY - HH24:MI'),
    p.Stadium,
    TRIM(j.ShirtNumber)::INT,
    j.Lineup,
    j.Position
FROM ddbb.Jugador_temporal j
JOIN ddbb.Partido_temporal p ON j.MatchID = p.MatchID;

INSERT INTO ddbb.ProtagonizaEvento (
    nombre_jugador,
    fecha_hora_partido,
    estadio_partido,
    tipo,
    minuto
)
SELECT DISTINCT 
    j.PlayerName,
    TO_TIMESTAMP(p.Datetime, 'DD Mon YYYY - HH24:MI'),
    p.Stadium,
    SUBSTRING(regexp_split_to_table(j.Event, '\s+') FROM '^[A-Z]+')::TEXT,
    SUBSTRING(regexp_split_to_table(j.Event, '\s+') FROM '[0-9]+')::INT
FROM ddbb.Jugador_temporal j
JOIN ddbb.Partido_temporal p ON j.MatchID = p.MatchID;

--Consulta 1: Obtener el listado de todos los partidos de la final ("Final") ordenados del más reciente al más antiguo


--Consulta 2: Mostrar todos los eventos de gol ('G') o gol en propia puerta ('OG') que ocurrieron en los primeros 10 minutos de un partido
--Consulta 3: Contar cuántos partidos se han jugado en cada estadio y ciudad, mostrando los 5 estadios con más partidos en la historia
--Consulta 4: Mostrar los 10 jugadores que han recibido más tarjetas, tanto rojas ('R') como amarillas ('Y')
--Consulta 5: Listar los nombres de los jugadores que han marcado al menos un gol ('G') en una final de un mundial

ROLLBACK;