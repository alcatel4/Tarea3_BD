-- Recibe un idEmpleado, retorna todas sus planillas mensuales.
-- Es el grid del tab Planilla Mensual en R05.

CREATE PROCEDURE dbo.procConsultarPlanillasMensual
    @inIdEmpleado INT
    ,@inUsername VARCHAR(64)
    ,@inPostInIP VARCHAR(64)
    ,@outResultCode INT OUTPUT

AS
BEGIN

    SET NOCOUNT ON
    SET @outResultCode = 0

    DECLARE @idUsuario INT
    DECLARE @fechaInicio DATETIME
    DECLARE @fechaFin DATETIME

    BEGIN TRY

        SELECT @idUsuario = u.id
        FROM dbo.Usuario u
        WHERE (u.UserName = @inUsername)

        SELECT
            @fechaInicio = MIN(m.FechaInicio)
            ,@fechaFin = MAX(m.FechaFin)
        FROM dbo.PlanillaMensual pm
        INNER JOIN dbo.Mes m ON (m.id = pm.idMes)
        WHERE (pm.idEmpleado = @inIdEmpleado)

        SELECT
            pm.id AS idMes
            ,CONVERT(VARCHAR(16), m.FechaInicio, 103) AS FechaInicio
            ,CONVERT(VARCHAR(16), m.FechaFin, 103) AS FechaFin
            ,pm.SalarioBruto
            ,pm.TotalDeducciones
            ,pm.SalarioNeto
        FROM dbo.PlanillaMensual pm
        INNER JOIN dbo.Mes m ON (m.id = pm.idMes)
        WHERE (pm.idEmpleado = @inIdEmpleado)
        ORDER BY m.FechaInicio DESC

        BEGIN TRANSACTION

            INSERT INTO dbo.BitacoraEvento (
                IpPostIn
                ,PostTime
                ,Descripcion
                ,idUsuario
                ,idTipoEvento
            )
            VALUES (
                @inPostInIP
                ,GETDATE()
                ,'{"idEmpleado": ' + CAST(@inIdEmpleado AS VARCHAR(16))
                    + ', "FechaInicio": "' + CONVERT(VARCHAR(16), @fechaInicio, 103)
                    + '", "FechaFin": "' + CONVERT(VARCHAR(16), @fechaFin, 103) + '"}'
                ,@idUsuario
                ,21
            )

        COMMIT TRANSACTION

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION

        SET @outResultCode = 50008

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
            @inUsername
            ,ERROR_NUMBER()
            ,ERROR_STATE()
            ,ERROR_SEVERITY()
            ,ERROR_LINE()
            ,ERROR_PROCEDURE()
            ,ERROR_MESSAGE()
            ,GETDATE()
        )

    END CATCH
END