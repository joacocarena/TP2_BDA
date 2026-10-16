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


-- 8.1. Red vial principal
-- Identificar las rutas nacionales y provinciales que atraviesan el departamento seleccionado.
SELECT DISTINCT r.name
FROM rutas r
JOIN departamentos d
    ON ST_Intersects(r.geom, d.geom)
WHERE d.nam = 'San Salvador' AND r.name IS NOT NULL;

-- 8.2. Longitud de las rutas
-- Calcular cuántos kilómetros de cada ruta se encuentran dentro del departamento.
-- Los resultados deberán presentarse en forma de tabla y acompañarse, cuando sea posible, con
-- una representación cartográfica.
SELECT
    COALESCE(NULLIF(TRIM(r.ref), ''), r.name) AS ruta,
    ROUND(SUM(ST_Length(ST_CollectionExtract(ST_Intersection(r.geom, d.geom), 2)::geography))::numeric / 1000,2) AS longitud_km
FROM rutas r
JOIN departamentos d
    ON ST_Intersects(r.geom, d.geom)
WHERE d.nam = 'San Salvador'
  AND (
      NULLIF(TRIM(r.ref), '') IS NOT NULL
      OR NULLIF(TRIM(r.name), '') IS NOT NULL
  )
GROUP BY COALESCE(NULLIF(TRIM(r.ref), ''), r.name)
ORDER BY ruta;

-- 8.3. Establecimientos de salud
-- Identificar los hospitales y clínicas registrados en OpenStreetMap dentro del departamento.
-- Analizar su distribución espacial.
SELECT
    s.name AS establecimiento,
    s.amenity,
    s.healthcare,
    s.addr_city AS localidad
FROM salud s
JOIN departamentos d
    ON ST_Intersects(s.geom, d.geom)
WHERE d.nam = 'San Salvador'
  AND (
      s.amenity IN ('hospital', 'clinic')
      OR s.healthcare IN ('hospital', 'clinic')
  )
ORDER BY s.name;






-- 8.4. Localidad más alejada
-- Determinar qué localidad del departamento presenta la mayor distancia respecto de un
-- establecimiento de salud.
-- El grupo deberá explicar el criterio utilizado para determinar dicha distancia.

SELECT
    l.name AS localidad,
    ROUND(
        MIN(ST_Distance(l.geom::geography,ST_PointOnSurface(s.geom)::geography))::numeric / 1000,2) AS distancia_km
FROM localidades l
JOIN departamentos d
    ON ST_Intersects(l.geom, d.geom)
CROSS JOIN salud s
WHERE d.nam = 'San Salvador'
  AND ST_Intersects(s.geom, d.geom)
  AND (
      s.amenity IN ('hospital', 'clinic')
      OR s.healthcare IN ('hospital', 'clinic')
  )
GROUP BY l.id, l.name
ORDER BY distancia_km DESC;

--Se realizó un análisis de proximidad espacial con el objetivo de determinar cuál de las localidades del departamento San Salvador presenta la mayor distancia respecto de un establecimiento de salud.
-- Para ello, se utilizaron las geometrías de las localidades y los establecimientos sanitarios registrados en OpenStreetMap. Mediante la función ST_Distance de PostGIS, se calculó la distancia entre cada localidad y los establecimientos de salud ubicados dentro del departamento.
-- Posteriormente, se seleccionó la distancia mínima correspondiente a cada localidad, identificando así el establecimiento más cercano. Finalmente, los resultados se ordenaron de forma descendente para determinar la localidad que presenta la mayor distancia.
-- Las distancias obtenidas corresponden a distancias geográficas en línea recta, por lo que no representan necesariamente las distancias reales de desplazamiento por la red vial.


-- 8.5. Área de cobertura sanitaria
-- Generar un área de influencia de 5 km alrededor de los establecimientos de salud.
-- A partir de esta información, determinar cuántas localidades del departamento quedan fuera
-- de dicha cobertura.
-- Representar el resultado en QGIS y explicar qué podría significar esta situación desde el punto
-- de vista de la accesibilidad sanitaria.


