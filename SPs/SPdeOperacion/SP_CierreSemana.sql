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
    DECLARE @IdMovPlanilla INT
    DECLARE @SalarioBruto MONEY
    DECLARE @TotalDeducciones MONEY
    DECLARE @SalarioNeto MONEY
    DECLARE @CantSemanas TINYINT
    DECLARE @Descripcion VARCHAR(256)
    DECLARE @IdTipoDeduccionActual INT
    DECLARE @MontoActual MONEY

    DECLARE @Empleados TABLE (
        id INT
        ,IdPlanillaSemanal INT
        ,IdPlanillaMensual INT
        ,SalarioBruto MONEY
    )

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

        SELECT @CantSemanas = m.CantSemanas
        FROM dbo.Mes AS m
        INNER JOIN dbo.Semana AS s ON (s.idMes = m.id)
        WHERE (s.FechaInicio <= @inFechaOperacion)
            AND (s.FechaFin >= @inFechaOperacion)

        IF (@CantSemanas IS NULL)
            SET @CantSemanas = 4

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

            WHILE EXISTS (SELECT 1 FROM @Empleados)
            BEGIN
                SELECT TOP 1
                    @IdEmpleado = e.id
                    ,@IdPlanillaSemanal = e.IdPlanillaSemanal
                    ,@IdPlanillaMensual = e.IdPlanillaMensual
                    ,@SalarioBruto = e.SalarioBruto
                FROM @Empleados AS e

                SET @TotalDeducciones = 0

                DELETE FROM @Deducciones

                INSERT INTO @Deducciones (IdTipoDeduccion, Monto, EsPorcentual)
                SELECT ep.idTipoDeduccion
                    ,@SalarioBruto * ep.Porcentaje
                    ,1
                FROM dbo.EmpXTipoDeduccionPorcentual AS ep
                WHERE (ep.idEmpleado = @IdEmpleado)
                    AND (ep.FechaInicio <= @inFechaOperacion)
                    AND (ep.FechaFin >= @inFechaOperacion)

                INSERT INTO @Deducciones (IdTipoDeduccion, Monto, EsPorcentual)
                SELECT ef.idTipoDeduccion
                    ,ef.Monto / @CantSemanas
                    ,0
                FROM dbo.EmpXTipoDeduccionFija AS ef
                WHERE (ef.idEmpleado = @IdEmpleado)
                    AND (ef.FechaInicio <= @inFechaOperacion)
                    AND (ef.FechaFin >= @inFechaOperacion)

                WHILE EXISTS (SELECT 1 FROM @Deducciones)
                BEGIN
                    SELECT TOP 1
                        @IdTipoDeduccionActual = d.IdTipoDeduccion
                        ,@MontoActual = d.Monto
                    FROM @Deducciones AS d

                    INSERT INTO dbo.MovPlanilla (
                        Fecha
                        ,Monto
                        ,NuevoSaldo
                        ,idPlanillaSemanal
                        ,idTipoMov
                    )
                    VALUES (
                        @inFechaOperacion
                        ,@MontoActual
                        ,0
                        ,@IdPlanillaSemanal
                        ,(SELECT td.idTipoMov FROM dbo.TipoDeduccion AS td WHERE (td.id = @IdTipoDeduccionActual))
                    )

                    SET @IdMovPlanilla = SCOPE_IDENTITY()

                    INSERT INTO dbo.MovDeduccion (
                        idMovPlanilla
                        ,idTipoDeduccion
                    )
                    VALUES (
                        @IdMovPlanilla
                        ,@IdTipoDeduccionActual
                    )

                    SET @TotalDeducciones = @TotalDeducciones + @MontoActual

                    IF NOT EXISTS (
                        SELECT 1
                        FROM dbo.DeduccionMensual AS dm
                        WHERE (dm.idPlanillaMensual = @IdPlanillaMensual)
                            AND (dm.idTipoDeduccion = @IdTipoDeduccionActual)
                    )
                    BEGIN
                        INSERT INTO dbo.DeduccionMensual (
                            Monto
                            ,idPlanillaMensual
                            ,idTipoDeduccion
                        )
                        VALUES (
                            @MontoActual
                            ,@IdPlanillaMensual
                            ,@IdTipoDeduccionActual
                        )
                    END
                    ELSE
                    BEGIN
                        UPDATE dbo.DeduccionMensual
                        SET Monto = Monto + @MontoActual
                        WHERE (idPlanillaMensual = @IdPlanillaMensual)
                            AND (idTipoDeduccion = @IdTipoDeduccionActual)
                    END

                    DELETE FROM @Deducciones
                    WHERE (IdTipoDeduccion = @IdTipoDeduccionActual)
                END

                SET @SalarioNeto = @SalarioBruto - @TotalDeducciones

                UPDATE dbo.PlanillaSemanal
                SET TotalDeducciones = @TotalDeducciones
                    ,SalarioNeto = @SalarioNeto
                WHERE (id = @IdPlanillaSemanal)

                UPDATE dbo.PlanillaMensual
                SET SalarioBruto = SalarioBruto + @SalarioBruto
                    ,TotalDeducciones = TotalDeducciones + @TotalDeducciones
                    ,SalarioNeto = SalarioNeto + @SalarioNeto
                WHERE (id = @IdPlanillaMensual)

                DELETE FROM @Empleados
                WHERE (id = @IdEmpleado)
            END

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