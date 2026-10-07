-- 7.1. Departamentos vecinos
-- Identificar cuáles son los departamentos que limitan con el departamento seleccionado.
SELECT d2.nam AS departamento_vecino
FROM departamentos d1
JOIN departamentos d2
    ON ST_Intersects(d1.geom, d2.geom)
WHERE d1.nam = 'San Salvador'
  AND d2.nam <> 'San Salvador'
ORDER BY d2.nam;



-- 7.2. Frontera común
--Seleccionar al menos uno de los departamentos vecinos y obtener la geometría correspondiente a la frontera compartida.
-- El resultado deberá poder visualizarse posteriormente en QGIS.
SELECT
    d1.nam AS departamento,
    d2.nam AS vecino,
    ST_Intersection(
        ST_Boundary(d1.geom),
        ST_Boundary(d2.geom)
    ) AS geom
FROM departamentos d1
JOIN departamentos d2
    ON ST_Touches(d1.geom, d2.geom)
WHERE d1.nam = 'San Salvador'
  AND d2.nam = 'Federal';

-- 7.3. Presencia de cuerpos de agua
-- Realizar un ranking de los departamentos de Entre Ríos según la cantidad de lagunas y otros
-- cuerpos de agua identificados en las fuentes utilizadas.
-- Explicar brevemente qué limitaciones puede tener este ranking debido a la fuente de
-- información utilizada.


  SELECT
    d.nam AS departamento,

    (SELECT COUNT(*)
     FROM aguas_provincia a
     WHERE ST_Intersects(d.geom, a.geom)
    ) AS cuerpos_agua,

    (SELECT COUNT(*)
     FROM rios_provincia r
     WHERE ST_Intersects(d.geom, r.geom)
    ) AS segmentos_rios_arroyos

FROM departamentos d


-- 7.4. Superficie cubierta por agua
-- Calcular, para el departamento seleccionado:
-- superficie total;
-- superficie correspondiente a lagunas o cuerpos de agua;
-- superficie restante;
-- porcentaje de superficie ocupada por agua.
-- Los resultados deberán expresarse en km².



WITH superficies AS (
    SELECT
        (SELECT ST_Area(geom::geography) / 1000000
         FROM departamentos
         WHERE nam = 'San Salvador') AS total_km2,

        (SELECT COALESCE(
            ST_Area(
                ST_UnaryUnion(ST_Collect(geom))::geography
            ) / 1000000, 0)
         FROM lagunas) AS agua_km2
)
SELECT
    ROUND(total_km2::numeric, 2) AS superficie_total_km2,
    ROUND(agua_km2::numeric, 2) AS superficie_agua_km2,
    ROUND((total_km2 - agua_km2)::numeric, 2)
        AS superficie_restante_km2,
    ROUND((agua_km2 * 100 / total_km2)::numeric, 2)
        AS porcentaje_agua
FROM superficies;


-- 7.5. Cursos de agua
-- Identificar los ríos y arroyos que atraviesan el departamento seleccionado y calcular la longitud
-- total de estos cursos de agua dentro del departamento.
-- Presentar los resultados en metros.
SELECT
    ROUND(SUM(ST_Length(geom::geography))::numeric, 2)
        AS longitud_total_metros
FROM rios;
