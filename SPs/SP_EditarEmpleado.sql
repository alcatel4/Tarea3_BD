CREATE PROCEDURE dbo.procEditarEmpleado
    @inIdEmpleado INT
    ,@inNombre VARCHAR(100)
    ,@inTipoDocumentoIdentidad VARCHAR(30)
    ,@inDocumentoIdentidad VARCHAR(20)
    ,@inCuentaBancaria VARCHAR(30)
    ,@inIdPuesto INT
    ,@inUsername VARCHAR(64)
    ,@inPostInIP VARCHAR(64)
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdUsuario INT
    DECLARE @NombreAntes VARCHAR(100)
    DECLARE @TipoDocAntes VARCHAR(30)
    DECLARE @DocAntes VARCHAR(20)
    DECLARE @CuentaAntes VARCHAR(30)
    DECLARE @IdPuestoAntes INT
    DECLARE @DescripcionEvento VARCHAR(MAX)

    SET @outResultCode = 0

    BEGIN TRY

        SELECT @IdUsuario = u.id
        FROM dbo.Usuario AS u
        WHERE (u.UserName = @inUsername)

        SELECT @NombreAntes = e.Nombre
            ,@TipoDocAntes = e.TipoDocumentoIdentidad
            ,@DocAntes = e.DocumentoIdentidad
            ,@CuentaAntes = e.CuentaBancaria
            ,@IdPuestoAntes = e.idPuesto
        FROM dbo.Empleado AS e
        WHERE (e.id = @inIdEmpleado)

        SET @DescripcionEvento = 
            '{"antes":{"Nombre":"' + @NombreAntes + 
            '","TipoDoc":"' + @TipoDocAntes + 
            '","Doc":"' + @DocAntes + 
            '","Cuenta":"' + @CuentaAntes + 
            '","IdPuesto":"' + CAST(@IdPuestoAntes AS VARCHAR) + 
            '"},"despues":{"Nombre":"' + @inNombre + 
            '","TipoDoc":"' + @inTipoDocumentoIdentidad + 
            '","Doc":"' + @inDocumentoIdentidad + 
            '","Cuenta":"' + @inCuentaBancaria + 
            '","IdPuesto":"' + CAST(@inIdPuesto AS VARCHAR) + '"}}'

        BEGIN TRANSACTION
        
            UPDATE dbo.Empleado
            SET Nombre = @inNombre
                ,TipoDocumentoIdentidad = @inTipoDocumentoIdentidad
                ,DocumentoIdentidad = @inDocumentoIdentidad
                ,CuentaBancaria = @inCuentaBancaria
                ,idPuesto = @inIdPuesto
            WHERE (id = @inIdEmpleado)

            INSERT INTO dbo.BitacoraEvento (
                idTipoEvento
                ,IpPostIn
                ,PostTime
                ,Descripcion
                ,idUsuario
            )
            VALUES (
                8
                ,@inPostInIP
                ,GETDATE()
                ,@DescripcionEvento
                ,@IdUsuario
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
            @inUsername
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