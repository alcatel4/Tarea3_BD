-- Limpiar datos previos
DELETE FROM dbo.BitacoraEvento
DELETE FROM dbo.MovDeduccion
DELETE FROM dbo.MovHoras
DELETE FROM dbo.MovPlanilla
DELETE FROM dbo.Asistencia
DELETE FROM dbo.HorarioJornada
DELETE FROM dbo.DeduccionMensual
DELETE FROM dbo.PlanillaSemanal
DELETE FROM dbo.PlanillaMensual
DELETE FROM dbo.EmpXTipoDeduccionFija
DELETE FROM dbo.EmpXTipoDeduccionPorcentual
DELETE FROM dbo.Semana
DELETE FROM dbo.Mes
DELETE FROM dbo.Empleado
DELETE FROM dbo.Usuario WHERE (Tipo = 2)
DELETE FROM dbo.DBError

DECLARE @xml XML
DECLARE @outResultCode INT
DECLARE @FechaOperacion DATETIME
DECLARE @FechaStr VARCHAR(10)
DECLARE @ValorDocumento VARCHAR(20)
DECLARE @Nombre VARCHAR(100)
DECLARE @Puesto VARCHAR(100)
DECLARE @CuentaBancaria VARCHAR(30)
DECLARE @FechaContratacion DATETIME
DECLARE @Username VARCHAR(50)
DECLARE @Password VARCHAR(255)
DECLARE @TipoDeduccion VARCHAR(100)
DECLARE @MontoFijo MONEY
DECLARE @Jornada VARCHAR(50)
DECLARE @InicioSemana DATETIME
DECLARE @HoraEntrada DATETIME
DECLARE @HoraSalida DATETIME

DECLARE @Fechas TABLE (
    Fecha DATETIME
    ,Procesada BIT DEFAULT 0
)

DECLARE @InsertarEmpleados TABLE (
    ValorDocumento VARCHAR(20)
    ,Nombre VARCHAR(100)
    ,Puesto VARCHAR(100)
    ,CuentaBancaria VARCHAR(30)
    ,FechaContratacion DATETIME
    ,Username VARCHAR(50)
    ,Password VARCHAR(255)
)

DECLARE @EliminarEmpleados TABLE (
    ValorDocumento VARCHAR(20)
)

DECLARE @AsociarDeducciones TABLE (
    ValorDocumento VARCHAR(20)
    ,TipoDeduccion VARCHAR(100)
    ,MontoFijo MONEY
)

DECLARE @DesasociarDeducciones TABLE (
    ValorDocumento VARCHAR(20)
    ,TipoDeduccion VARCHAR(100)
)

DECLARE @AsignarJornadas TABLE (
    ValorDocumento VARCHAR(20)
    ,Jornada VARCHAR(50)
    ,InicioSemana DATETIME
)

DECLARE @MarcasAsistencia TABLE (
    ValorDocumento VARCHAR(20)
    ,HoraEntrada DATETIME
    ,HoraSalida DATETIME
)

SELECT @xml = BulkColumn
FROM OPENROWSET(BULK 'C:\Users\Usuario\Desktop\BD1\Tarea3\Operaciones.xml', SINGLE_BLOB) AS x

--Lee las fechas del XML y las inserta en la tabla @Fechas
INSERT INTO @Fechas (Fecha)
SELECT DISTINCT
    CAST(nodo.value('@Fecha', 'VARCHAR(20)') AS DATETIME) AS Fecha
FROM @xml.nodes('/Operaciones/FechaOperacion') AS T(nodo)
ORDER BY Fecha ASC

