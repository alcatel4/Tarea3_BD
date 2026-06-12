CREATE PROCEDURE dbo.procCierreSemana
    @inFechaOperacion DATETIME
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdUsuarioSistema INT
    DECLARE @IdEmpleado INT
    DECLARE @IdPlanillaSemanal INT
    DECLARE @IdPlanillaMensual INT
    DECLARE @SalarioBruto MONEY
    DECLARE @TotalDeducciones MONEY
    DECLARE @SalarioNeto MONEY
    DECLARE @MontoDeducciones MONEY
    DECLARE @Porcentaje DECIMAL(6,4)
    DECLARE @IdTipoDeduccion INT
    DECLARE @CantSemanas TINYINT
    DECLARE @Descripcion VARCHAR(256)

    -- Tabla variable para iterar empleados
    DECLARE @Empleados TABLE (
        id INT
        ,IdPlanillaSemanal INT
        ,IdPlanillaMensual INT
        ,SalarioBruto MONEY
    )

    -- Tabla variable para iterar deducciones de cada empleado
    DECLARE @Deducciones TABLE (
        IdTipoDeduccion INT
        ,Monto MONEY
        ,EsPorcentual BIT
    )

    SET @outResultCode = 0

    BEGIN TRY

        SELECT @IdUsuarioSistema = u.id
        FROM dbo.Usuario AS u
        WHERE (u.Tipo = 1)

        -- Obtener cantidad de semanas del mes actual
        SELECT @CantSemanas = m.CantSemanas
        FROM dbo.Mes AS m
        INNER JOIN dbo.Semana AS s ON (s.idMes = m.id)
        WHERE (s.FechaInicio <= @inFechaOperacion)
            AND (s.FechaFin >= @inFechaOperacion)

        -- Cargar empleados activos con su planilla semanal y mensual
        INSERT INTO @Empleados (id, IdPlanillaSemanal, IdPlanillaMensual, SalarioBruto)
        SELECT e.id
            ,ps.id
            ,ps.idPlanillaMensual
            ,ps.SalarioBruto
        FROM dbo.Empleado AS e
        INNER JOIN dbo.PlanillaSemanal AS ps ON (ps.idEmpleado = e.id)
        INNER JOIN dbo.Semana AS s ON (s.id = ps.idSemana)
        WHERE (s.FechaInicio <= @inFechaOperacion)
            AND (s.FechaFin >= @inFechaOperacion)

        BEGIN TRANSACTION

            -- Iterar sobre cada empleado
            WHILE EXISTS (SELECT 1 FROM @Empleados)
            BEGIN
                -- Tomar primer empleado
                SELECT TOP 1
                    @IdEmpleado = e.id
                    ,@IdPlanillaSemanal = e.IdPlanillaSemanal
                    ,@IdPlanillaMensual = e.IdPlanillaMensual
                    ,@SalarioBruto = e.SalarioBruto
                FROM @Empleados AS e

                SET @TotalDeducciones = 0

                -- Limpiar deducciones del empleado anterior
                DELETE FROM @Deducciones

                -- Cargar deducciones porcentuales vigentes del empleado
                INSERT INTO @Deducciones (IdTipoDeduccion, Monto, EsPorcentual)
                SELECT ep.idTipoDeduccion
                    ,@SalarioBruto * ep.Porcentaje
                    ,1
                FROM dbo.EmpXTipoDeduccionPorcentual AS ep
                WHERE (ep.idEmpleado = @IdEmpleado)
                    AND (ep.FechaInicio <= @inFechaOperacion)
                    AND (ep.FechaFin >= @inFechaOperacion)

                -- Cargar deducciones fijas vigentes del empleado
                INSERT INTO @Deducciones (IdTipoDeduccion, Monto, EsPorcentual)
                SELECT ef.idTipoDeduccion
                    ,ef.Monto / @CantSemanas
                    ,0
                FROM dbo.EmpXTipoDeduccionFija AS ef
                WHERE (ef.idEmpleado = @IdEmpleado)
                    AND (ef.FechaInicio <= @inFechaOperacion)
                    AND (ef.FechaFin >= @inFechaOperacion)

                -- Insertar movimientos de deduccion y acumular total
                INSERT INTO dbo.MovPlanilla (
                    Fecha
                    ,Monto
                    ,NuevoSaldo
                    ,idPlanillaSemanal
                    ,idTipoMov
                )
                SELECT @inFechaOperacion
                    ,d.Monto
                    ,0
                    ,@IdPlanillaSemanal
                    ,(SELECT td.idTipoMov FROM dbo.TipoDeduccion AS td WHERE (td.id = d.IdTipoDeduccion))
                FROM @Deducciones AS d

                -- Acumular total deducciones
                SELECT @TotalDeducciones = SUM(d.Monto)
                FROM @Deducciones AS d

                -- Calcular salario neto
                SET @SalarioNeto = @SalarioBruto - @TotalDeducciones

                -- Actualizar planilla semanal
                UPDATE dbo.PlanillaSemanal
                SET TotalDeducciones = @TotalDeducciones
                    ,SalarioNeto = @SalarioNeto
                WHERE (id = @IdPlanillaSemanal)

                -- Acumular en planilla mensual
                UPDATE dbo.PlanillaMensual
                SET SalarioBruto = SalarioBruto + @SalarioBruto
                    ,TotalDeducciones = TotalDeducciones + @TotalDeducciones
                    ,SalarioNeto = SalarioNeto + @SalarioNeto
                WHERE (id = @IdPlanillaMensual)

                -- Eliminar empleado procesado de la tabla variable
                DELETE TOP (1) FROM @Empleados

            END

            -- Registrar evento en bitacora
            SET @Descripcion = '{"FechaCierre":"' + CAST(@inFechaOperacion AS VARCHAR) + '"}'

            INSERT INTO dbo.BitacoraEvento (
                idTipoEvento
                ,IpPostIn
                ,PostTime
                ,Descripcion
                ,idUsuario
            )
            VALUES (
                14
                ,'127.0.0.1'
                ,GETDATE()
                ,@Descripcion
                ,@IdUsuarioSistema
            )

        COMMIT TRANSACTION

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
            ROLLBACK TRANSACTION

        INSERT INTO dbo.DBError (
            UserName
            ,Number
            ,State
            ,Severity
            ,Line
            ,[Procedure]
            ,Message
            ,DateTime
        )
        VALUES (
            SYSTEM_USER
            ,ERROR_NUMBER()
            ,ERROR_STATE()
            ,ERROR_SEVERITY()
            ,ERROR_LINE()
            ,ERROR_PROCEDURE()
            ,ERROR_MESSAGE()
            ,GETDATE()
        )

        SET @outResultCode = 50008

    END CATCH
END