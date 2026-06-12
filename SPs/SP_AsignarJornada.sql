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
    DECLARE @IdUsuarioSistema INT
    DECLARE @Descripcion VARCHAR(256)

    SET @outResultCode = 0

    BEGIN TRY

        SELECT @IdUsuarioSistema = u.id
        FROM dbo.Usuario AS u
        WHERE (u.Tipo = 1)

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
        WHERE (ps.idEmpleado = @IdEmpleado)
            AND (s.FechaInicio = @inInicioSemana)

        SET @Descripcion = '{"Empleado":"' + @inValorDocumentoIdentidad +
            '","Jornada":"' + @inJornada +
            '","InicioSemana":"' + CAST(@inInicioSemana AS VARCHAR) + '"}'

        BEGIN TRANSACTION

            INSERT INTO dbo.HorarioJornada (
                idPlanillaSemanal
                ,idTipoJornada
            )
            VALUES (
                @IdPlanillaSemanal
                ,@IdTipoJornada
            )

            INSERT INTO dbo.BitacoraEvento (
                idTipoEvento
                ,IpPostIn
                ,PostTime
                ,Descripcion
                ,idUsuario
            )
            VALUES (
                23
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