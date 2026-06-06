-- Recibe un idSemana, retorna por cada día: fecha, hora entrada, hora salida, tipo de movimiento y monto. 
-- Es el modal que aparece al clickear el salario bruto

CREATE PROCEDURE dbo.procDetalleSemanal
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

        -- Obtener id del usuario para la bitácora
        SELECT @idUsuario = u.id
        FROM dbo.Usuario u
        WHERE (u.UserName = @inUsername)

        -- Obtener datos de la semana para la bitácora
        SELECT
            @idEmpleado = ps.idEmpleado
            ,@fechaInicio = s.FechaInicio
            ,@fechaFin = s.FechaFin
        FROM dbo.PlanillaSemanal ps
        INNER JOIN dbo.Semana s ON (s.id = ps.idSemana)
        WHERE (ps.id = @inIdPlanillaSemanal)

        -- Detalle por día
        SELECT
            CONVERT(VARCHAR(16), a.Fecha, 103) AS Fecha
            ,CONVERT(VARCHAR(8), a.MarcaInicio, 108) AS HoraEntrada -- resultado: HH:MM:SS ejemplo: "14:30:00"
            ,CONVERT(VARCHAR(8), a.MarcaFin, 108) AS HoraSalida 
            ,tm.Nombre AS TipoMovimiento
            ,mh.QHoras AS QHoras
            ,mp.Monto AS Monto
        FROM dbo.PlanillaSemanal ps
        INNER JOIN dbo.MovPlanilla mp ON (mp.idPlanillaSemanal = ps.id)
        INNER JOIN dbo.MovHoras mh ON (mh.idMovPlanilla = mp.id)
        INNER JOIN dbo.Asistencia a ON (a.id = mh.idAsistencia)
        INNER JOIN dbo.TipoMov tm ON (tm.id = mp.idTipoMov)
        WHERE (ps.id = @inIdPlanillaSemanal)
            AND (tm.Accion = 'C')
        ORDER BY
            a.Fecha ASC
            ,mp.idTipoMov ASC -- Segundo criterio en caso de que la fecha se repita (ejemplo: horas normales y horas extra en el mismo día)

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