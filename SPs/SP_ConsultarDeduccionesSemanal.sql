-- Recibe un idPlanillaSemanal, retorna todas las deducciones de esa semana: nombre, porcentaje (si aplica) y monto
-- Es el modal que aparece al clickear el total de deducciones en R04.

CREATE PROCEDURE dbo.procDeduccionesSemanal
    @inIdPlanillaSemanal INT
    ,@inUsername VARCHAR(64)
    ,@inPostInIP VARCHAR(64)
    ,@outResultCode INT OUTPUT

AS
BEGIN

    SET NOCOUNT ON
    SET @outResultCode = 0

    DECLARE @idUsuario INT
    DECLARE @idEmpleado INT
    DECLARE @fechaInicio DATETIME
    DECLARE @fechaFin DATETIME

    BEGIN TRY

        SELECT @idUsuario = u.id
        FROM dbo.Usuario u
        WHERE (u.UserName = @inUsername)

        SELECT @idEmpleado = ps.idEmpleado
            ,@fechaInicio = s.FechaInicio
            ,@fechaFin = s.FechaFin
        FROM dbo.PlanillaSemanal ps
        INNER JOIN dbo.Semana s ON (s.id = ps.idSemana)
        WHERE (ps.id = @inIdPlanillaSemanal)

        SELECT
            td.Nombre AS NombreDeduccion
            ,CASE
                WHEN td.FlagPorcentual = 1
                    THEN CAST(td.Porcentaje * 100 AS VARCHAR(16))
                ELSE 
                    NULL
             END AS Porcentaje
            ,mp.Monto AS Monto
        FROM dbo.PlanillaSemanal ps
        INNER JOIN dbo.MovPlanilla mp ON (mp.idPlanillaSemanal = ps.id)
        INNER JOIN dbo.MovDeduccion md ON (md.idMovPlanilla = mp.id)
        INNER JOIN dbo.TipoDeduccion td ON (td.id = md.idTipoDeduccion)
        WHERE (ps.id = @inIdPlanillaSemanal)
            AND (mp.idTipoMov IN (5, 6, 7, 8))
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
                    + '", "FechaFin": "' + CONVERT(VARCHAR(16), @fechaFin, 103) + '"}'
                ,@idUsuario
                ,20
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