WITH cobertura AS (
    SELECT ST_Union(
        ST_Buffer(
            s.geom::geography,
            5000
        )::geometry
    ) AS geom
    FROM salud s
    JOIN departamentos d
        ON ST_Intersects(s.geom, d.geom)
    WHERE d.nam = 'San Salvador'
),
localidades_fuera AS (
    SELECT
        l.id,
        l.name AS localidad,
        l.geom
    FROM localidades l
    JOIN departamentos d
        ON ST_Intersects(l.geom, d.geom)
    CROSS JOIN cobertura c
    WHERE d.nam = 'San Salvador'
      AND NOT ST_Covers(c.geom, l.geom)
)
SELECT
    localidad
FROM localidades_fuera
ORDER BY localidad;
-- Ninguna queda fuera



-- 9.1
-- Generar una zona de influencia de 2 km alrededor de los ríos, arroyos y lagunas del
-- departamento seleccionado.

DROP TABLE IF EXISTS zona_riesgo_final;

CREATE TABLE zona_riesgo_final AS
WITH departamento AS (
    SELECT ST_UnaryUnion(ST_Collect(geom)) AS geom
    FROM departamentos
    WHERE nam = 'San Salvador'
),
agua AS (
    SELECT r.geom
    FROM rios r
    CROSS JOIN departamento d
    WHERE ST_Intersects(r.geom, d.geom)

    UNION ALL

    SELECT l.geom
    FROM lagunas l
    CROSS JOIN departamento d
    WHERE ST_Intersects(l.geom, d.geom)
),
buffers AS (
    SELECT
        ST_Buffer(
            geom::geography,
            2000
        )::geometry AS geom
    FROM agua
),
union_buffers AS (
    SELECT ST_UnaryUnion(ST_Collect(geom)) AS geom
    FROM buffers
)
SELECT
    1 AS id,
    ST_Multi(
        ST_CollectionExtract(
            ST_Intersection(u.geom, d.geom),
            3
        )
    )::geometry(MultiPolygon, 4326) AS geom
FROM union_buffers u
CROSS JOIN departamento d;





--9.2


SELECT
    s.id,
    s.name AS establecimiento,
    s.amenity AS tipo,
    s.healthcare,
    CASE
        WHEN ST_Intersects(s.geom, z.geom)
        THEN 'Expuesto'
        ELSE 'No expuesto'
    END AS situacion
FROM salud s
CROSS JOIN zona_riesgo_final z
JOIN departamentos d
    ON d.nam = 'San Salvador'
WHERE ST_Intersects(s.geom, d.geom)
ORDER BY situacion, establecimiento;

-- 9.3. Posibles situaciones de aislamiento
SELECT
    r.id AS id_ruta,
    r.ref AS ruta,
    r.name AS nombre_ruta,
    a.id AS id_curso_agua,
    a.name AS curso_agua,
    ST_Intersection(r.geom, a.geom) AS interseccion
FROM rutas r
JOIN rios a
    ON ST_Intersects(r.geom, a.geom)
JOIN departamentos d
    ON ST_Intersects(r.geom, d.geom)
WHERE d.nam = 'San Salvador'
  AND ST_Intersects(
      ST_Intersection(r.geom, a.geom),
      d.geom
  )
ORDER BY r.ref, a.name;

-- Se realizó un análisis espacial para identificar posibles dificultades de conectividad entre las localidades del departamento San Salvador y la red vial principal, considerando la presencia de ríos y arroyos.
-- Metodología utilizada
-- En primer lugar, mediante la función ST_Intersects, se identificaron los puntos donde las rutas intersectan los cursos de agua del departamento. Estos puntos fueron considerados posibles sectores críticos de la infraestructura vial.
-- Posteriormente, se analizó la proximidad de las localidades a las rutas mediante ST_Distance y ST_ClosestPoint. A partir de ello, se construyeron conexiones lineales directas entre cada localidad y la ruta más cercana, verificando si dichas conexiones atravesaban cursos de agua.
-- Adicionalmente, se utilizó ST_DWithin para identificar cursos de agua ubicados a menos de 500 metros de las localidades.
-- Interpretación
-- La presencia de cursos de agua en las proximidades de localidades o en puntos de intersección con la red vial puede representar una dificultad potencial para la conectividad territorial, particularmente ante crecidas o interrupciones del tránsito.
-- Sin embargo, las intersecciones espaciales no implican necesariamente una situación de aislamiento, dado que pueden existir puentes u otras infraestructuras que permitan atravesar los cursos de agua.
-- Asimismo, las conexiones lineales analizadas representan distancias directas y no recorridos reales por la red vial.
-- Por lo tanto, los resultados constituyen una aproximación exploratoria para identificar posibles puntos vulnerables, siendo necesario incorporar información sobre puentes, caminos alternativos y condiciones de transitabilidad para evaluar situaciones reales de aislamiento.

