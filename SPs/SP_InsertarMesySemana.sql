CREATE PROCEDURE dbo.procCrearMesYSemana
    @inFechaJueves DATETIME
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @FechaInicioSemana DATETIME
    DECLARE @FechaFinSemana DATETIME
    DECLARE @IdMes INT
    DECLARE @IdSemana INT
    DECLARE @IdEmpleado INT
    DECLARE @IdPlanillaMensual INT
    DECLARE @FechaInicioMes DATETIME
    DECLARE @FechaFinMes DATETIME
    DECLARE @CantSemanas TINYINT
    DECLARE @flagNuevoMes BIT
    DECLARE @FechaTemp DATETIME
    DECLARE @ContJueves INT
    DECLARE @UltimoJuevesDelMes DATETIME

    DECLARE @Empleados TABLE (
        id INT
    )

    SET @outResultCode = 0
    SET @flagNuevoMes = 0

    BEGIN TRY

        -- La semana nueva inicia el viernes siguiente al jueves de operacion
        SET @FechaInicioSemana = DATEADD(DAY, 1, @inFechaJueves)
        SET @FechaFinSemana = DATEADD(DAY, 7, @inFechaJueves)

        -- Si el viernes es el primer viernes del mes hay que crear un nuevo mes
        IF (DAY(@FechaInicioSemana) <= 7)
            SET @flagNuevoMes = 1

        -- Contar jueves del mes que inicia el viernes siguiente
        SET @FechaTemp = @FechaInicioSemana
        SET @ContJueves = 0

        WHILE (MONTH(@FechaTemp) = MONTH(@FechaInicioSemana))
        BEGIN
            IF (DATEPART(WEEKDAY, @FechaTemp) = 5)
            BEGIN
                SET @ContJueves = @ContJueves + 1
                SET @UltimoJuevesDelMes = @FechaTemp
            END
            SET @FechaTemp = DATEADD(DAY, 1, @FechaTemp)
        END

        SET @CantSemanas = @ContJueves
        SET @FechaFinMes = @UltimoJuevesDelMes

        -- Cargar empleados activos
        INSERT INTO @Empleados (id)
        SELECT e.id
        FROM dbo.Empleado AS e

        BEGIN TRANSACTION

            IF (@flagNuevoMes = 1)
            BEGIN
                INSERT INTO dbo.Mes (
                    FechaInicio
                    ,FechaFin
                    ,CantSemanas
                )
                VALUES (
                    @FechaInicioSemana
                    ,@FechaFinMes
                    ,@CantSemanas
                )

                SET @IdMes = SCOPE_IDENTITY()

                -- Crear PlanillaMensual para cada empleado
                WHILE EXISTS (SELECT 1 FROM @Empleados)
                BEGIN
                    SELECT TOP 1 @IdEmpleado = e.id
                    FROM @Empleados AS e

                    INSERT INTO dbo.PlanillaMensual (
                        SalarioBruto
                        ,TotalDeducciones
                        ,SalarioNeto
                        ,idEmpleado
                        ,idMes
                    )
                    VALUES (
                        0
                        ,0
                        ,0
                        ,@IdEmpleado
                        ,@IdMes
                    )

                    DELETE FROM @Empleados
                    WHERE (id = @IdEmpleado)
                END
            END
            ELSE
            BEGIN
                SELECT @IdMes = m.id
                FROM dbo.Mes AS m
                WHERE (m.FechaInicio <= @FechaInicioSemana)
                    AND (m.FechaFin >= @FechaInicioSemana)
            END

            -- Crear semana
            INSERT INTO dbo.Semana (
                FechaInicio
                ,FechaFin
                ,idMes
            )
            VALUES (
                @FechaInicioSemana
                ,@FechaFinSemana
                ,@IdMes
            )

            SET @IdSemana = SCOPE_IDENTITY()

            -- Recargar empleados para crear PlanillaSemanal
            INSERT INTO @Empleados (id)
            SELECT e.id
            FROM dbo.Empleado AS e

            WHILE EXISTS (SELECT 1 FROM @Empleados)
            BEGIN
                SELECT TOP 1 @IdEmpleado = e.id
                FROM @Empleados AS e

                SELECT @IdPlanillaMensual = pm.id
                FROM dbo.PlanillaMensual AS pm
                WHERE (pm.idEmpleado = @IdEmpleado)
                    AND (pm.idMes = @IdMes)

                INSERT INTO dbo.PlanillaSemanal (
                    SalarioBruto
                    ,TotalDeducciones
                    ,SalarioNeto
                    ,idEmpleado
                    ,idSemana
                    ,idPlanillaMensual
                )
                VALUES (
                    0
                    ,0
                    ,0
                    ,@IdEmpleado
                    ,@IdSemana
                    ,@IdPlanillaMensual
                )

                DELETE FROM @Empleados
                WHERE (id = @IdEmpleado)
            END

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