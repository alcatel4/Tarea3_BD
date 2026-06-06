CREATE PROCEDURE dbo.procConsultarPlanillasSemanal
    @inIdEmpleado INT
    ,@inUsername VARCHAR(64) -- Username del usuario que intenta hacer la inserción
    ,@inPostInIP VARCHAR(64) -- IP del usuario que intenta hacer la inserción
    ,@outResultCode INT OUTPUT

AS
BEGIN

    SET NOCOUNT ON
    SET @outResultCode = 0

    DECLARE @idUsuario INT
    DECLARE @fechaInicio DATETIME
    DECLARE @fechaFin DATETIME

    BEGIN TRY

        -- Obtener id del usuario para la bitácora
        SELECT @idUsuario = u.id
        FROM dbo.Usuario u
        WHERE (u.UserName = @inUsername)

        -- Obtener datos de la semana para la bitácora
        SELECT
            @fechaInicio = MIN(s.FechaInicio)
            ,@fechaFin = MAX(s.FechaFin)
        FROM dbo.PlanillaSemanal ps
        INNER JOIN dbo.Semana s ON (s.id = ps.idSemana)
        WHERE (ps.idEmpleado = @inIdEmpleado)

        -- Consulta principal para obtener las planillas semanales del empleado
        SELECT
            ps.id AS idSemana
            ,CONVERT(VARCHAR(16), s.FechaInicio, 103) AS FechaInicio -- 103 para que se muestre DD/MM/YYYY
            ,CONVERT(VARCHAR(16), s.FechaFin, 103) AS FechaFin
            ,ps.SalarioBruto
            ,ps.TotalDeducciones
            ,ps.SalarioNeto
            ,ISNULL(SUM(CASE WHEN mp.idTipoMov = 1 
                        THEN mh.QHoras 
                        ELSE 0 
                        END), 0) AS HorasOrdinarias
            ,ISNULL(SUM(CASE WHEN mp.idTipoMov = 2 
                        THEN mh.QHoras 
                        ELSE 0 
                        END), 0) AS HorasExtraNormal
            ,ISNULL(SUM(CASE WHEN mp.idTipoMov = 3 
                        THEN mh.QHoras 
                        ELSE 0 
                        END), 0) AS HorasExtraDoble
        FROM dbo.PlanillaSemanal ps
        INNER JOIN dbo.Semana s ON (s.id = ps.idSemana)
        LEFT JOIN dbo.MovPlanilla mp ON (mp.idPlanillaSemanal = ps.id)
        LEFT JOIN dbo.MovHoras mh ON (mh.idMovPlanilla = mp.id)
        WHERE (ps.idEmpleado = @inIdEmpleado)
        GROUP BY
            ps.id
            ,s.FechaInicio
            ,s.FechaFin
            ,ps.SalarioBruto
            ,ps.TotalDeducciones
            ,ps.SalarioNeto
        ORDER BY s.FechaInicio DESC

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