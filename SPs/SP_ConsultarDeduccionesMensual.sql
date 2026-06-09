-- Recibe un idPlanillaMensual, retorna todas las deducciones acumuladas de ese mes.
-- Es el que aparece al clickear el total de deducciones en R05.

CREATE PROCEDURE dbo.procDeduccionesMensual
    @inIdPlanillaMensual INT
    ,@inUsername         VARCHAR(64)
    ,@inPostInIP         VARCHAR(64)
    ,@outResultCode      INT OUTPUT

AS
BEGIN

    SET NOCOUNT ON
    SET @outResultCode = 0

    DECLARE @idUsuario   INT
    DECLARE @idEmpleado  INT
    DECLARE @fechaInicio DATETIME
    DECLARE @fechaFin    DATETIME

    BEGIN TRY

        SELECT @idUsuario = u.id
        FROM dbo.Usuario u
        WHERE (u.UserName = @inUsername)

        SELECT
            @idEmpleado  = pm.idEmpleado
            ,@fechaInicio = m.FechaInicio
            ,@fechaFin    = m.FechaFin
        FROM dbo.PlanillaMensual pm
        INNER JOIN dbo.Mes m ON (m.id = pm.idMes)
        WHERE (pm.id = @inIdPlanillaMensual)

        SELECT
            td.Nombre AS NombreDeduccion
            ,CASE
                WHEN td.FlagPorcentual = 1
                    THEN CAST(td.Porcentaje * 100 AS VARCHAR(16))
                ELSE
                    NULL
             END AS Porcentaje
            ,dm.Monto AS Monto
        FROM dbo.DeduccionMensual dm
        INNER JOIN dbo.TipoDeduccion td ON (td.id = dm.idTipoDeduccion)
        WHERE (dm.idPlanillaMensual = @inIdPlanillaMensual)
        ORDER BY td.Nombre ASC

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
                ,'{"idEmpleado": ' + CAST(@idEmpleado AS VARCHAR(16))
                    + ', "FechaInicio": "' + CONVERT(VARCHAR(16), @fechaInicio, 103)
                    + '", "FechaFin": "'   + CONVERT(VARCHAR(16), @fechaFin,    103) + '"}'
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