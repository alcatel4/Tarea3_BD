-- Habilita las opciones avanzadas de configuracion del servidor SQL Server
EXEC sp_configure 'show advanced options', 1
RECONFIGURE
-- Habilita OPENROWSET y OPENDATASOURCE para leer archivos externos
EXEC sp_configure 'Ad Hoc Distributed Queries', 1
RECONFIGURE
GO

DECLARE @xml XML

SELECT @xml = BulkColumn -- Almacena el contenido del archivo XML en una variable de tipo XML
FROM OPENROWSET(BULK 'C:\Users\Usuario\Desktop\BD1\Tarea3\Datos (1).xml', SINGLE_BLOB) AS x

-- Puestos
INSERT INTO dbo.Puesto (Nombre, SalarioXHora)
SELECT
    nodo.value('@Nombre', 'VARCHAR(100)')
    ,nodo.value('@SalarioXHora', 'MONEY')
FROM @xml.nodes('/Datos/Puestos/Puesto') AS T(nodo)

-- TiposJornada
INSERT INTO dbo.TipoJornada (id, Nombre, HoraInicio, HoraFin)
SELECT
    nodo.value('@Id', 'INT')
    ,nodo.value('@Nombre', 'VARCHAR(50)')
    ,CAST(nodo.value('@HoraInicio', 'VARCHAR(10)') AS DATETIME)
    ,CAST(nodo.value('@HoraFin', 'VARCHAR(10)') AS DATETIME)
FROM @xml.nodes('/Datos/TiposJornada/TipoJornada') AS T(nodo)

-- Feriados
INSERT INTO dbo.Feriado (id, Nombre, Fecha)
SELECT
    nodo.value('@Id', 'INT')
    ,nodo.value('@Nombre', 'VARCHAR(100)')
    ,CAST(nodo.value('@Fecha', 'VARCHAR(20)') AS DATETIME)
FROM @xml.nodes('/Datos/Feriados/Feriado') AS T(nodo)

-- TiposEvento
INSERT INTO dbo.TipoEvento (id, Nombre)
SELECT
    nodo.value('@Id', 'INT')
    ,nodo.value('@Nombre', 'VARCHAR(100)')
FROM @xml.nodes('/Datos/TiposEvento/TipoEvento') AS T(nodo)

-- TiposMovimiento
INSERT INTO dbo.TipoMov (id, Nombre, Accion)
SELECT
    nodo.value('@Id', 'INT')
    ,nodo.value('@Nombre', 'VARCHAR(100)')
    ,nodo.value('@Accion', 'CHAR(1)')
FROM @xml.nodes('/Datos/TiposMovimiento/TipoMovimiento') AS T(nodo)

-- TiposDeduccion
INSERT INTO dbo.TipoDeduccion (id, Nombre, FlagObligatorio, FlagPorcentual, Porcentaje, idTipoMov)
SELECT
    nodo.value('@Id', 'INT')
    ,nodo.value('@Nombre', 'VARCHAR(100)')
    ,CAST(nodo.value('@EsObligatoria', 'INT') AS BIT)
    ,CAST(nodo.value('@EsPorcentual', 'INT') AS BIT)
    ,nodo.value('@Valor', 'DECIMAL(6,4)')
    ,(SELECT tm.id FROM dbo.TipoMov AS tm WHERE (tm.Nombre = nodo.value('@TipoMovimiento', 'VARCHAR(100)')))
FROM @xml.nodes('/Datos/TiposDeduccion/TipoDeduccion') AS T(nodo)

-- Usuarios
INSERT INTO dbo.Usuario (UserName, Password, Tipo)
SELECT
    nodo.value('@Username', 'VARCHAR(50)')
    ,nodo.value('@PasswordHash', 'VARCHAR(255)')
    ,nodo.value('@Tipo', 'TINYINT')
FROM @xml.nodes('/Datos/Usuarios/Usuario') AS T(nodo)

-- Errores
INSERT INTO dbo.Error (Codigo, Descripcion)
SELECT
    nodo.value('@Codigo', 'INT')
    ,nodo.value('@Descripcion', 'VARCHAR(256)')
FROM @xml.nodes('/Datos/Error/error') AS T(nodo)