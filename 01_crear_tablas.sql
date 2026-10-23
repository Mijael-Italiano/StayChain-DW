CREATE DATABASE IF NOT EXISTS staychain;

USE staychain;

-- 1. DIMENSIÓN HOTEL
CREATE TABLE IF NOT EXISTS DIM_HOTEL (
    id_hotel INT PRIMARY KEY,
    nombre VARCHAR(100),
    tipo VARCHAR(50),
    provincia VARCHAR(100),
    capacidad_hab INT
);

-- 2. DIMENSIÓN HABITACIÓN
CREATE TABLE IF NOT EXISTS DIM_HABITACION (
    id_habitacion INT PRIMARY KEY,
    tipo_habitacion VARCHAR(50),
    capacidad INT,
    precio_rack DECIMAL(10,2)
);

-- 3. DIMENSIÓN CANAL
CREATE TABLE IF NOT EXISTS DIM_CANAL (
    id_canal INT PRIMARY KEY,
    nombre_canal VARCHAR(100),
    tipo_canal VARCHAR(50)
);

-- 4. DIMENSIÓN CLIENTE
CREATE TABLE IF NOT EXISTS DIM_CLIENTE (
    id_cliente INT PRIMARY KEY,
    tipo_cliente VARCHAR(50),
    es_recurrente BOOLEAN,
    estancias_previas INT,
    cancelaciones_previas INT
);

-- 5. DIMENSIÓN TEMPORADA
CREATE TABLE IF NOT EXISTS DIM_TEMPORADA (
    id_temporada INT PRIMARY KEY,
    nombre VARCHAR(50),
    mes_inicio INT,
    mes_fin INT
);

-- 6. DIMENSIÓN FECHA
CREATE TABLE IF NOT EXISTS DIM_FECHA (
    id_fecha INT PRIMARY KEY,
    fecha DATE,
    dia INT,
    mes INT,
    trimestre INT,
    anio INT,
    es_fin_semana BOOLEAN,
    es_feriado BOOLEAN
);

-- 7. TABLA DE HECHOS: RESERVAS
CREATE TABLE IF NOT EXISTS FACT_RESERVA (
    id_reserva INT PRIMARY KEY,
    id_fecha_llegada INT,
    id_hotel INT,
    id_habitacion INT,
    id_canal INT,
    id_cliente INT,
    id_temporada INT,
    noches_total INT,
    cantidad_huespedes INT,
    adr DECIMAL(10,2),
    revenue_total DECIMAL(12,2),
    lead_time INT,
    is_cancelada BOOLEAN,

    FOREIGN KEY (id_fecha_llegada) REFERENCES DIM_FECHA(id_fecha),
    FOREIGN KEY (id_hotel) REFERENCES DIM_HOTEL(id_hotel),
    FOREIGN KEY (id_habitacion) REFERENCES DIM_HABITACION(id_habitacion),
    FOREIGN KEY (id_canal) REFERENCES DIM_CANAL(id_canal),
    FOREIGN KEY (id_cliente) REFERENCES DIM_CLIENTE(id_cliente),
    FOREIGN KEY (id_temporada) REFERENCES DIM_TEMPORADA(id_temporada)
);

-- 8. TABLA DE HECHOS: CANCELACIONES
CREATE TABLE IF NOT EXISTS FACT_CANCELACION (
    id_cancelacion INT PRIMARY KEY,
    id_reserva_orig INT,
    id_fecha_cancelacion INT,
    id_hotel INT,
    id_canal INT,
    id_cliente INT,
    dias_anticipacion_cancel INT,
    lead_time_original INT,
    revenue_perdido DECIMAL(12,2),
    tipo_tarifa VARCHAR(50),
    previous_cancellations INT,

    FOREIGN KEY (id_reserva_orig) REFERENCES FACT_RESERVA(id_reserva),
    FOREIGN KEY (id_fecha_cancelacion) REFERENCES DIM_FECHA(id_fecha),
    FOREIGN KEY (id_hotel) REFERENCES DIM_HOTEL(id_hotel),
    FOREIGN KEY (id_canal) REFERENCES DIM_CANAL(id_canal),
    FOREIGN KEY (id_cliente) REFERENCES DIM_CLIENTE(id_cliente)
);

SHOW TABLES;