-- 9.4. Departamentos con mayor exposición
-- Realizar un análisis a escala provincial para identificar departamentos con una mayor
-- proporción de superficie relacionada con cuerpos de agua o zonas de influencia hídrica.
-- Para este ejercicio se utilizará como referencia un 30 % de superficie.

WITH zonas_hidricas AS (
    SELECT
        ST_Buffer(geom::geography, 2000)::geometry AS geom
    FROM rios_provincia

    UNION ALL

    SELECT
        ST_Buffer(geom::geography, 2000)::geometry AS geom
    FROM aguas_provincia
),
zona_unificada AS (
    SELECT ST_UnaryUnion(ST_Collect(geom)) AS geom
    FROM zonas_hidricas
),
superficies AS (
    SELECT
        d.nam AS departamento,

        ST_Area(d.geom::geography) / 1000000
            AS superficie_total_km2,

        ST_Area(
            ST_CollectionExtract(
                ST_Intersection(d.geom, z.geom), 3
            )::geography
        ) / 1000000 AS superficie_expuesta_km2

    FROM departamentos d
    CROSS JOIN zona_unificada z
)
SELECT
    departamento,
    ROUND(superficie_total_km2::numeric, 2)
        AS superficie_total_km2,
    ROUND(superficie_expuesta_km2::numeric, 2)
        AS superficie_expuesta_km2,
    ROUND(
        (
            superficie_expuesta_km2 /
            NULLIF(superficie_total_km2, 0) * 100
        )::numeric,
        2
    ) AS porcentaje_exposicion,
    CASE
        WHEN superficie_expuesta_km2 /
             NULLIF(superficie_total_km2, 0) >= 0.30
        THEN 'Mayor exposición'
        ELSE 'Menor exposición'
    END AS clasificacion
FROM superficies
ORDER BY porcentaje_exposicion DESC;

-- 10.1. Clasificación del riesgo de una localidad
-- Crear una función denominada:
-- fn_riesgo_localidad(nombre_localidad)
-- La función deberá recibir el nombre de una localidad y devolver una clasificación:
-- Alto: distancia inferior a 1 km de un río, arroyo o laguna.
-- Medio: distancia entre 1 y 3 km.
-- Bajo: distancia superior a 3 km.
-- Además de desarrollar la función, deberán probarla utilizando varias localidades y analizar los
-- resultados.

CREATE OR REPLACE FUNCTION fn_riesgo_localidad(
    nombre_localidad VARCHAR
)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_geom GEOMETRY;
    v_distancia DOUBLE PRECISION;
BEGIN
    SELECT geom
    INTO v_geom
    FROM localidades
    WHERE LOWER(name) = LOWER(nombre_localidad)
    LIMIT 1;

    IF v_geom IS NULL THEN
        RETURN 'Localidad no encontrada';
    END IF;

    SELECT MIN(distancia)
    INTO v_distancia
    FROM (
        SELECT ST_Distance(
            v_geom::geography,
            geom::geography
        ) AS distancia
        FROM rios
        UNION ALL
        SELECT ST_Distance(
            v_geom::geography,
            geom::geography
        ) AS distancia
        FROM lagunas
    ) AS distancias;

    IF v_distancia IS NULL THEN
        RETURN 'Sin datos hídricos';
    END IF;

    IF v_distancia < 1000 THEN
        RETURN 'Alto';

    ELSIF v_distancia <= 3000 THEN
        RETURN 'Medio';

    ELSE
        RETURN 'Bajo';
    END IF;
END;
$$;




--10.2. MBR de Entre Ríos
--Obtener el Mínimo Rectángulo Delimitador (MBR) correspondiente al territorio de Entre Ríos
--utilizando ST_Envelope.
--Calcular además la superficie de dicha envolvente y compararla con la superficie real de la
--provincia.
--Explicar por qué ambas superficies son diferentes.


