CREATE PROCEDURE dbo.procDesasociarDeduccion
    @inValorDocumentoIdentidad VARCHAR(20)
    ,@inTipoDeduccion VARCHAR(100)
    ,@inFechaFin DATETIME
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdEmpleado INT
    DECLARE @IdTipoDeduccion INT
    DECLARE @FlagPorcentual BIT

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

        SELECT @IdTipoDeduccion = td.id
            ,@FlagPorcentual  = td.FlagPorcentual
        FROM dbo.TipoDeduccion AS td
        WHERE (td.Nombre = @inTipoDeduccion)

        BEGIN TRANSACTION

            IF (@FlagPorcentual = 1)
            BEGIN
                UPDATE dbo.EmpXTipoDeduccionPorcentual
                SET FechaFin = @inFechaFin
                WHERE (idEmpleado = @IdEmpleado)
                    AND (idTipoDeduccion = @IdTipoDeduccion)
                    AND (FechaFin = '9999-12-31')
            END
            ELSE
            BEGIN
                UPDATE dbo.EmpXTipoDeduccionFija
                SET FechaFin = @inFechaFin
                WHERE (idEmpleado = @IdEmpleado)
                    AND (idTipoDeduccion = @IdTipoDeduccion)
                    AND (FechaFin = '9999-12-31')
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