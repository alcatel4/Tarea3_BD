CREATE PROCEDURE dbo.procAsignarJornada
    @inValorDocumentoIdentidad VARCHAR(20)
    ,@inJornada VARCHAR(50)
    ,@inInicioSemana DATETIME
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdEmpleado INT
    DECLARE @IdTipoJornada INT
    DECLARE @IdPlanillaSemanal INT

    SET @outResultCode = 0

    BEGIN TRY

        SELECT @IdEmpleado = e.id
        FROM dbo.Empleado AS e
        WHERE (e.DocumentoIdentidad = @inValorDocumentoIdentidad)

        IF (@IdEmpleado IS NULL)
        BEGIN
            SET @outResultCode = 50012
            RETURN
        END

        SELECT @IdTipoJornada = tj.id
        FROM dbo.TipoJornada AS tj
        WHERE (tj.Nombre = @inJornada)

        SELECT @IdPlanillaSemanal = ps.id
        FROM dbo.PlanillaSemanal AS ps
        INNER JOIN dbo.Semana AS s ON (s.id = ps.idSemana)
        WHERE (ps.idEmpleado  = @IdEmpleado)
            AND (s.FechaInicio = @inInicioSemana)

        BEGIN TRANSACTION

            INSERT INTO dbo.HorarioJornada (
                idPlanillaSemanal
                ,idTipoJornada
            )
            VALUES (
                @IdPlanillaSemanal
                ,@IdTipoJornada
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
            @inValorDocumentoIdentidad
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