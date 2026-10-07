WITH geometrías AS (
    SELECT 'calles' AS tabla, geom FROM calles
    UNION ALL
    SELECT 'departamentos', geom FROM departamentos
    UNION ALL
    SELECT 'lagunas', geom FROM lagunas
    UNION ALL
    SELECT 'localidades', geom FROM localidades
    UNION ALL
    SELECT 'provincia', geom FROM provincia
    UNION ALL
    SELECT 'rios', geom FROM rios
    UNION ALL
    SELECT 'rutas', geom FROM rutas
    UNION ALL
    SELECT 'salud', geom FROM salud
)
SELECT
    tabla,
    COUNT(*) AS total_registros,
    COUNT(*) FILTER (WHERE geom IS NULL) AS geometrias_nulas,
    COUNT(*) FILTER (WHERE geom IS NOT NULL AND ST_IsEmpty(geom))
        AS geometrias_vacias,
    COUNT(*) FILTER (WHERE geom IS NOT NULL AND NOT ST_IsValid(geom))
        AS geometrias_invalidas,
    STRING_AGG(
        DISTINCT ST_GeometryType(geom),
        ', '
    ) AS tipos_geometria,
    STRING_AGG(
        DISTINCT ST_SRID(geom)::TEXT,
        ', '
    ) AS srid
FROM geometrías
GROUP BY tabla
ORDER BY tabla;

-- checkea que no haya geometrias invalidas y demas