--Itera por cada fecha y procesa las operaciones correspondientes
WHILE EXISTS (SELECT 1 FROM @Fechas WHERE (Procesada = 0))
BEGIN
    SELECT TOP 1 @FechaOperacion = f.Fecha
    FROM @Fechas AS f
    WHERE (f.Procesada = 0)
    ORDER BY f.Fecha ASC

    SET @FechaStr = CONVERT(VARCHAR(10), @FechaOperacion, 120)

    PRINT 'Procesando: ' + @FechaStr

    DELETE FROM @InsertarEmpleados
    DELETE FROM @EliminarEmpleados
    DELETE FROM @AsociarDeducciones
    DELETE FROM @DesasociarDeducciones
    DELETE FROM @AsignarJornadas
    DELETE FROM @MarcasAsistencia
    INSERT INTO @InsertarEmpleados (ValorDocumento, Nombre, Puesto, CuentaBancaria, FechaContratacion, Username, Password)
    SELECT
        nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
        ,nodo.value('@Nombre', 'VARCHAR(100)')
        ,nodo.value('@Puesto', 'VARCHAR(100)')
        ,nodo.value('@CuentaBancaria', 'VARCHAR(30)')
        ,ISNULL(
            NULLIF(nodo.value('@FechaContratacion', 'VARCHAR(20)'), '')
            ,@FechaStr
        )
        ,nodo.value('@Username', 'VARCHAR(50)')
        ,nodo.value('@Password', 'VARCHAR(255)')
    FROM @xml.nodes('/Operaciones/FechaOperacion') AS T1(fecha_nodo)
    CROSS APPLY fecha_nodo.nodes('InsertarEmpleado') AS T2(nodo)
    WHERE (fecha_nodo.value('@Fecha', 'VARCHAR(20)') = @FechaStr)

    INSERT INTO @EliminarEmpleados (ValorDocumento)
    SELECT
        nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
    FROM @xml.nodes('/Operaciones/FechaOperacion') AS T1(fecha_nodo)
    CROSS APPLY fecha_nodo.nodes('EliminarEmpleado') AS T2(nodo)
    WHERE (fecha_nodo.value('@Fecha', 'VARCHAR(20)') = @FechaStr)

    INSERT INTO @AsociarDeducciones (ValorDocumento, TipoDeduccion, MontoFijo)
    SELECT
        nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
        ,nodo.value('@TipoDeduccion', 'VARCHAR(100)')
        ,nodo.value('@MontoFijo', 'MONEY')
    FROM @xml.nodes('/Operaciones/FechaOperacion') AS T1(fecha_nodo)
    CROSS APPLY fecha_nodo.nodes('AsociaEmpleadoConDeduccion') AS T2(nodo)
    WHERE (fecha_nodo.value('@Fecha', 'VARCHAR(20)') = @FechaStr)

    INSERT INTO @DesasociarDeducciones (ValorDocumento, TipoDeduccion)
    SELECT
        nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
        ,nodo.value('@TipoDeduccion', 'VARCHAR(100)')
    FROM @xml.nodes('/Operaciones/FechaOperacion') AS T1(fecha_nodo)
    CROSS APPLY fecha_nodo.nodes('DesasociaEmpleadoConDeduccion') AS T2(nodo)
    WHERE (fecha_nodo.value('@Fecha', 'VARCHAR(20)') = @FechaStr)

    INSERT INTO @AsignarJornadas (ValorDocumento, Jornada, InicioSemana)
    SELECT
        nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
        ,nodo.value('@Jornada', 'VARCHAR(50)')
        ,CAST(nodo.value('@InicioSemana', 'VARCHAR(20)') AS DATETIME)
    FROM @xml.nodes('/Operaciones/FechaOperacion') AS T1(fecha_nodo)
    CROSS APPLY fecha_nodo.nodes('AsignarJornada') AS T2(nodo)
    WHERE (fecha_nodo.value('@Fecha', 'VARCHAR(20)') = @FechaStr)

    INSERT INTO @MarcasAsistencia (ValorDocumento, HoraEntrada, HoraSalida)
    SELECT
        nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(20)')
        ,CAST(nodo.value('@HoraEntrada', 'VARCHAR(20)') AS DATETIME)
        ,CAST(nodo.value('@HoraSalida', 'VARCHAR(20)') AS DATETIME)
    FROM @xml.nodes('/Operaciones/FechaOperacion') AS T1(fecha_nodo)
    CROSS APPLY fecha_nodo.nodes('MarcaAsistencia') AS T2(nodo)
    WHERE (fecha_nodo.value('@Fecha', 'VARCHAR(20)') = @FechaStr)
    
    --Fin de la carga de datos para la fecha actual, ahora se procesan las operaciones
    WHILE EXISTS (SELECT 1 FROM @InsertarEmpleados)
    BEGIN
        SELECT TOP 1
            @ValorDocumento = ie.ValorDocumento
            ,@Nombre = ie.Nombre
            ,@Puesto = ie.Puesto
            ,@CuentaBancaria = ie.CuentaBancaria
            ,@FechaContratacion = ie.FechaContratacion
            ,@Username = ie.Username
            ,@Password = ie.Password
        FROM @InsertarEmpleados AS ie

        EXEC dbo.procInsertarEmpleado
            @ValorDocumento
            ,@Nombre
            ,@Puesto
            ,@CuentaBancaria
            ,@FechaContratacion
            ,@Username
            ,@Password
            ,@outResultCode OUTPUT

        PRINT 'InsertarEmpleado: ' + @ValorDocumento + ' ResultCode: ' + CAST(@outResultCode AS VARCHAR)

        DELETE FROM @InsertarEmpleados
        WHERE (ValorDocumento = @ValorDocumento)
    END

    WHILE EXISTS (SELECT 1 FROM @EliminarEmpleados)
    BEGIN
        SELECT TOP 1 @ValorDocumento = ee.ValorDocumento
        FROM @EliminarEmpleados AS ee

        EXEC dbo.procEliminarEmpleado
            @ValorDocumento
            ,@outResultCode OUTPUT

        PRINT 'EliminarEmpleado: ' + @ValorDocumento + ' ResultCode: ' + CAST(@outResultCode AS VARCHAR)

        DELETE FROM @EliminarEmpleados
        WHERE (ValorDocumento = @ValorDocumento)
    END

    WHILE EXISTS (SELECT 1 FROM @AsociarDeducciones)
    BEGIN
        SELECT TOP 1
            @ValorDocumento = ad.ValorDocumento
            ,@TipoDeduccion = ad.TipoDeduccion
            ,@MontoFijo = ad.MontoFijo
        FROM @AsociarDeducciones AS ad

        EXEC dbo.procAsociarDeduccion
            @ValorDocumento
            ,@TipoDeduccion
            ,@MontoFijo
            ,@FechaOperacion
            ,@outResultCode OUTPUT

        PRINT 'AsociarDeduccion: ' + @ValorDocumento + ' ResultCode: ' + CAST(@outResultCode AS VARCHAR)

        DELETE FROM @AsociarDeducciones
        WHERE (ValorDocumento = @ValorDocumento)
    END

    WHILE EXISTS (SELECT 1 FROM @DesasociarDeducciones)
    BEGIN
        SELECT TOP 1
            @ValorDocumento = dd.ValorDocumento
            ,@TipoDeduccion = dd.TipoDeduccion
        FROM @DesasociarDeducciones AS dd

        EXEC dbo.procDesasociarDeduccion
            @ValorDocumento
            ,@TipoDeduccion
            ,@FechaOperacion
            ,@outResultCode OUTPUT

        PRINT 'DesasociarDeduccion: ' + @ValorDocumento + ' ResultCode: ' + CAST(@outResultCode AS VARCHAR)

        DELETE FROM @DesasociarDeducciones
        WHERE (ValorDocumento = @ValorDocumento)
    END

    WHILE EXISTS (SELECT 1 FROM @MarcasAsistencia)
    BEGIN
        SELECT TOP 1
            @ValorDocumento = ma.ValorDocumento
            ,@HoraEntrada = ma.HoraEntrada
            ,@HoraSalida = ma.HoraSalida
        FROM @MarcasAsistencia AS ma

        EXEC dbo.procProcesarAsistencia
            @ValorDocumento
            ,@HoraEntrada
            ,@HoraSalida
            ,@FechaOperacion
            ,@outResultCode OUTPUT

        PRINT 'ProcesarAsistencia: ' + @ValorDocumento + ' ResultCode: ' + CAST(@outResultCode AS VARCHAR)

        DELETE FROM @MarcasAsistencia
        WHERE (ValorDocumento = @ValorDocumento)
    END

    --Si la fecha de operacion es jueves, se ejecutan los procedimientos de cierre de semana
    IF (DATEPART(WEEKDAY, @FechaOperacion) = 5)
    BEGIN
        EXEC dbo.procCierreSemana
            @FechaOperacion
            ,@outResultCode OUTPUT

        PRINT 'CierreSemana ResultCode: ' + CAST(@outResultCode AS VARCHAR)

        EXEC dbo.procCrearMesYSemana
            @FechaOperacion
            ,@outResultCode OUTPUT

        PRINT 'CrearMesYSemana ResultCode: ' + CAST(@outResultCode AS VARCHAR)

        WHILE EXISTS (SELECT 1 FROM @AsignarJornadas)
        BEGIN
            SELECT TOP 1
                @ValorDocumento = aj.ValorDocumento
                ,@Jornada = aj.Jornada
                ,@InicioSemana = aj.InicioSemana
            FROM @AsignarJornadas AS aj

            EXEC dbo.procAsignarJornada
                @ValorDocumento
                ,@Jornada
                ,@InicioSemana
                ,@outResultCode OUTPUT

            PRINT 'AsignarJornada: ' + @ValorDocumento + ' ResultCode: ' + CAST(@outResultCode AS VARCHAR)

            DELETE FROM @AsignarJornadas
            WHERE (ValorDocumento = @ValorDocumento)
        END
    END

    UPDATE @Fechas
    SET Procesada = 1
    WHERE (Fecha = @FechaOperacion)

END