SELECT
    ROUND((ST_Area(geom::geography) / 1000000)::numeric,2) AS superficie_provincia_km2,
    ROUND((ST_Area(ST_Envelope(geom)::geography) / 1000000)::numeric,2) AS superficie_mbr_km2,
 	ROUND((ST_Area(ST_Envelope(geom)::geography)- ST_Area(geom::geography))::numeric / 1000000,2) AS diferencia_km2,
	ROUND((ST_Area(geom::geography) /NULLIF(ST_Area(ST_Envelope(geom)::geography), 0)* 100)::numeric,2) AS porcentaje_ocupacion
FROM provincia;


--10.3. Hospital más cercano
--Crear una función parametrizada:
--fn_hospital_cercano(lat, lon)
--La función deberá recibir una coordenada geográfica y devolver:
-- nombre del establecimiento de salud más cercano;
-- distancia hasta el mismo.
--La consulta deberá simular la situación de una persona que solicita asistencia indicando
--únicamente su posición.

CREATE OR REPLACE FUNCTION fn_hospital_cercano(
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION
)
RETURNS TABLE (
    establecimiento VARCHAR,
    distancia_km NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.name::VARCHAR AS establecimiento,
        ROUND(
            (
                ST_Distance(
                    ST_SetSRID(
                        ST_MakePoint(lon, lat),
                        4326
                    )::geography,
                    s.geom::geography
                ) / 1000
            )::numeric,
            2
        ) AS distancia_km
    FROM salud s
    WHERE s.amenity IN ('hospital', 'clinic')
       OR s.healthcare IN ('hospital', 'clinic')
    ORDER BY
        ST_Distance(
            ST_SetSRID(
                ST_MakePoint(lon, lat),
                4326
            )::geography,
            s.geom::geography
        )
    LIMIT 1;
END;
$$;

SELECT * FROM fn_hospital_cercano(-31.624, -58.506);




-- 10.4. Agrupamiento de establecimientos sanitarios

CREATE OR REPLACE VIEW clusters_salud AS
WITH establecimientos AS (
    SELECT
        s.id,
        s.name,
        ST_PointOnSurface(s.geom) AS geom
    FROM salud s
    JOIN departamentos d
        ON ST_Intersects(s.geom, d.geom)
    WHERE d.nam = 'San Salvador'
)
SELECT
    id,
    name,
    ST_ClusterKMeans(
        geom, 3
    ) OVER () AS cluster,
    geom
FROM establecimientos;



SELECT
    cluster,
    STRING_AGG(name, ', ') AS establecimientos,
    COUNT(*) AS cantidad
FROM clusters_salud
GROUP BY cluster
ORDER BY cluster;




CREATE OR REPLACE VIEW centroides_salud AS
SELECT
    cluster AS id,
    COUNT(*) AS cantidad,
    ST_Centroid(
        ST_Collect(geom)
    )::geometry(Point, 4326) AS geom
FROM clusters_salud
GROUP BY cluster;


select * from centroides_salud


--Se realizó un análisis de agrupamiento espacial de los establecimientos de salud del departamento San Salvador mediante la función `ST_ClusterKMeans` de PostGIS, estableciendo tres grupos (k = 3), según lo solicitado en la consigna.
--Debido a que el departamento cuenta con solamente tres establecimientos sanitarios registrados en la base de datos, el algoritmo asignó un establecimiento a cada clúster.
--Posteriormente, se calcularon los centroides de los grupos mediante las funciones `ST_Collect` y `ST_Centroid`.
--Como cada grupo contiene un único establecimiento, los centroides obtenidos coinciden con las ubicaciones representativas de dichos establecimientos.
--**Interpretación de los resultados**
--El agrupamiento realizado presenta una limitación importante: al existir la misma cantidad de establecimientos que de grupos solicitados, no se generan agrupamientos de múltiples establecimientos que permitan identificar concentraciones espaciales.
--En consecuencia, los centroides obtenidos no aportan nuevas ubicaciones potenciales para mejorar la distribución de ambulancias, medicamentos o futuros centros de atención, sino que representan los establecimientos existentes.
--Para realizar un análisis más significativo sería conveniente ampliar el área de estudio, incorporar establecimientos de salud adicionales o utilizar un menor número de grupos.
--Por lo tanto, el ejercicio permite demostrar el funcionamiento de `ST_ClusterKMeans`, aunque los resultados tienen una utilidad limitada para la planificación sanitaria debido a la escasa cantidad de establecimientos disponibles.


-- 11.1. Densidad de la red vial
-- Calcular la longitud total de calles del departamento seleccionado.
-- Comparar este valor con el promedio correspondiente al conjunto de departamentos de Entre Ríos.

WITH longitud_departamentos AS (
    SELECT
        d.id,
        d.nam AS departamento,
        COALESCE(
            SUM(
                ST_Length(
                    ST_CollectionExtract(
                        ST_Intersection(c.geom, d.geom),
                        2
                    )::geography
                )
            ), 0
        ) / 1000 AS longitud_km
    FROM departamentos d
    LEFT JOIN calles_provincia c
        ON ST_Intersects(c.geom, d.geom)
    GROUP BY d.id, d.nam
),
promedio AS (
    SELECT AVG(longitud_km) AS promedio_km
    FROM longitud_departamentos
)
SELECT
    l.departamento,

    ROUND(l.longitud_km::numeric, 2)
        AS longitud_total_km,

    ROUND(p.promedio_km::numeric, 2)
        AS promedio_provincial_km,

    ROUND(
        (l.longitud_km - p.promedio_km)::numeric,
        2
    ) AS diferencia_km,

    CASE
        WHEN l.longitud_km > p.promedio_km
            THEN 'Superior al promedio'
        WHEN l.longitud_km < p.promedio_km
            THEN 'Inferior al promedio'
        ELSE 'Igual al promedio'
    END AS comparacion

FROM longitud_departamentos l
CROSS JOIN promedio p
ORDER BY l.longitud_km DESC;


-- 11.2. Densidad vial por localidad
-- Determinar qué localidad presenta la mayor densidad vial.
-- Para ello se podrá utilizar como indicador: longitud total de calles / superficie de la localidad
-- Explicar las decisiones tomadas para realizar el cálculo.


WITH areas_localidades AS (
    SELECT
        l.id,
        l.name AS localidad,
        ST_Intersection(
            ST_Buffer(l.geom::geography, 2000)::geometry,
            d.geom
        ) AS geom
    FROM localidades l
    JOIN departamentos d
        ON ST_Intersects(l.geom, d.geom)
    WHERE d.nam = 'San Salvador'
),
densidades AS (
    SELECT
        a.localidad,

        ST_Area(a.geom::geography) / 1000000
            AS superficie_km2,

        COALESCE(
            SUM(
                ST_Length(
                    ST_CollectionExtract(
                        ST_Intersection(c.geom, a.geom),
                        2
                    )::geography
                )
            ), 0
        ) / 1000 AS longitud_calles_km

    FROM areas_localidades a
    LEFT JOIN calles c
        ON ST_Intersects(c.geom, a.geom)

    GROUP BY a.id, a.localidad, a.geom
)
SELECT
    localidad,

    ROUND(superficie_km2::numeric, 2)
        AS superficie_km2,

    ROUND(longitud_calles_km::numeric, 2)
        AS longitud_calles_km,

    ROUND(
        (
            longitud_calles_km /
            NULLIF(superficie_km2, 0)
        )::numeric,
        2
    ) AS densidad_vial,

    RANK() OVER (
        ORDER BY
            longitud_calles_km /
            NULLIF(superficie_km2, 0) DESC
    ) AS posicion

FROM densidades
ORDER BY posicion;

-- 11.3. Categorías de calles
-- Identificar las calles clasificadas como:
-- primary secondary y calcular cuántos kilómetros corresponden a cada categoría.

SELECT
    c.highway AS categoria,
    COUNT(*) AS cantidad_tramos,
    ROUND(
        (
            SUM(
                ST_Length(
                    ST_CollectionExtract(
                        ST_Intersection(c.geom, d.geom),
                        2
                    )::geography
                )
            ) / 1000
        )::numeric,
        2
    ) AS longitud_km
FROM calles c
JOIN departamentos d
    ON ST_Intersects(c.geom, d.geom)
WHERE d.nam = 'San Salvador'
  AND c.highway IN ('primary', 'secondary')
GROUP BY c.highway
ORDER BY longitud_km DESC;



