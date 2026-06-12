CREATE PROCEDURE dbo.procAsociarDeduccion
    @inValorDocumentoIdentidad VARCHAR(20)
    ,@inTipoDeduccion VARCHAR(100)
    ,@inMontoFijo MONEY
    ,@inFechaInicio DATETIME
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdEmpleado INT
    DECLARE @IdTipoDeduccion INT
    DECLARE @IdUsuarioSistema INT
    DECLARE @FlagPorcentual BIT
    DECLARE @Porcentaje DECIMAL(6,4)
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

        SELECT @IdTipoDeduccion = td.id
            ,@FlagPorcentual = td.FlagPorcentual
            ,@Porcentaje = td.Porcentaje
        FROM dbo.TipoDeduccion AS td
        WHERE (td.Nombre = @inTipoDeduccion)

        SET @Descripcion = '{"Empleado":"' + @inValorDocumentoIdentidad +
            '","TipoDeduccion":"' + @inTipoDeduccion +
            '","MontoFijo":"' + CAST(@inMontoFijo AS VARCHAR) + '"}'

        BEGIN TRANSACTION

            IF (@FlagPorcentual = 1)
            BEGIN
                INSERT INTO dbo.EmpXTipoDeduccionPorcentual (
                    FechaInicio
                    ,FechaFin
                    ,Porcentaje
                    ,idEmpleado
                    ,idTipoDeduccion
                )
                VALUES (
                    @inFechaInicio
                    ,'9999-12-31'
                    ,@Porcentaje
                    ,@IdEmpleado
                    ,@IdTipoDeduccion
                )
            END
            ELSE
            BEGIN
                INSERT INTO dbo.EmpXTipoDeduccionFija (
                    FechaInicio
                    ,FechaFin
                    ,Monto
                    ,idEmpleado
                    ,idTipoDeduccion
                )
                VALUES (
                    @inFechaInicio
                    ,'9999-12-31'
                    ,@inMontoFijo
                    ,@IdEmpleado
                    ,@IdTipoDeduccion
                )
            END

            INSERT INTO dbo.BitacoraEvento (
                idTipoEvento
                ,IpPostIn
                ,PostTime
                ,Descripcion
                ,idUsuario
            )
            VALUES (
                18
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